import Vapor
import Foundation
import Fluent

final class TrackingItemPiece: Model, @unchecked Sendable {
    static let schema: String = "tracking_item_pieces"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @OptionalField(key: "boxed_at")
    var boxedAt: Date?
    
    @OptionalField(key: "flying_back_at")
    var flyingBackAt: Date?
    
    @OptionalField(key: "received_at_vn_at")
    var receivedAtVNAt: Date?
    
    @OptionalField(key: "information")
    var information: String?
    
    @Parent(key: "tracking_item_id")
    var trackingItem: TrackingItem
    
    @OptionalParent(key: "box_id")
    var box: Box?

    init() { }
     
    init(
        information: String,
        trackingItemID: TrackingItem.IDValue,
        boxID: Box.IDValue? = nil,
        receivedAtVNAt: Date? = nil,
        boxedAt: Date? = nil,
        flyingBackAt: Date? = nil
    ) {
        self.information = information
        self.$trackingItem.id = trackingItemID
        self.$box.id = boxID
        self.receivedAtVNAt = receivedAtVNAt
        self.boxedAt = boxedAt
        self.flyingBackAt = flyingBackAt
    }
}

extension TrackingItemPiece: Parameter { }
