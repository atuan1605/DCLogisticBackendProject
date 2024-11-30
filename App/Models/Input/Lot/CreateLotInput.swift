import Vapor
import Foundation

struct CreateLotInput: Content {
    var lotIndex: String
}

extension CreateLotInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("lotIndex", as: String.self, is: !.empty)
    }
}

extension CreateLotInput {
    func toLot() -> Lot {
        return .init(
            lotIndex: self.lotIndex)
    }
}
