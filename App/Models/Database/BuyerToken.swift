//
//  File.swift
//  
//
//  Created by Anh Tuan on 15/02/2024.
//

import Foundation
import Vapor
import Fluent

final class BuyerToken: Model, @unchecked Sendable {
    static let schema = "buyer_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: String

    @Field(key: "expired_at")
    var expiredAt: Date

    @Parent(key: "buyer_id")
    var buyer: Buyer

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(id: UUID? = nil,
         value: String,
         expiredAt: Date = Date().addingTimeInterval(.oneDay*60),
         buyerID: Buyer.IDValue) {
        self.id = id
        self.value = value
        self.$buyer.id = buyerID
        self.expiredAt = expiredAt
    }
}

