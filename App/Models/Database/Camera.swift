import Vapor
import Foundation
import Fluent

final class Camera: Model, @unchecked Sendable {
    static let schema: String = "cameras"
    
    @ID(custom: .id)
    var id: String?
    
    @Field(key: "name")
    var name: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    init() { }
    
    init(id: String?, name: String) {
        self.id = id
        self.name = name
    }
}
