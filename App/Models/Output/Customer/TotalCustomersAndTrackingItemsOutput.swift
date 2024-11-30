import Vapor
import Foundation

struct TotalCustomersAndTrackingItemsOutput: Content {
    var customerCount: Int
    var trackingItemCount: Int
}

extension TotalCustomersAndTrackingItemsOutput {
    init(items: [TrackingItem], customers: [Customer]) {
        self.trackingItemCount = items.count
        self.customerCount = customers.count
    }
}
