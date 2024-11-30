import Vapor
import Foundation

struct GetLabelQueryInput: Content {
    var warehouseID: Warehouse.IDValue?
    var agentID: Agent.IDValue?
}
