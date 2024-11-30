import Vapor
import Foundation
import Fluent

struct GetDeliveryListOutput: Content {
    var id: Delivery.IDValue?
    var name: String?
    var customerID: Customer.IDValue?
    var boxCount: Int
    var trackingItemCount: Int
}

extension Delivery {
    func toListOutput(on db: Database) async throws -> GetDeliveryListOutput {
        try await self.$customer.load(on: db)
        let packBoxesID = try await self.$packBoxes.query(on: db).all(\.$id)
        let trackingItemCount = try await TrackingItem.query(on: db)
            .filter(\.$packBox.$id ~~ packBoxesID)
            .count()
        try await self.$customer.load(on: db)
        return .init(
            id: self.id,
            name: self.customer.customerCode,
            customerID: self.customer.id,
            boxCount: packBoxesID.count,
            trackingItemCount: trackingItemCount
        )
    }
}
