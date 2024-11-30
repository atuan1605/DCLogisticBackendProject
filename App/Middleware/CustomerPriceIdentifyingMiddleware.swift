import Vapor
import Foundation
import Fluent

struct CustomerPriceIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let customerPriceID = request.parameters.get(CustomerPrice.parameter, as: CustomerPrice.IDValue.self) {
            if let customer = request.customer {
                request.customerPrice = try await customer.$prices.query(on: request.db)
                    .filter(\.$id == customerPriceID)
                    .first()
            } else {
                let customerPrice = try await CustomerPrice.find(customerPriceID, on: request.db)
                request.customerPrice = customerPrice
            }
        }
        return try await next.respond(to: request)
    }
}

struct CustomerPriceKey: StorageKey {
    typealias Value = CustomerPrice
}

extension Request {
    var customerPrice: CustomerPrice? {
        get {
            self.storage[CustomerPriceKey.self]
        }
        set {
            self.storage[CustomerPriceKey.self] = newValue
        }
    }
    
    func requireCustomerPrice() throws -> CustomerPrice {
        guard let customerPrice = self.customerPrice else {
            throw AppError.customerPriceNotFound
        }
        return customerPrice
    }
}
