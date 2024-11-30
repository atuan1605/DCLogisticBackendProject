import Foundation
import Vapor
import JWT

struct UserJWTAuthenticator: JWTAuthenticator {
    typealias Payload = User.AccessTokenPayload

    func authenticate(jwt: User.AccessTokenPayload, for request: Request) -> EventLoopFuture<Void> {
        print("running jwt \(jwt.sub.value)")
        guard let userID = User.IDValue.init(jwt.sub.value) else {
            return request.eventLoop.future()
        }
        
        return User.find(userID, on: request.db)
            .flatMapThrowing
        {
            guard let user = $0 else {
                return
            }
            request.auth.login(user)
        }
    }
}

extension Request {
    func requireAuthUser() throws -> User {
        return try self.auth.require(User.self)
    }

    func requireAuthUserID() throws -> User.IDValue {
        return try self.requireAuthUser().requireID()
    }
    
    func requireAuthBuyer() throws -> Buyer {
        return try self.auth.require(Buyer.self)
    }
    
    func requireAuthBuyerID() throws -> Buyer.IDValue {
        return try self.requireAuthBuyer().requireID()
    }
}
