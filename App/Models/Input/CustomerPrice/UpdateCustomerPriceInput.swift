import Foundation
import Vapor

struct UpdateCustomerPriceInput: Content {
    let productName: String?
    let unitPrice: Int?
}

extension UpdateCustomerPriceInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("unitPrice", as: Int.self, is: .range(1...), required: false)
    }
}
