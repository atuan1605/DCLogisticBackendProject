import Vapor
import Foundation
import Fluent

struct WarehouseIdentifyingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let warehouseID = request.parameters.get(Warehouse.parameter, as: Warehouse.IDValue.self) {
            let warehouse = try await Warehouse.find(warehouseID, on: request.db)
            request.warehouse = warehouse
        }
        return try await next.respond(to: request)
    }
}

struct WarehouseKey: StorageKey {
    typealias Value = Warehouse
}

extension Request {
    var warehouse: Warehouse? {
        get {
            self.storage[WarehouseKey.self]
        }
        set {
            self.storage[WarehouseKey.self] = newValue
        }
    }
    
    func requireWarehouse() throws -> Warehouse {
        guard let warehouse = self.warehouse else {
            throw AppError.warehouseNotFound
        }
        return warehouse
    }
}
