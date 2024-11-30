import Foundation
import Vapor

struct ValidateResetPasswordTokenInput: Content {
    var token: String
}

