import Vapor
import Foundation

struct UpdateTrackingStatusBySheetInput: Content {
	var date: String
	var trackingNumber: String
	var sheetName: String
	var state: TrackingItem.Status
    var pieces: [String]?
}
