import Vapor
import Foundation

struct GetTrackingByWarehousesInput: Content {
    var sourceWarehouseID: Warehouse.IDValue
    var destinationWarehouseID: Warehouse.IDValue
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
    var page: Int
    var per: Int
}

extension GetTrackingByWarehousesInput {
    enum CodingKeys: String, CodingKey {
        case sourceWarehouseID
        case destinationWarehouseID
        case fromDate
        case toDate
        case page
        case per
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sourceWarehouseID = try container.decode(Warehouse.IDValue.self, forKey: .sourceWarehouseID)
        self.destinationWarehouseID = try container.decode(Warehouse.IDValue.self, forKey: .destinationWarehouseID)
        self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
        self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
        self.page = try container.decode(Int.self, forKey: .page)
        self.per = try container.decode(Int.self, forKey: .per)
    }
    
}
