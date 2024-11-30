import Foundation
import Vapor

struct GetLooseChainOutput: Content {
	var chain: String
	var customerNames: String
	var items: [TrackingItemOutput]?
}
