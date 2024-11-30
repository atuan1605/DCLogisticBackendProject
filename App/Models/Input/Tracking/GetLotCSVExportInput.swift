import Foundation
import Vapor

struct GetLotCSVExportInput: Content {
    var lotIDs: [Lot.IDValue]
    var timeZone: String?
}

extension GetLotCSVExportInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("lotIDs", as: [Lot.IDValue].self, is: !.empty)
    }
}
