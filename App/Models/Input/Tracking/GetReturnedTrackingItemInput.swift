import Vapor
import Foundation

struct GetReturnedTrackingItemInput: Content {
    var holdState: TrackingItem.HoldState?
    var searchStrings: [String]?
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
    var status: Status?
    var per: Int
    var page: Int
}

extension GetReturnedTrackingItemInput {
    enum Status: String, Content {
        case holded
        case packingRequest
    }
}
