import Vapor
import Fluent
import Foundation

struct CustomerIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder)
    async throws -> Response {
        if let customerID = request.parameters.get(Customer.parameter, as: Customer.IDValue.self) {
            let customer = try await Customer.find(customerID, on: request.db)
            request.customer = customer
        }
        return try await next.respond(to: request)
    }
}

struct CustomerKey: StorageKey {
    typealias Value = Customer
}

extension Request {
    var customer: Customer? {
        get {
            self.storage[CustomerKey.self]
        }
        set {
            self.storage[CustomerKey.self] = newValue
        }
    }
    
    func requireCustomer() throws -> Customer {
        guard let customer = self.customer else {
            throw AppError.customerNotFound
        }
        return customer
    }
}
