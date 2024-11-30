import Foundation
import Vapor

struct DeleteMultipleTrackingItemsInput: Content {
    var trackedItemIDs: [BuyerTrackingItem.IDValue]
}
