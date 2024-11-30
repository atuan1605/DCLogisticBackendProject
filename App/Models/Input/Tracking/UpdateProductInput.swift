import Foundation
import Vapor

struct UpdateProductInput: Content {
    let id: Product.IDValue?
    let images: [String]?
    let description: String?
    let quantity: Int?
}

extension UpdateProductInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("quantity", as: Int.self, is: .range(1...), required: false)
    }
}


