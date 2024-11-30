import Vapor
import Foundation

struct CreateBuyerTrackingItemInput: Content {
    var trackingNumber: String
    var note: String?
    var packingRequest: String?
    var deposit: Int
    var quantity: Int
}
