import Vapor
import Foundation

struct ChangeWarehouseInput: Content {
    var trackingNumber: String
    var destinationWarehouseID: Warehouse.IDValue
    var sourceWarehouseID: Warehouse.IDValue
}
