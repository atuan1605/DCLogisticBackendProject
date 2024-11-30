import Vapor
import Foundation

struct UnpackByCustomerCodeListOutput: Content {
    var customerCode: String
    var boxCount: Int
    var trackingItemCount: Int
}

extension UnpackByCustomerCodeListOutput {
    init(customer: String, box: Int, trackingItems: Int) {
        self.customerCode = customer
        self.boxCount = box
        self.trackingItemCount = trackingItems
    }
}
