import Vapor
import Foundation

struct TotalCustomerAndTrackingItemByAgentOutput: Content {
    var customerCount: Int
    var trackingItemCount: Int
}

extension TotalCustomerAndTrackingItemByAgentOutput {
    init(customers: [Customer]) {
        self.customerCount = customers.count
        self.trackingItemCount = customers.compactMap{ $0.$trackingItems.value?.count }.reduce(0, +)
    }
}
