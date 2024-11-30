import Foundation
import Vapor

struct UpdateCustomerBySheetInput: Content {
    var trackingNumber: String
    var customerCode: String
}
