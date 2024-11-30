import Foundation
import Vapor

struct GetCustomerRequestInput: Content {
    var requestType: BuyerTrackingItem.RequestType
}
