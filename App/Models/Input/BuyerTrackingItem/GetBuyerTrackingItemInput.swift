import Foundation
import Vapor

struct GetBuyerTrackingItemInput: Content {
    var filteredStates: [TrackingItem.Status]
    var searchString: String?
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
}

