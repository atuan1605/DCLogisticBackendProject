import Vapor
import Foundation
import Fluent

struct GetRepackedItemsPaginatedOutput: Content {
    var trackingNumber: String
    var id: TrackingItem.IDValue?
    var productsDescription: String
    var totalTrackingInChain: Int
    var repackedAt: Date?
    var check: Bool
}

//extension TrackingItem {
//    func toRepackedOutput(on db: Database) async throws -> GetRepackedItemsPaginatedOutput {
//        let repackedItemsCount = try await TrackingItem.query(on: db)
//            .filterRepacked()
//            .filter(\.$chain == self.chain)
//            .all().count
//        var checked = self.customerCode != nil && self.agentCode != nil && !self.files.isEmpty && !self.products.isEmpty
//        return .init(
//            trackingNumber: self.trackingNumber,
//            id: self.id,
//            productsDescription: self.products.description,
//            totalTrackingInChain: repackedItemsCount,
//            repackedAt: self.repackedAt,
//            check: checked
//        )
//    }
//}
