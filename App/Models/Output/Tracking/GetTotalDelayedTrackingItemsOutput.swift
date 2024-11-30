import Vapor
import Foundation

struct GetProtractedTrackingItemsOutput: Content {
    let itemCount: Int
    let items: [TrackingItemOutput]
}

extension GetProtractedTrackingItemsOutput {
    init(items: [TrackingItem]) {
        self.itemCount = items.count
        self.items = items.map { $0.output() }
    }
}
