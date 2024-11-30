import Vapor
import Foundation

struct GetTrackingItemsByCustomerQueryInput: Content {
    var agentID: Agent.IDValue
    var customerID: Customer.IDValue?
}

extension GetTrackingItemsByCustomerQueryInput {
    enum CodingKeys: String, CodingKey {
        case agentID
        case customerID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.agentID = try container.decode(Agent.IDValue.self, forKey: .agentID)
        self.customerID = try container.decodeIfPresent(Customer.IDValue.self, forKey: .customerID)
    }
}
