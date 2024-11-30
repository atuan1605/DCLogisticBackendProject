import Vapor
import Foundation

struct UpdateTrackingReferencesInput: Content {
    var trackingReferences: [String]
}
