//
//  File.swift
//  
//
//  Created by Anh Tuan on 15/02/2024.
//

import Foundation
import Vapor
import JWT

struct BuyerJWTAuthenticator: JWTAuthenticator {
    typealias Payload = Buyer.AccessTokenPayload
    
    func authenticate(jwt: Buyer.AccessTokenPayload, for request: Request) -> EventLoopFuture<Void> {
        print("running jwt \(jwt.sub.value)")
        guard let buyerID = Buyer.IDValue.init(jwt.sub.value) else {
            return request.eventLoop.future()
        }
        return Buyer.find(buyerID, on: request.db)
            .flatMapThrowing
        {
            guard let buyer = $0 else {
                return
            }
            request.auth.login(buyer)
        }
    }
}
