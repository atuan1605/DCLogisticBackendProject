import Vapor
import Foundation
import Fluent

struct ProductIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let productID =
            request.parameters.get(Product.parameter, as: Product.IDValue.self) {
            if let trackingItem = request.trackingItem {
                request.product = try await trackingItem.$products.query(on: request.db)
                    .filter(\.$id == productID)
                    .first()
            } else {
                let product = try await
                Product.find(productID, on: request.db)
                request.product = product
            }
        }
        return try await next.respond(to: request)
    }
}

struct ProductKey: StorageKey {
    typealias Value = Product
}

extension Request {
    var product: Product? {
        get {
            self.storage[ProductKey.self]
        }
        set {
            self.storage[ProductKey.self] = newValue
        }
    }
    
    func requireProduct() throws -> Product {
        guard let product = self.product else {
            throw AppError.productNotFound
        }
        return product
    }
}
