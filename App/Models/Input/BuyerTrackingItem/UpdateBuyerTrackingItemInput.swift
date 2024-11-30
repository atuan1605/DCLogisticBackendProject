import Foundation
import Vapor

struct UpdateBuyerTrackingItemInput: Content {
    var note: String?
    var packingRequest: String?
    var packingRequestState: BuyerTrackingItem.PackingRequestState?
    var isPaid: Bool?
}
