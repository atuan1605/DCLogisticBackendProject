//
import Foundation
import Vapor

struct UpdateMultipleTrackingItemsInput: Content {
    var trackedItemIDs: [BuyerTrackingItem.IDValue]
    var sharedNote: String
    var sharedPackingRequest: String
}
