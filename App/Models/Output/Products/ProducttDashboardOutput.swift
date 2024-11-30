import Vapor
import Foundation

struct ProductDashboardOutput: Content {
    var name: String?
    var quantity: Int?
}

extension Product {
    func toDashboardOutput() -> ProductDashboardOutput {
        .init(
            name: self.description,
            quantity: self.quantity
        )
    }
}
