import Vapor
import Foundation
import Fluent

struct ProductController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("products")
        
        let protected = groupedRoutes.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )
        
        let productRoutes = protected
            .grouped(Product.parameterPath)
            .grouped(ProductIdentifyingMiddleware())
        
        productRoutes.group(ScopeCheckMiddleware(requiredScope: .trackingItems)) {
            $0.get(use: getProductHandler)
        }
    }
    
    private func getProductHandler(request: Request) async throws -> ProductOutput {
        let product = try request.requireProduct()
        return product.toOutput()
    }
}
