import Foundation
import Fluent
import Vapor
import Crypto

struct CreateUserInput: Content {
    var username: String
    var password: String
    var isExternal: Bool?
    var agentID: Agent.IDValue?
}

extension CreateUserInput: Validatable {
    static func validations(_ validations: inout Vapor.Validations) {
        validations.add("username", as: String.self, is: !.empty && .alphanumeric)
        validations.add("password", as: String.self, is: !.empty)
    }
}

extension CreateUserInput {
    func toUser() throws -> User {
        let passwordHash = try Bcrypt.hash(self.password)
        let scope = User.Scope(rawValue: 0)
        return .init(
            username: self.username,
            passwordHash: passwordHash,
            scopes: scope,
            isExternal: isExternal
        )
    }
}


