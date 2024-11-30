import Vapor
import Fluent
import Foundation

final class Lot: Model, @unchecked Sendable {
    static let schema: String = "lots"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Field(key: "lot_index")
    var lotIndex: String
    
    @Children(for: \.$lot)
    var boxes: [Box]
    
    init() { }
    
    init(
        lotIndex: String
    ) {
        self.lotIndex = lotIndex
    }
}

extension Lot: Parameter { }
