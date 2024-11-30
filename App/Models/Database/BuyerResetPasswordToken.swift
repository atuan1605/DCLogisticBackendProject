import Foundation
import Vapor
import Fluent

final class BuyerResetPasswordToken: Model, @unchecked Sendable {
    static let schema: String = "buyer_reset_password_tokens"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "buyer_id")
    var buyer: Buyer

    @Field(key: "value")
    var value: String

    init() { }

    init(buyerID: Buyer.IDValue, value: String) {
        self.$buyer.id = buyerID
        self.value = value
    }
}

extension Buyer {
    func generateResetPasswordToken() throws -> BuyerResetPasswordToken {
        try .init(
            buyerID: self.requireID(),
            value: .randomCode()
        )
    }
}
