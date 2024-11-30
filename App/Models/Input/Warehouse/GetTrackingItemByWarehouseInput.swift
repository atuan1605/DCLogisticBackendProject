import Vapor
import Foundation

struct GetTrackingItemByWarehouseInput: Content {
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
    var warehouseID: Warehouse.IDValue
    var sortedType: SortedType?
    var agentID: Agent.IDValue
    var orderType: OrderType?
    var page: Int
    var per: Int
}

enum SortedType: String, Content {
    case trackingNumber
    case date
    case productName
    case customerCode
}

enum OrderType: String, Content {
    case desc
    case asc
}

extension GetTrackingItemByWarehouseInput {
    enum CodingKeys: String, CodingKey {
        case fromDate
        case toDate
        case warehouseID
        case sortedType
        case agentID
        case orderType
        case page
        case per
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
        self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
        self.warehouseID = try container.decode(Warehouse.IDValue.self, forKey: .warehouseID)
        self.sortedType = try container.decodeIfPresent(SortedType.self, forKey: .sortedType)
        self.agentID = try container.decode(Agent.IDValue.self, forKey: .agentID)
        self.orderType = try container.decodeIfPresent(OrderType.self, forKey: .orderType)
        self.page = try container.decode(Int.self, forKey: .page)
        self.per = try container.decode(Int.self, forKey: .per)
    }
}
