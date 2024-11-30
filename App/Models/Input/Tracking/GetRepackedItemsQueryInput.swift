import Vapor

struct GetRepackedItemsQueryInput: Content {
    var products: [String]?
    var agentID: Agent.IDValue
    var searchStrings: [String]?
    @OptionalISO8601Date var fromDate: Date?
    @OptionalISO8601Date var toDate: Date?
}

extension GetRepackedItemsQueryInput {
    enum CodingKeys: String, CodingKey {
        case products
        case agentID
        case searchStrings
        case fromDate
        case toDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.products = try container.decodeIfPresent([String].self, forKey: .products)
        self.agentID = try container.decode(String.self, forKey: .agentID)
        self.searchStrings = try container.decodeIfPresent([String].self, forKey: .searchStrings)
        self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
        self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
    }
}

