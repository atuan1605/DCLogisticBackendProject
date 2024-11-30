import Vapor
import Foundation

struct GetTrackingItemVideosByCustomerRequestInput: Content {
    var searchStrings: [String]?
}
