import Vapor
import Foundation

struct TrackingReferenceOutput: Content {
    var id: TrackingItemReference.IDValue?
    var trackingNumber: String
}

extension TrackingItemReference {
    func output() -> TrackingReferenceOutput {
        return .init(
            id: self.id,
            trackingNumber: self.trackingNumber
        )
    }
}
