import Vapor
import Fluent
import Foundation

final class PackBox: Model, @unchecked Sendable {
    static let schema = "pack_boxes"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "customer_code")
    var customerCode: String
    
    @OptionalField(key: "commited_at")
    var commitedAt: Date?
    
    @OptionalField(key: "weight")
    var weight: Double?
    
    @Children(for: \.$packBox)
    var trackingItems: [TrackingItem]
    
    @OptionalParent(key: "delivery_id")
    var delivery: Delivery?
    
    @Parent(key: "customer_id")
    var customer: Customer

    init() { }
    
    init(
        name: String,
        weight: Double? = nil,
        commitedAt: Date? = nil,
        customerCode: String,
        customerID: Customer.IDValue
    ) {
        self.name = name
        self.weight = weight
        self.commitedAt = commitedAt
        self.customerCode = customerCode
        self.$customer.id = customerID
    }
}

extension PackBox: Parameter { }
