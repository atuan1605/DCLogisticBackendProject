import Vapor
import Foundation

struct ProductOutput: Content {
    let id: Product.IDValue?
    let images: [String]
    let index: Int
    let description: String
    let quantity: Int
}

extension Product {
    func toOutput() -> ProductOutput {
        .init(
            id: self.id,
            images: self.images,
            index: self.index,
            description: self.description,
            quantity: self.quantity
        )
    }
}
