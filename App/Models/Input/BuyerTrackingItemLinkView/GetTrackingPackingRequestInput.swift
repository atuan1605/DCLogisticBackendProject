import Vapor
import Foundation

struct GetTrackingPackingRequestInput: Content {
    var status: FilterState?
    var page: Int
    var per: Int
    var searchStrings: [String]?
    var agentID: Agent.IDValue?
}

enum FilterState: String, Content {
    case processed
    case unprocessed
}
