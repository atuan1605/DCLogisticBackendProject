import Vapor
import Foundation

struct UpdateLabelInput: Content {
    var warehouseID: Warehouse.IDValue?
    var agentID: Agent.IDValue?
    var customerID: Customer.IDValue?
    var labelProductName: String?
    var quantity: Int?
    var reference: String?
}
