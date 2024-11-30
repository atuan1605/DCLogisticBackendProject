import Vapor
import Foundation

struct CreateShipmentInput: Content {
    var shipmentCode: String
}

extension CreateShipmentInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("shipmentCode", as: String.self, is: !.empty && .alphanumeric)
    }
}

extension CreateShipmentInput {
    func toShipment() -> Shipment {
        return .init(
            shipmentCode: self.shipmentCode,
            commitedAt: nil
        )
    }
}
