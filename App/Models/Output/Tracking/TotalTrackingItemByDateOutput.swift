import Vapor
import Foundation

struct TotalTrackingItemByDateOutput: Content {
    var receivedAtUSAt: Date?
    var allItems: Int?
    var flyingBackItems: Int?
    var itemWithFiles: Int?
    var unflyingBackItems: Int?
}
