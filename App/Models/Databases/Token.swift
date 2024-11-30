//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Vapor
import Fluent

// Refresh token
final class Token: Model, @unchecked Sendable {
    static let schema = "tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Parent(key: "userID")
    var user: User

    @Field(key: "expired_at")
    var expiredAt: Date

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        value: String,
        userID: User.IDValue,
        expiredAt: Date = Date().addingTimeInterval(.oneDay*10)
    ) {
        self.value = value
        self.$user.id = userID
        self.expiredAt = expiredAt
    }
}

extension Token {
    func resetExpiredAtDate() {
        self.expiredAt = Date().addingTimeInterval(.oneDay*10)
    }

    static func generate(for user: User) throws -> Token {
        let random = [UInt8].random(count: 16).base64
        return try Token(value: random, userID: user.requireID())
    }
}

extension Token: ModelTokenAuthenticatable {
    static var valueKey: KeyPath<Token, Field<String>> {
        return \Token.$value
    }
    
    static var userKey: KeyPath<Token, Parent<User>> {
        return \Token.$user
    }
//
//    static let valueKey = \Token.$value
//    static let userKey = \Token.$user
  
    typealias User = App.User

    var isValid: Bool { true }
}

