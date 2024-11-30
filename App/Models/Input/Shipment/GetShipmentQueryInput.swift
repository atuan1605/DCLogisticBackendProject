import Vapor

struct GetShipmentQueryInput: Content {
    var agentID: String?
    var shipmentIDs: [String]?
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
}

extension GetShipmentQueryInput {
    enum CodingKeys: String, CodingKey {
        case agentID
        case shipmentIDs
        case fromDate
        case toDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agentID = try container.decodeIfPresent(String.self, forKey: .agentID)
        self.shipmentIDs = try container.decodeIfPresent([String].self, forKey: .shipmentIDs)
        self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
        self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
    }
}

