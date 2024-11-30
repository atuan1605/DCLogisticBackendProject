import Vapor
import Foundation

struct UpdateCustomerCodeInChainInput: Content {
    let customerID: Customer.IDValue?
    let customerCode: String?
}
