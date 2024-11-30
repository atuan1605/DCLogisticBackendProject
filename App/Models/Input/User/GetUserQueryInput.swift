import Vapor

struct GetUserQueryInput: Content {
    var agentCode: Agent.IDValue?
    var username: String?
    var warehouseID: Warehouse.IDValue?
}
