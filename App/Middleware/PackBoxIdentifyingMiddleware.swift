import Foundation
import Vapor
import Fluent

struct PackBoxIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let packBoxID = request.parameters.get(PackBox.parameter, as: PackBox.IDValue.self) {
            if let customer = request.customer {
                request.packBox = try await customer.$packBoxes.query(on: request.db)
                    .filter(\.$id == packBoxID)
                    .first()
            } else {
                let packBox = try await PackBox.find(packBoxID, on: request.db)
                request.packBox = packBox
            }
        }
        return try await next.respond(to: request)
    }
}

struct PackBoxKey: StorageKey {
    typealias Value = PackBox
}

extension Request {
    var packBox: PackBox? {
        get {
            self.storage[PackBoxKey.self]
        }
        set {
            self.storage[PackBoxKey.self] = newValue
        }
    }
    
    func requirePackBox() throws -> PackBox {
        guard let packBox = self.packBox else {
            throw AppError.packBoxNotFound
        }
        return packBox
    }
    
    func requireUncommitedPackBox() throws -> PackBox {
        let packBox = try self.requirePackBox()
        guard packBox.commitedAt == nil else {
            throw AppError.packBoxIsCompleted
        }
        return packBox
    }
    
    func requireCommitedPackBox() throws -> PackBox {
        let packBox = try self.requirePackBox()
        guard packBox.commitedAt != nil else {
            throw AppError.unfinishedPackBox
        }
        return packBox
    }
    
}
