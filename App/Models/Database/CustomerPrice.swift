import Vapor
import Foundation
import Fluent

final class CustomerPrice: Model, @unchecked Sendable {
    static let schema: String = "customer_prices"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "customer_id")
    var customer: Customer
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Field(key: "unit_price")
    var unitPrice: Int
    
    @Field(key: "product_name")
    var productName: String
    
    init() { }
    
    init(
        customerID: Customer.IDValue,
        unitPrice: Int,
        productName: String
    ) {
        self.$customer.id = customerID
        self.unitPrice = unitPrice
        self.productName = productName
    }
}

extension CustomerPrice: Parameter { }
