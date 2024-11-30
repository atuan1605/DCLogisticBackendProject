import Vapor
import Foundation

struct UpdateLotInput: Content {
    var lotIndex: String
}

extension UpdateLotInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("lotIndex", as: String.self, is: !.empty)
    }
}
