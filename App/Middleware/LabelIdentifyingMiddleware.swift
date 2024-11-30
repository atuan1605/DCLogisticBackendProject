import Vapor
import Foundation
import Fluent

struct LabelIdentifyingMiddleWare: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let labelID = request.parameters.get(Label.parameter, as: Label.IDValue.self) {
            let label = try await Label.find(labelID, on: request.db)
            request.label = label
        }
        return try await next.respond(to: request)
    }
}

struct LabelKey: StorageKey {
    typealias Value = Label
}

extension Request {
    var label: Label? {
        get {
            self.storage[LabelKey.self]
        }
        set {
            self.storage[LabelKey.self] = newValue
        }
    }
    
    func requireLabel() throws -> Label {
        guard let label = self.label else {
            throw AppError.labelNotFound
        }
        return label
    }
}

