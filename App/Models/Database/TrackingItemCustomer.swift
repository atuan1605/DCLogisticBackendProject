import Foundation
import Vapor
import Fluent

final class TrackingItemCustomer: Model, @unchecked Sendable {
    
    static let schema: String = "tracking_item_customers"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "tracking_item_id")
    var trackingItem: TrackingItem
    
    @Parent(key: "customer_id")
    var customer: Customer
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(trackingItemID: TrackingItem.IDValue, customerID: Customer.IDValue) {
        self.$trackingItem.id = trackingItemID
        self.$customer.id = customerID
    }
}

extension TrackingItemCustomer: Parameter { }
