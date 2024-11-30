import Vapor
import Foundation

struct GetReturnedTrackingItemOutput: Content {
    var id: TrackingItem.IDValue?
    var trackingNumber: String
    var customerCode: String?
    var holdRequestContent: String?
    var holdState: TrackingItem.HoldState?
    var holdStateAt: Date?
    var returnRequestAt: Date?
    var updatedBy: String?
    var packingRequestNote: String?
}
