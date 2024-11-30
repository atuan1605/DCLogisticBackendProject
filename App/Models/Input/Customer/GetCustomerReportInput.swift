import Vapor
import Foundation

struct GetCustomerReportInput: Content {
    var customerIDs: [Customer.IDValue]?
    @OptionalISO8601Date var startDate: Date?
    @OptionalISO8601Date var endDate: Date?
}

extension GetCustomerReportInput {
    enum CodingKeys: String, CodingKey {
        case customerIDs
        case startDate
        case endDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.customerIDs = try container.decodeIfPresent([Customer.IDValue].self, forKey: .customerIDs)
        self._startDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .startDate) ?? .init(date: nil)
        self._endDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .endDate) ?? .init(date: nil)
    }
    
}
