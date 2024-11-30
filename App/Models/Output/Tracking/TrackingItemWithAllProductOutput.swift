import Foundation
import Vapor

struct TrackingItemWithAllProduct: Content {
    var id: TrackingItem.IDValue?
    var trackingNumber: String
    var customerCode: String?
    var agentCode: String?
    var receivedAtUSAt: Date?
    var status: TrackingItem.Status?
    var files: [String]?
    var itemDescription: String?
    var customers: [CustomerOutput]?
}

extension TrackingItem {
    func outputWithProduct() -> TrackingItemWithAllProduct {
        var files: [String] = self.files
        if let products = self.$products.value {
            products.forEach { product in
                files.append(contentsOf: product.images)
            }
        }
        let customers = self.$customers.value?.map { $0.output() }
        return .init(
            id: self.id,
            trackingNumber: self.trackingNumber,
            customerCode: self.$customers.value?.map(\.customerCode).joined(separator: ", "),
            agentCode: self.agentCode,
            receivedAtUSAt: self.receivedAtUSAt,
            status: self.status,
            files: files,
            itemDescription: self.itemDescription,
            customers: customers
        )
    }
}
