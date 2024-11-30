import Foundation
import Vapor

struct GetTrackingItemImagesInput: Content {
    var trackingNumber: String
    var receivedAtUSAt: Date
}

struct GetDCTrackingItemInput: Content {
    var trackingNumber: String
    var receivedAtUSAt: Date?
}
