import Foundation
import Vapor

struct GetShipmentCSVExportInput: Content {
    var shipmentIDs: [Shipment.IDValue]
    var timeZone: String?
}

extension GetShipmentCSVExportInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("shipmentIDs", as: [Shipment.IDValue].self, is: !.empty)
    }
}
