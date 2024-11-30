import Vapor
import Foundation

struct UpdateTrackingItemsInput: Content {
    var trackingItemIDs: [TrackingItem.IDValue]
    var agentID: Agent.IDValue
}
