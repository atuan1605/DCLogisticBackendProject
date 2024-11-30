import Foundation
import Vapor

struct RefreshTokenInput: Content {
    var refreshToken: String
}
