import Foundation
import Vapor

struct GetTrackingItemByWarehouseOutput: Content {
    var id: TrackingItem.IDValue?
    var trackingNumber: String
    var receivedAtUSAt: Date?
    var files: [String]?
    var productName: String?
    var customers: String?
}

extension TrackingItem {
    func outputByWarehouse() -> GetTrackingItemByWarehouseOutput {
        return .init(
            id: self.id,
            trackingNumber: self.trackingNumber,
            receivedAtUSAt: self.receivedAtUSAt,
            files: self.$products.value?.first?.images,
            productName: self.$products.value?.first?.description,
            customers: self.$customers.value?.map(\.customerCode).joined(separator: ", ")
        )
    }
}
