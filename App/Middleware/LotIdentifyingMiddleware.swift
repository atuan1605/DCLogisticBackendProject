import Vapor
import Foundation
import Fluent

struct LotIdentifyingMiddleWare: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let lotID = request.parameters.get(Lot.parameter, as: Lot.IDValue.self) {
            let lot = try await Lot.find(lotID, on: request.db)
            request.lot = lot
        }
        return try await next.respond(to: request)
    }
}

struct LotKey: StorageKey {
    typealias Value = Lot
}

extension Request {
    var lot: Lot? {
        get {
            self.storage[LotKey.self]
        }
        set {
            self.storage[LotKey.self] = newValue
        }
    }
    
    func requireLot() throws -> Lot {
        guard let lot = self.lot else {
            throw AppError.lotNotFound
        }
        return lot
    }
}
