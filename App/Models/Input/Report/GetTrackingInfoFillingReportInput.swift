import Foundation
import Vapor

struct GetTrackingInfoFillingReportInput: Content {
	@OptionalISO8601Date var fromDate: Date?
	@OptionalISO8601Date var toDate: Date?
	var agentCode: Agent.IDValue
}

extension GetTrackingInfoFillingReportInput {
	enum CodingKeys: String, CodingKey {
		case fromDate
		case toDate
		case agentCode
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.agentCode = try container.decode(Agent.IDValue.self, forKey: .agentCode)
		self._fromDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .fromDate) ?? .init(date: nil)
		self._toDate = try container.decodeIfPresent(OptionalISO8601Date.self, forKey: .toDate) ?? .init(date: nil)
	}
}
