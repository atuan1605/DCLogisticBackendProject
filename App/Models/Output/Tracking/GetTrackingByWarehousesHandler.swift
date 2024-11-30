import Vapor
import Foundation

struct GetTrackingByWarehousesOutput: Content {
    var id: TrackingItem.IDValue?
    var trackingNumber: String
    var receivedAtUSAt: Date?
    var updatedAt: Date?
    var warehouseID: Warehouse.IDValue?
    var updatedBy: String?
}

extension TrackingItem {
    func toWarehouseOutput(updatedBy: String? = nil) -> GetTrackingByWarehousesOutput {
        return .init(
            id: self.id,
            trackingNumber: self.trackingNumber,
            receivedAtUSAt: self.receivedAtUSAt,
            updatedAt: self.updatedAt,
            warehouseID: self.$warehouse.id,
            updatedBy: updatedBy
        )
    }
}
