import Foundation
import Vapor

struct GetProcessedCustomerRequestInput: Content {
    var trackingNumbers: [String]?
    var requestType: BuyerTrackingItem.RequestType
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
}
