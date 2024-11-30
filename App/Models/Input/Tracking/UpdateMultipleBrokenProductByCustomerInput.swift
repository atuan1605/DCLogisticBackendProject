import Vapor
import Foundation

struct UpdateMultipleBrokenProductByCustomerInput: Content {
    var trackingItemIDs: [TrackingItem.IDValue]
}
