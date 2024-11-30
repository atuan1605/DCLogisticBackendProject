import Vapor
import Foundation

struct GetTrackingItemsInChainOutput: Content {
    let id: TrackingItem.IDValue?
    let trackingNumber: String?
    let image: String?
    let chain: String?
}
extension TrackingItem {
    func toOutputInChain() -> GetTrackingItemsInChainOutput {
        .init(
            id: self.id,
            trackingNumber: self.trackingNumber,
            image: self.files.first,
            chain: self.chain
        )
    }
}
