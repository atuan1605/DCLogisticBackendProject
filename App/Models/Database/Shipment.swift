import Vapor
import Fluent
import Foundation

final class Shipment: Model, @unchecked Sendable {
    static let schema: String = "shipments"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Field(key: "shipment_code")
    var shipmentCode: String
    
    @Children(for: \.$shipment)
    var boxes: [Box]
    
    @OptionalField(key: "commited_at")
    var commitedAt: Date?
    
    init() { }
    
    init(
        shipmentCode: String,
        commitedAt: Date? = nil
        
    ) {
        self.shipmentCode = shipmentCode
        self.commitedAt = commitedAt
    }
    
}
extension Shipment: Parameter { }


