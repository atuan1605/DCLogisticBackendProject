import Foundation
import Vapor

struct UserIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let userID = request.parameters.get(User.parameter, as: User.IDValue.self) {
            let user = try await User.find(userID, on: request.db)
            request.user = user
        }
        // logic trong middleware
        return try await next.respond(to: request)
    }
}

struct UserKey: StorageKey {
    typealias Value = User
}

extension Request {
    var user: User? {
        get {
            self.storage[UserKey.self]
        }
        set {
            self.storage[UserKey.self] = newValue
        }
    }

    func requireUser() throws -> User {
        guard let user = self.user else {
            throw AppError.invalidInput
        }
        return user
    }
}
