import Vapor
import Foundation

struct RepackedAtVNByCustomerOutput: Content {
    var customerID: Customer.IDValue?
    var customerCode: String?
    var boxCount: Int
    var trackingItemCount: Int
}

extension Customer {
    func toListOutput() -> RepackedAtVNByCustomerOutput {
        return .init(
            customerID: self.id,
            customerCode: self.customerCode,
            boxCount: self.packBoxes.count,
            trackingItemCount: self.packBoxes.map { $0.trackingItems.count }.reduce(0, +)
            )
    }
}

