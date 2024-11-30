import Foundation
import Vapor

struct MoveToPackedInput: Content {
    var chain: String?
}

extension MoveToPackedInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("chain", as: String.self, is: !.empty, required: false)
    }
}
