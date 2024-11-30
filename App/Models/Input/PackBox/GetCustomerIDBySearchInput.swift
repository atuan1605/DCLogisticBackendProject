import Vapor
import Foundation

struct GetCustomerIDBySearchInput: Content {
    var customerID: Customer.IDValue?
}

extension GetCustomerIDBySearchInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("customerID", as: Customer.IDValue.self, required: false)
    }
}
