import Foundation
import Vapor

struct WarehouseForTotalTrackingOutput: Content {
    var id: Warehouse.IDValue?
    var name: String
    var count: Int
}

extension Warehouse {
    func totalOutput(trackingItems: [TrackingItem]) -> WarehouseForTotalTrackingOutput {
        return .init(id: self.id, name: self.name, count: trackingItems.filter{ $0.$warehouse.id == self.id}.count )
    }
}
