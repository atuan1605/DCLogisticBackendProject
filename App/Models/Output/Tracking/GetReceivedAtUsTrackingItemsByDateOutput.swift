import Vapor
import Foundation

struct GetReceivedAtUsTrackingItemsByDateOutput: Content {
    var date: Date?
    var trackingNumber: String?
    var id: TrackingItem.IDValue?
}

extension TrackingItem {
    func toReceivedAtUSByDate() -> GetReceivedAtUsTrackingItemsByDateOutput {
        return .init(
            date: self.receivedAtUSAt,
            trackingNumber: self.trackingNumber,
            id: self.id
        )
    }
}
