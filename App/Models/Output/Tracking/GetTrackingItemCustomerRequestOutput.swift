import Vapor
import Foundation

struct GetBrokenProductByCustomerRequestOutput: Content {
    var id: TrackingItem.IDValue?
    var trackingNumber: String
    var description: String?
    var flagAt: Date?
    var feedback: TrackingItem.CustomerFeedback?
    var receivedAtUSAt: Date?
    var receivedAtVNAt: Date?
    var boxedAt: Date?
    var flyingBackAt: Date?
    var files: [String]?
    var trackingItemReferences: String?
    var customerNote: String?
    var packingRequestNote: String?
    var checkedAt: Date?
}
