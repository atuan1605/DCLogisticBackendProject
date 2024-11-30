import Vapor
import Foundation

struct SearchDeliveriesCustomerInput: Content {
    var shipments: [String]?
}
