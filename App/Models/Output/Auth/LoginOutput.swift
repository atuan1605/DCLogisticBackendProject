import Foundation
import Vapor

struct LoginOutput: Content {
    let refreshToken: String
    let accessToken: String
    let expiredAt: Date
}

extension LoginOutput {
    init(user: User, refreshToken: String, request: Request) throws {
        let newAccessTokenPayload = try user.accessTokenPayload()
        let accessToken = try request.jwt.sign(newAccessTokenPayload)
        
        self.init(
            refreshToken: refreshToken,
            accessToken: accessToken,
            expiredAt: newAccessTokenPayload.exp.value
        )
    }
}
