import Foundation
import Vapor

struct GetTrackingItemInfoRequiredOutput: Content {
    var trackingItem: TrackingItemOutput
    var total: Int
}
