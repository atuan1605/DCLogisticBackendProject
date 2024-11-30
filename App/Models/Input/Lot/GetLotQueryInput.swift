import Vapor
import Foundation

struct GetLotQueryInput: Content {
    var agentID: String?
    var lotIDs: [String]?
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
}

extension GetLotQueryInput {
    enum CodingKeys: String, CodingKey {
        case agentID
        case lotIDs
        case fromDate
        case toDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agentID = try container.decodeIfPresent(String.self, forKey: .agentID)
        self.lotIDs = try container.decodeIfPresent([String].self, forKey: .lotIDs)
        self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
        self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
    }
}
