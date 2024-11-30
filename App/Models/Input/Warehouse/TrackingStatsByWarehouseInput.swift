import Foundation
import Vapor

struct TrackingStatsByWarehouseInput: Content {
    let agentID: String
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
}

extension TrackingStatsByWarehouseInput {
    enum CodingKeys: String, CodingKey {
        case agentID
        case fromDate
        case toDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agentID = try container.decode(String.self, forKey: .agentID)
        self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
        self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
    }
}
