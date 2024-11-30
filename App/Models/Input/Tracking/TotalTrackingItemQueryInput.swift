import Fluent
import Foundation
import Vapor

struct TotalTrackingItemQueryInput: Content {
    @ISO8601Date var fromDate: Date
    @ISO8601Date var toDate: Date
    var page: Int
    var per: Int
    var agentIDs: [Agent.IDValue]?
    var warehouseIDs: [Warehouse.IDValue]?
}

extension TotalTrackingItemQueryInput {
    enum CodingKeys: String, CodingKey {
        case fromDate
        case toDate
        case page
        case per
        case agentIDs
        case warehouseIDs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self._fromDate = try container.decode(ISO8601Date.self, forKey: .fromDate)
        self._toDate = try container.decode(ISO8601Date.self, forKey: .toDate)
        self.page = try container.decode(Int.self, forKey: .page)
        self.per = try container.decode(Int.self, forKey: .per)
        self.agentIDs = try container.decodeIfPresent([Agent.IDValue].self, forKey: .agentIDs)
        self.warehouseIDs = try container.decodeIfPresent([Warehouse.IDValue].self, forKey: .warehouseIDs)
    }
}
