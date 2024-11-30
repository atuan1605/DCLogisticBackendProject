import Vapor
import Fluent
import Foundation

final class Box: Model, @unchecked Sendable {
    static let schema = "boxes"
    
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
    
    @OptionalField(key: "weight")
    var weight: Double?
    
    @OptionalField(key: "agent_code")
    var agentCodes: [String]?
    
    @OptionalParent(key: "shipment_id")
    var shipment: Shipment?
    
    @Children(for: \.$box)
    var customItems: [BoxCustomItem]
    
    @OptionalParent(key: "lot_id")
    var lot: Lot?
    
    @Children(for: \.$box)
    var pieces: [TrackingItemPiece]
    
    init() { }
    
    init(
        name: String,
        weight: Double? = nil,
        agentCodes: [String]? = nil,
        lotID: Lot.IDValue
    ) {
        self.name = name
        self.weight = weight
        self.agentCodes = agentCodes
        self.$lot.id = lotID
    }
}

extension Box: Parameter { }


