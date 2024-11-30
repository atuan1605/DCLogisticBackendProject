import Vapor
import Foundation
import Fluent

final class LabelProduct: Model, @unchecked Sendable {
    static let schema = "label_products"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "code")
    var code: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Field(key: "name")
    var name: String
    
    init() {}
    
    init(id: UUID? = nil,
         code: String,
         name: String
    ) {
        self.id = id
        self.code = code
        self.name = name
    }
}
extension LabelProduct: Parameter { }
