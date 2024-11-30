import Vapor
import Foundation
import Fluent

struct GetCustomersPackboxOutput: Content {
    var customerID: Customer.IDValue?
    var customerCode: String
    var itemsInPackBox: Int
    var remainingItems: Int
    var packBoxes: [GetPackBoxesByCustomerOutput]
}

extension Customer {
    func toPackBoxesOutput(on request: Request) async throws -> GetCustomersPackboxOutput {
        let receivedItemsCount = try await request.trackingItems.get(by: self.requireID(), queryModifier: { query in
            query.filterReceivedAtVN()
        }).count
        let packedItemsCount = try await request.trackingItems.get(by: self.requireID(), queryModifier: { query in
            query.filterPackedAtVN()
        }).count
        let packBoxes = try await PackBox.query(on: request.db)
            .filter(\.$customerCode == self.customerCode)
            .filter(\.$commitedAt == nil)
            .with(\.$trackingItems) { $0.with(\.$products) }
            .all()
        return .init(
            customerID: self.id,
            customerCode: self.customerCode,
            itemsInPackBox: packedItemsCount,
            remainingItems: receivedItemsCount,
            packBoxes: packBoxes.map{ $0.toCustomerOutput() }
        )
    }
}

