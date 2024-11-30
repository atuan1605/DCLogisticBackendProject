import Vapor
import Foundation
import Fluent

struct GetPackBoxesOutput: Content {
    let id: PackBox.IDValue?
    let name: String
    let customer: String?
    let trackingItemCount: Int
    let createdAt: Date?
}

extension PackBox {
    func toListOutput(on db: Database) async throws -> GetPackBoxesOutput {
        let trackingItemsCount = try await self.$trackingItems.query(on: db).count()
        return .init(
            id: self.id,
            name: self.name,
            customer: self.customerCode,
            trackingItemCount: trackingItemsCount,
            createdAt: self.createdAt
        )
    }
}
