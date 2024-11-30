import Foundation
import Vapor

struct GetTrackingItemTimeLineOutput: Content {
    var id: TrackingItem.IDValue
    var action: ActionLogger.ActionType
    var username: String
    var createdAt: Date?
}
