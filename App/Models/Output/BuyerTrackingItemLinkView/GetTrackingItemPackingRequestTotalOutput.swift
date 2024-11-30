import Vapor
import Foundation

struct GetTrackingItemPackingRequestTotalOutput: Content {
    var total: Int
    var processed: Int
    var unprocessed: Int
}
