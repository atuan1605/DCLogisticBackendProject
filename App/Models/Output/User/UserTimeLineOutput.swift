import Vapor
import Foundation

struct UserTimeLineOutput: Content {
    var id: User.IDValue
    var action: ActionLogger.ActionType
    var username: String
    var createdAt: Date?
}
