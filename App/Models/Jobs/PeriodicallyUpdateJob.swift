import Foundation
import Vapor
import Fluent
import Queues
import SQLKit

struct PeriodicallyUpdateJob: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        let now = Date()
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: now)

        if minutes % 3 != 0 {
            return
        }

        context.application.logger.info("refresh periodically tracking items")
        try await context.application.db.transaction { transactionDB in
            let buyerTrackingItems = try await BuyerTrackingItem.query(on: transactionDB)
                .filter(\.$packingRequestState == nil)
                .all()
            let buyerTrackingNumbers = buyerTrackingItems.map { $0.trackingNumber }
            let trackingItemReferences = try await TrackingItemReference.query(on: transactionDB)
                .filter(trackingNumbers: buyerTrackingNumbers)
                .with(\.$trackingItem)
                .all()
            let trackingNumbers = trackingItemReferences.map { $0.trackingItem.trackingNumber }
            let hasParentRequestTrackingItems = try await BuyerTrackingItem.query(on: transactionDB)
                .filter(\.$trackingNumber ~~ trackingNumbers)
                .filter(\.$parentRequest.$id != .null)
                .field(\.$trackingNumber)
                .all()
            let hasParentRequestTrackingNumbers = hasParentRequestTrackingItems.map { $0.trackingNumber }
            
            var newBuyerTrackingItems: [BuyerTrackingItem] = []
            for trackingItemReference in trackingItemReferences {
                let trackingReferenceNumber = trackingItemReference.trackingNumber
                let trackingItem = trackingItemReference.trackingItem
                let trackingNumber = trackingItem.trackingNumber
                if let buyerTrackingItem = buyerTrackingItems.first(where: { trackingReferenceNumber.contains($0.trackingNumber)}), !hasParentRequestTrackingNumbers.contains(trackingNumber) {
                    let newBuyerTrackingItem: BuyerTrackingItem = .init(
                        note: buyerTrackingItem.note,
                        packingRequest: buyerTrackingItem.packingRequest,
                        buyerID: buyerTrackingItem.$buyer.id,
                        trackingNumber: trackingNumber,
                        quantity: buyerTrackingItem.quantity,
                        parentRequestID: buyerTrackingItem.id,
                        deposit: buyerTrackingItem.deposit,
                        requestType: buyerTrackingItem.requestType
                    )
                    newBuyerTrackingItems.append(newBuyerTrackingItem)
                }
            }
            try await newBuyerTrackingItems.create(on: transactionDB)
            
            try await (transactionDB as? SQLDatabase)?.raw("""
            REFRESH MATERIALIZED VIEW CONCURRENTLY \(raw: BuyerTrackingItemLinkView.schema);
            """).run()
        }
    }
}

extension PeriodicallyUpdateJob: AsyncJob {
    struct Payload: Content {
        var refreshBuyerTrackedItemLinkView: Bool
    }
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        if payload.refreshBuyerTrackedItemLinkView {
            try await context.application.db.transaction { transactionDB in
                try await (transactionDB as? SQLDatabase)?.raw("""
                REFRESH MATERIALIZED VIEW CONCURRENTLY \(raw: BuyerTrackingItemLinkView.schema);
                """).run()
            }
        }
        
    }
}
