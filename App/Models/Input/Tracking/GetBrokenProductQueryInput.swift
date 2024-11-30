import Vapor

struct GetBrokenProductQueryInput: Content {
    var agentID: String?
    var customerFeedback: TrackingItem.CustomerFeedback?
}
