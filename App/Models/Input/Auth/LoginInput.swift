import Foundation
import Vapor

struct LoginInput: Content {
    var username: String
    var password: String
}
