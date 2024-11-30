import Vapor
import Foundation

struct UpdateShipmentInput: Content {
    var shipmentCode: String
}

extension UpdateShipmentInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("shipmentCode", as: String.self, is: !.empty)
    }
}

