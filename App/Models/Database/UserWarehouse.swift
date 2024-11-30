import Foundation
import Vapor
import Fluent

final class UserWarehouse: Model, @unchecked Sendable {
    static let schema: String = "user_warehouses"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Parent(key: "warehouse_id")
    var warehouse: Warehouse
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @OptionalField(key: "index")
    var index: Int?
    
    init() {}
    
    init(userID: User.IDValue, warehouseID: Warehouse.IDValue, index: Int? = nil) {
        self.$user.id = userID
        self.$warehouse.id = warehouseID
        self.index = index
    }
}
