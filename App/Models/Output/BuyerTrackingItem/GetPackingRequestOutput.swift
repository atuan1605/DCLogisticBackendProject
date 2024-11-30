import Vapor
import Foundation

struct GetPackingRequestOutput: Content {
    var id: BuyerTrackingItem.IDValue?
    var createdAt: Date?
    var trackingNumber: String?
    var customerCodes: String?
    var packingRequest: String?
    var packingRequestState: BuyerTrackingItem.PackingRequestState?
    var files: [String]?
    var packingRequestNote: String?
}

