import Vapor
import Foundation
import Fluent

final class Delivery: Model, @unchecked Sendable {
    static let schema: String = "delivery"
    
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

    @OptionalField(key: "commited_at")
    var commitedAt: Date?
    
    @OptionalField(key: "images")
    var images: [String]?
    
    @Children(for: \.$delivery)
    var packBoxes: [PackBox]

    @Parent(key: "customer_id")
    var customer: Customer

    init() { }
    
    init(
        name: String,
        images: [String]? = nil,
        commitedAt: Date? = nil,
        customerID: Customer.IDValue
    ) {
        self.name = "Default"
        self.$customer.id = customerID
        self.images = images
        self.commitedAt = commitedAt
    }
    
}

extension Delivery: Parameter { }
