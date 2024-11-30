import Vapor
import Foundation
import Fluent

final class Agent: Model, @unchecked Sendable {
    static let schema: String = "agents"

    @ID(custom: .id)
    var id: String?

    @Field(key: "name")
    var name: String

    @Field(key: "popular_products")
    var popularProducts: [String]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    init() { }
    
    init(
        id: String?,
        name: String,
        popularProducts: [String] = ["iPad, iPhone, AirPod, Clothes"]
    ) {
        self.id = id
        self.name = name
        self.popularProducts = popularProducts
    }
}
