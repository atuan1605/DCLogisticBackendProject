//
//  File.swift
//  
//
//  Created by Anh Tuan on 15/02/2024.
//

import Foundation
import Vapor
import Fluent

struct BuyerBasicAuthenticator: BasicAuthenticator {
    func authenticate(basic: BasicAuthorization, for request: Request) -> EventLoopFuture<Void> {
        Buyer.query(on: request.db)
            .group(.or) { builder in
                builder.filter(\.$username == basic.username.lowercased())
                builder.filter(\.$email == basic.username.lowercased())
                builder.filter(\.$phoneNumber == basic.username.lowercased())
            }
            .first()
            .flatMapThrowing
        {
            guard let user = $0 else {
                return
            }
            guard try user.verify(password: basic.password) else {
                return
            }
            request.auth.login(user)
        }
    }
}

