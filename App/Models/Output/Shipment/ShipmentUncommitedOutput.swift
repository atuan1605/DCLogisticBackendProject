import Vapor
import Foundation

struct ShipmentUncommitedOutput: Content {
    let id: Shipment.IDValue?
    let shipmentCode: String
    let boxCount: Int
}

extension Shipment {
    func toUncommitedOutput() -> ShipmentUncommitedOutput {
        .init(
            id: self.id,
            shipmentCode: self.shipmentCode,
            boxCount: self.$boxes.value?.count ?? 0
        )
    }
}
