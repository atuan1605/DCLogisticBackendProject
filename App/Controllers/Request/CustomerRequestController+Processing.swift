import Foundation
import Vapor
import Fluent

struct ProcessingCustomerRequestController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let grouped = routes.grouped("processing")
        let protected = grouped.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )
        let trackingItemsRoute = protected.grouped("trackingItems")
        let trackingItemIdentifierRoute = trackingItemsRoute
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())
        trackingItemIdentifierRoute.put(use: updateProcessingTrackingItemHandler)
        trackingItemsRoute.get(use: getCustomerRequestHandler)
    }
    
    private func getCustomerRequestHandler(request: Request) async throws -> BuyerTrackingItemOutput {
        let input = try request.query.decode(GetPackingRequestInput.self)
        if let buyerTrackingItemLinkView = try await BuyerTrackingItemLinkView.query(on: request.db)
            .join(BuyerTrackingItem.self, on: \BuyerTrackingItem.$id == \BuyerTrackingItemLinkView.$buyerTrackingItem.$id)
            .filter(\.$trackingItemTrackingNumber == input.trackingNumber)
            .filter(BuyerTrackingItem.self, \.$requestType !~ BuyerTrackingItem.nonActionRequestType)
            .with(\.$buyerTrackingItem)
            .first() {
            let buyerTrackingItem = buyerTrackingItemLinkView.buyerTrackingItem
            return buyerTrackingItem.output()
        }
        return .init()
    }
    
    private func updateProcessingTrackingItemHandler(request: Request) async throws -> BuyerTrackingItemOutput {
        let trackingItem = try request.requireTrackingItem()
        let trackingItemID = try trackingItem.requireID()
        let input = try request.content.decode(UpdateProccessingCustomerRequestInput.self)
        let buyerTrackingItemLinkView = try await BuyerTrackingItemLinkView.query(on: request.db)
            .filter(\.$trackingItem.$id == trackingItemID)
            .with(\.$buyerTrackingItem)
            .first()
        guard let buyerTrackingItemLinkView = buyerTrackingItemLinkView else {
            throw AppError.invalidInput
        }
        var buyerTrackingItem = buyerTrackingItemLinkView.buyerTrackingItem
        let buyerTrackingItemID = try buyerTrackingItem.requireID()
        let requestType = buyerTrackingItem.requestType
        
        if requestType == .quantityCheck {
            guard let actualQuantity = input.quantity else {
                throw AppError.invalidInput
            }
            if actualQuantity != buyerTrackingItem.quantity {
                buyerTrackingItem = try await request.buyerTrackingItems.updatePackingState(buyerTrackingItemID: buyerTrackingItemID, state: .hold)
            } else {
                buyerTrackingItem = try await request.buyerTrackingItems.updatePackingState(buyerTrackingItemID: buyerTrackingItemID, state: .processed)
            }
            let parentRequest = buyerTrackingItem.parentRequest
            buyerTrackingItem.actualQuantity = actualQuantity
            parentRequest?.actualQuantity = actualQuantity
            try await buyerTrackingItem.save(on: request.db)
            try await parentRequest?.save(on: request.db)
        } else if requestType == .specialRequest {
            guard let packingRequestState = input.packingRequestState else {
                throw AppError.invalidInput
            }
            buyerTrackingItem = try await request.buyerTrackingItems.updatePackingState(buyerTrackingItemID: buyerTrackingItemID, state: packingRequestState)
            try await buyerTrackingItem.save(on: request.db)
            let parentRequest = buyerTrackingItem.parentRequest
          
            if let actualQuantity = input.quantity {
                buyerTrackingItem.actualQuantity = actualQuantity
                parentRequest?.actualQuantity = actualQuantity
            }
            if let packingRequestNote = input.note {
                buyerTrackingItem.packingRequestNote = packingRequestNote
                parentRequest?.packingRequestNote = packingRequestNote
            }
            if buyerTrackingItem.hasChanges {
                try await buyerTrackingItem.save(on: request.db)
                try await parentRequest?.save(on: request.db)
            }
        } else if requestType == .holdTracking {
            buyerTrackingItem = try await request.buyerTrackingItems.updatePackingState(buyerTrackingItemID: buyerTrackingItemID, state: .hold)
        } else if requestType == .returnTracking {
            buyerTrackingItem = try await request.buyerTrackingItems.updatePackingState(buyerTrackingItemID: buyerTrackingItemID, state: .hold)
            let _ = try await request.trackingItems.updateHoldState(trackingItemID: trackingItemID, holdState: .returnProduct)
        }
        return buyerTrackingItem.output()
    }
}
