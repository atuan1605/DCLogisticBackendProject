import Vapor
import Foundation

struct UpdateUserInput: Content {
    var inactiveUser: Bool
}
