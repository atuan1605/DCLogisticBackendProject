import Foundation
import Vapor

struct CreateBoxCustomItemInput: Content {
    var details: String
    var reference: String
}

extension CreateBoxCustomItemInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("reference", as: String.self, is: !.empty)
    }
}
