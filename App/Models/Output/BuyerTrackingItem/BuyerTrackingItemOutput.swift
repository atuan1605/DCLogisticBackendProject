import Foundation
import Vapor
import Fluent

extension String {
    var isBlank: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct BuyerTrackingItemOutput: Content {
    
    var id: BuyerTrackingItem.IDValue?
    var note: String
    var createdAt: Date?
    var updatedAt: Date?
    var buyer: BuyerOutput?
    var packingRequest: String
    var trackingNumber: String
    var trackedItem: TrackingItemDCOutput?
    var quantity: Int?
    var deposit: Int?
    var requestType: BuyerTrackingItem.RequestType?
    var trackingItems: [TrackingItemOutput]?
    var actualQuantity: Int?
    var packingRequestNote: String?
    var packingRequestState: BuyerTrackingItem.PackingRequestState?
    var paidAt: Date?
    var customerNote: String?

    internal init(id: UUID? = nil, note: String, createdAt: Date? = nil, updatedAt: Date? = nil, buyer: BuyerOutput?, trackingNumber: String, trackedItem: TrackingItemDCOutput? = nil, packingRequest: String, paidAt: Date? = nil, customerNote: String? = nil) {
        self.id = id
        
        if note.isBlank {
            self.note = note
        } else {
            self.note = "🗒️ \(note)"
        }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.buyer = buyer
        self.trackingNumber = trackingNumber
        if packingRequest.isBlank {
            self.packingRequest = packingRequest
        } else {
            self.packingRequest = "🚨 \(packingRequest)"
        }
        
        if let validTrackedItem = trackedItem {
            self.trackedItem = validTrackedItem
        } else {
            self.trackedItem = .init(
                trackingNumber: trackingNumber,
                stateTrails: [])
        }
        self.paidAt = paidAt
        self.customerNote = customerNote
    }
    
    init(
        id: BuyerTrackingItem.IDValue? = nil,
        note: String = "",
        createdAt: Date? = nil,
        buyer: BuyerOutput? = nil,
        packingRequest: String = "",
        trackingNumber: String = "",
        quantity: Int? = nil,
        deposit: Int? = nil,
        requestType: BuyerTrackingItem.RequestType? = nil,
        trackingItems: [TrackingItemOutput]? = nil,
        actualQuantity: Int? = nil,
        packingRequestNote: String? = nil,
        packingRequestState: BuyerTrackingItem.PackingRequestState? = nil,
        paidAt: Date? = nil,
        customerNote: String? = nil
    ) {
            self.id = id
            self.note = note
            self.createdAt = createdAt
            self.buyer = buyer
            self.packingRequest = packingRequest
            self.trackingNumber = trackingNumber
            self.quantity = quantity
            self.deposit = deposit
            self.requestType = requestType
            self.trackingItems = trackingItems
            self.actualQuantity = actualQuantity
            self.packingRequestNote = packingRequestNote
            self.packingRequestState = packingRequestState
            self.paidAt = paidAt
            self.customerNote = customerNote
    }
    
    
}

extension BuyerTrackingItem {
    func output(with trackingItem: TrackingItem?) -> BuyerTrackingItemOutput {
        var trackingNumber = self.trackingNumber
        let parentRequest = self.$parentRequest.value ?? nil
        if let parentRequest = parentRequest {
            trackingNumber = parentRequest.trackingNumber
        }
        return .init(
            id: self.id,
            note: self.note,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            buyer: self.$buyer.value?.output(),
            trackingNumber: trackingNumber,
            trackedItem: trackingItem?.dcOutput(),
            packingRequest: self.packingRequest
        )
    }
    
    func outputWithoutTrackedItem() -> BuyerTrackingItemOutput {
        .init(note: self.note,
              createdAt: self.createdAt,
              updatedAt: self.updatedAt,
              buyer: self.$buyer.value?.output(),
              trackingNumber: self.trackingNumber,
              packingRequest: self.packingRequest)
    }

    func output(with trackingItems: [TrackingItem]) -> BuyerTrackingItemOutput {
        let trackedItem = trackingItems.first(where: {
            $0.trackingNumber.hasSuffix(self.trackingNumber)
        })
        
        return self.output(with: trackedItem)
    }

    func output(in db: Database) async throws -> BuyerTrackingItemOutput {
        let trackingItems = try await self.$trackingItems.get(on: db)
        return self.output(with: trackingItems.first)
    }
    

    func output() -> BuyerTrackingItemOutput {
        .init(
            id: self.id,
            note: self.note,
            createdAt: self.createdAt,
            buyer: self.$buyer.value?.output(),
            packingRequest: self.packingRequest,
            trackingNumber: self.trackingNumber,
            quantity: self.quantity,
            deposit: self.deposit,
            requestType: self.requestType,
            trackingItems: self.$trackingItems.value?.compactMap { $0.output() },
            actualQuantity: self.actualQuantity, 
            packingRequestNote: self.packingRequestNote,
            packingRequestState: self.packingRequestState,
            paidAt: self.paidAt,
            customerNote: self.customerNote
        )
    }
}
