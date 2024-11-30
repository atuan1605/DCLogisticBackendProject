import Vapor
import Foundation
import Fluent

struct ShipmentIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let shipmentID = request.parameters.get(Shipment.parameter, as: Shipment.IDValue.self) {
            let shipment = try await Shipment.find(shipmentID, on: request.db)
            request.shipment = shipment
        }
        return try await next.respond(to: request)
    }
}

struct ShipmentKey: StorageKey {
    typealias Value = Shipment
}

extension Request {
    var shipment: Shipment? {
        get {
            self.storage[ShipmentKey.self]
        }
        set {
            self.storage[ShipmentKey.self] = newValue
        }
    }
    
    func requireShipment() throws -> Shipment {
        guard let shipment = self.shipment else {
            throw AppError.shipmentNotFound
        }
        return shipment
    }
    
    func requireUncommitedShipment() throws -> Shipment {
        let shipment = try self.requireShipment()
        guard shipment.commitedAt == nil else {
            throw AppError.shipmentIsCompleted
        }
        return shipment
    }
    
    func requireCommitedShipment() throws -> Shipment {
        let shipment = try self.requireShipment()
        guard shipment.commitedAt != nil else {
            throw AppError.unfinishedShipment
        }
        return shipment
    }
}
