import Vapor

struct GetReceivedAtUSItemsQueryInput: Content {
    var agentID: Agent.IDValue
    var searchStrings: [String]?
    var month: Int?
}

extension GetReceivedAtUSItemsQueryInput {
    enum CodingKeys: String, CodingKey {
        case agentID
        case searchStrings
        case month
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agentID = try container.decode(String.self, forKey: .agentID)
        self.searchStrings = try container.decodeIfPresent([String].self, forKey: .searchStrings)
        self.month = try container.decodeIfPresent(Int.self, forKey: .month)
    }
}

