import Vapor
import Foundation

struct CustomerPriceOutput: Content {
    let id: CustomerPrice.IDValue?
    let unitPrice: Int
    let productName: String
}

extension CustomerPrice {
    func toOutput() -> CustomerPriceOutput {
        .init(
            id: self.id,
            unitPrice: self.unitPrice,
            productName: self.productName
        )
    }
}
