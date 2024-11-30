import Foundation
import Vapor

struct UpdateMultipleBuyerTrackingItemInput: Content {
    var buyerTrackingItemIDs: [BuyerTrackingItem.IDValue]
    var sharedNote: String?
    var sharedPackingRequest: String?
}
