import Vapor
import Foundation
import Fluent

struct DeliveryOutput: Content {
    let name: String?
    let customerID: Customer.IDValue?
    let images: [String]?
    let items: GetPackBoxesCommitedListOutput
}

extension Delivery {
    func toOutput(on db: Database) async throws -> DeliveryOutput {
        let packBoxes = try await self.$packBoxes.get(on: db)
        try await self.$customer.load(on: db)
        return try await .init(
            name: self.customer.customerCode,
            customerID: self.customer.id,
            images: self.images,
            items: GetPackBoxesCommitedListOutput(items: packBoxes, on: db)
        )
    }
}
