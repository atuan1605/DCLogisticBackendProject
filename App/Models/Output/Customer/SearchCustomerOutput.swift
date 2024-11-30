import Vapor
import Foundation

struct SearchCustomerOutput: Content {
    var customerCount: Int?
    var trackingItemCount: Int?
    var customers: [CustomerOutput]?
}
