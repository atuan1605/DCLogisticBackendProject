import Vapor
import Foundation
import Fluent

struct LabelProductIdentifyingMiddleWare: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let labelProductID = request.parameters.get(LabelProduct.parameter, as: LabelProduct.IDValue.self) {
            let labelProduct = try await LabelProduct.find(labelProductID, on: request.db)
            request.labelProduct = labelProduct
        }
        return try await next.respond(to: request)
    }
}

struct LabelProductKey: StorageKey {
    typealias Value = LabelProduct
}

extension Request {
    var labelProduct: LabelProduct? {
        get {
            self.storage[LabelProductKey.self]
        }
        set {
            self.storage[LabelProductKey.self] = newValue
        }
    }
    
    func requireLabelProduct() throws -> LabelProduct {
        guard let labelProduct = self.labelProduct else {
            throw AppError.productNotFound
        }
        return labelProduct
    }
}
