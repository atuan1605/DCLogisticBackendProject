import Foundation
import Vapor

typealias GetTrackingInfoFillingReportOutput = [String: [String: GetTrackingInfoFillingReportByUser]]

struct GetTrackingInfoFillingReportByUser: Content {
	var id: User.IDValue
	var count: Int
	var name: String
}
