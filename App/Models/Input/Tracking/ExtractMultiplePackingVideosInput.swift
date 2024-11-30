import Vapor
import Foundation

struct ExtractMultiplePackingVideosInput: Content {
    let trackingItemIDs: [TrackingItem.IDValue]
}
