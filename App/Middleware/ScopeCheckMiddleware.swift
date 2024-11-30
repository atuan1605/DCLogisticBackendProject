import Vapor
import Foundation

struct ScopeCheckMiddleware: AsyncMiddleware {
    var requiredScope: User.Scope

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: self.requiredScope) else {
            throw AppError.invalidScope
        }
        return try await next.respond(to: request)
    }
}
