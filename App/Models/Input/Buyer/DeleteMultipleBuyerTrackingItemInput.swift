import Foundation
import Vapor

struct DeleteMultipleBuyerTrackingItemInput: Content {
    var buyerTrackingItemIDs: [BuyerTrackingItem.IDValue]
}
