import Vapor
import Foundation
import Fluent

struct CustomerDeliveryOuput: Content {
    var id: Shipment.IDValue?
    var trackingItemsCount: Int
    var commitedAt: Date?
    var createdAt: Date?
}

extension Delivery {
    
//    func output(customerId: UUID, on db: Database) async throws -> CustomerDeliveryOuput {
//        let trackingItems = try await TrackingItem.query(on: db)
//            .filter(\.$customer.$id == customerId)
//            .join(PackBox.self, on: \PackBox.$id == \TrackingItem.$packBox.$id)
//            .filter(PackBox.self, \.$delivery.$id == self.id)
//            .unique()
//            .fields(for: TrackingItem.self)
//            .all()
//        return CustomerDeliveryOuput(id: self.id, trackingItemsCount: trackingItems.count, commitedAt: self.commitedAt, createdAt: self.createdAt)
//    }
}


