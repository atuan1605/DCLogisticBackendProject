import Vapor
import Foundation

struct VerifyBuyerInput: Content {
    var buyerID: Buyer.IDValue
    var customerCode: String
}
