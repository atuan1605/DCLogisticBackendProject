import Vapor

struct AssignWarehouseInput: Content {
    var warehouseID: Warehouse.IDValue
    var index: Int
}
