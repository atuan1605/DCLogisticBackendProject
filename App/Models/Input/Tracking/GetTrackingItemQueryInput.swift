import Vapor

struct GetTrackingItemQueryInput: Content {
    var agentID: Agent.IDValue
    var searchStrings: [String]?
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
    var warehouseID: Warehouse.IDValue?
}

extension GetTrackingItemQueryInput {
    enum CodingKeys: String, CodingKey {
        case agentID
        case searchStrings
        case fromDate
        case toDate
        case warehouseID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agentID = try container.decode(String.self, forKey: .agentID)
        self.searchStrings = try container.decodeIfPresent([String].self, forKey: .searchStrings)
        self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
        self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
        self.warehouseID = try container.decodeIfPresent(Warehouse.IDValue.self, forKey: .warehouseID)
    }
}
