import Vapor
import Foundation

struct GetTrackingItemReportsQueryInput: Content {
    var searchStrings: [String]?
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
    var searchType: SearchType?
    var page: Int
    var per: Int
    var agentIDs: [Agent.IDValue]?
    var warehouseIDs: [Warehouse.IDValue]?
}

enum SearchType: String, Codable {
    case total, flyingBack, files, unflyingBack
}

extension GetTrackingItemReportsQueryInput {
    enum CodingKeys: String, CodingKey {
        case searchStrings
        case fromDate
        case toDate
        case searchType
        case page
        case per
        case agentIDs
        case warehouseIDs
        
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.searchStrings = try container.decodeIfPresent([String].self, forKey: .searchStrings)
        self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
        self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
        self.searchType = try container.decodeIfPresent(SearchType.self, forKey: .searchType)
        self.page = try container.decode(Int.self, forKey: .page)
        self.per = try container.decode(Int.self, forKey: .per)
        self.agentIDs = try container.decodeIfPresent([Agent.IDValue].self, forKey: .agentIDs)
        self.warehouseIDs = try container.decodeIfPresent([Warehouse.IDValue].self, forKey: .warehouseIDs)
    }
}
