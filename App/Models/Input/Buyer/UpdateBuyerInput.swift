import Vapor
import Foundation

struct UpdateBuyerInput: Content {
    var id: Buyer.IDValue
    var packingRequest: Int
}
