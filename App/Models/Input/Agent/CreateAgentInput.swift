import Vapor
import Foundation

struct CreateAgentInput: Content {
    var name: String
}

extension CreateAgentInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
    }
}

extension CreateAgentInput {
    func toAgent() -> Agent {
        return .init(
            id: self.name,
            name: self.name)
    }
}
