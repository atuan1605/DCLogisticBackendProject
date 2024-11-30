import Foundation
import Vapor

struct ResetPasswordInput: Content {
    var resetPasswordToken: String
    var password: String
    var confirmPassword: String
}
