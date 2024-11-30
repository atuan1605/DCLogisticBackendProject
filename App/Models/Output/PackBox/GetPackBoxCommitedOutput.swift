import Vapor
import Foundation
import Fluent

struct GetPackBoxesCommitedOutput: Content {
    let id: PackBox.IDValue?
    let name: String
    let customer: String?
    let trackingItemCount: Int?
    let commitedAt: Date?
    let customerID: Customer.IDValue
}

extension PackBox {
    func toListCommitedOutput(on db: Database) async throws -> GetPackBoxesCommitedOutput {
        let trackingItemsCount = try await self.$trackingItems.query(on: db).count()
        return .init(
            id: self.id,
            name: self.name,
            customer: self.customerCode,
            trackingItemCount: trackingItemsCount,
            commitedAt: self.commitedAt,
            customerID: self.$customer.id
        )
    }
}
