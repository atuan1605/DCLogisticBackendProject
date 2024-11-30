import Foundation
import Vapor
import Fluent

struct DeliveryIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let deliveryID = request.parameters.get(Delivery.parameter, as: Delivery.IDValue.self) {
            let delivery = try await Delivery.find(deliveryID, on: request.db)
            request.delivery = delivery
        }
        return try await next.respond(to: request)
    }
}

struct DeliveryKey: StorageKey {
    typealias Value = Delivery
}

extension Request {
    var delivery: Delivery? {
        get {
            self.storage[DeliveryKey.self]
        }
        set {
            self.storage[DeliveryKey.self] = newValue
        }
    }
    
    func requireDelivery() throws -> Delivery {
        guard let delivery = self.delivery else {
            throw AppError.deliveryNotFound
        }
        return delivery
    }
    
    func requireUncommitedDelivery() throws -> Delivery {
        let delivery = try self.requireDelivery()
        guard delivery.commitedAt == nil else {
            throw AppError.packBoxIsCompleted
        }
        return delivery
    }
    
    func requireCommitedDelivery() throws -> Delivery {
        let delivery = try self.requireDelivery()
        guard delivery.commitedAt != nil else {
            throw AppError.packBoxIsCompleted
        }
        return delivery
    }
}
