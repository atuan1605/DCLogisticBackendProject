import Vapor
import Foundation
import Fluent

struct BoxIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let boxID =
            request.parameters.get(Box.parameter, as: Box.IDValue.self) {
            if let lot = request.lot {
                request.box = try await lot.$boxes.query(on: request.db)
                    .filter(\.$id == boxID)
                    .first()
            } else {
                let box = try await
                Box.find(boxID, on: request.db)
                request.box = box
            }
        }
        return try await next.respond(to: request)
    }
}

struct BoxKey: StorageKey {
    typealias Value = Box
}

extension Request {
    var box: Box? {
        get {
            self.storage[BoxKey.self]
        }
        set {
            self.storage[BoxKey.self] = newValue
        }
    }
    
    func requireBox() throws -> Box {
        guard let box = self.box else {
            throw AppError.boxNotFound
        }
        return box
    }
}

    
    
