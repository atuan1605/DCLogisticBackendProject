import Foundation
import Vapor

struct GetTrackingStatusOutput: Content {
    var trackingID: TrackingItem.IDValue?
    var status: TrackingItem.Status
    var chain: String?
    var trackingNumber: String?
    var agentCode: String?
    var customerCode: String?
    var files: [String]?
    var productCount: Int?
    var firstProductQuantity: Int?
    var trackingItemReferences: [String]?
    var isDuplicatedReferenceTracking: Bool?
}
