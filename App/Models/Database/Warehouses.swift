import Foundation
import Fluent
import Vapor

final class Warehouse: Model, @unchecked Sendable {
    static let schema: String = "warehouses"
    
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
    
    @OptionalField(key: "address")
    var address: String?
    
    @OptionalField(key: "inactive_at")
    var inactiveAt: Date?
    
    @Siblings(through: UserWarehouse.self, from: \.$warehouse, to: \.$user)
    var users: [User]

    @OptionalField(key: "dvr_account")
    var dvrAccount: String?
    
    @OptionalField(key: "dvr_password")
    var dvrPassword: String?
    
    @OptionalField(key: "dvr_domain")
    var dvrDomain: String?

    @OptionalField(key: "reference")
    var reference: String?
    
    init() {}
    
    init(name: String, address: String? = nil) {
        self.name = name
        self.address = address
    }
}

extension Warehouse: Parameter {}
