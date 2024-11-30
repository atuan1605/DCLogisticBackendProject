import Foundation
import Vapor

struct BuyerTrackingItemCountOutput: Content {
    var receivedAtUSWarehouseCount: Int
    var flyingBackCount: Int
    var receivedAtVNWarehouseCount: Int
}
