import Vapor
import Foundation

struct GetPackedAtVNItemsOutput: Content {
    var trackingNumber: String
    var id: TrackingItem.IDValue?
    var productsDescription: String
}

extension TrackingItem {
    func toPackedAtVNOutput() -> GetPackedAtVNItemsOutput {
        return .init(
            trackingNumber: self.trackingNumber,
            id: self.id,
            productsDescription: self.products.description
        )
    }
}
