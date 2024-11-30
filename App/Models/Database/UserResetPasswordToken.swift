import Vapor
import Foundation
import Fluent

final class UserResetPasswordToken: Model, @unchecked Sendable {
    static let schema: String = "user_reset_password_tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "value")
    var value: String
    
    init() { }
    
    init(userID: User.IDValue, value: String) {
        self.$user.id = userID
        self.value = value
    }
}

extension User {
    func generateResetPasswordToken() throws -> UserResetPasswordToken {
        try .init(
            userID: self.requireID(),
            value: .randomCode())
    }
}
