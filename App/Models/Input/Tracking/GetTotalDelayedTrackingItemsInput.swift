import Vapor
import Foundation

struct GetProtractedTrackingItemsInput: Content {
    var agentID: Agent.IDValue
    var warehouseID: Warehouse.IDValue?
}
