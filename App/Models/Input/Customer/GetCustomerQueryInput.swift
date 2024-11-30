import Vapor
import Foundation

struct GetCustomersQueryInput: Content {
    let agentID: String
    let searchString: String?
}

extension GetCustomersQueryInput {
    enum CodingKeys: String, CodingKey {
        case agentID
        case searchString
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agentID = try container.decode(Agent.IDValue.self, forKey: .agentID)
        self.searchString = try container.decodeIfPresent(String.self, forKey: .searchString)
    }
}

struct GetCustomersByCodeQueryInput: Content {
    let customerCode: String
}
