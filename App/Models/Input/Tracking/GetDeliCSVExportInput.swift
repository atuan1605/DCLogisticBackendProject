import Foundation
import Vapor

struct GetDeliCSVExportInput: Content {
    var agentCode: String?
    var customerID: Customer.IDValue?
    @ISO8601Date var fromDate: Date
    @ISO8601Date var toDate: Date
    var targetStatus: TrackingItem.Status
    var timeZone: String?
    var warehouseID: Warehouse.IDValue?
}
