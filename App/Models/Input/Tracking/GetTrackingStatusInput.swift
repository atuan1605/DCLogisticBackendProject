import Foundation
import Vapor

struct GetTrackingStatusInput: Content {
    var trackingNumber: String
    var includeAlternativeRef: Bool?
    var includePackingRequest: Bool?
}
