import Vapor
import Foundation

struct RequestResetPasswordInput: Content {
    var username: String
}
