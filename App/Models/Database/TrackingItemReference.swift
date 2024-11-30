import Vapor
import Foundation
import Fluent

final class TrackingItemReference: Model, @unchecked Sendable {
    static let schema: String = "tracking_item_references"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Field(key: "tracking_number")
    var trackingNumber: String
    
    @Parent(key: "tracking_item_id")
    var trackingItem: TrackingItem
    
    init() { }
    
    init(
        trackingNumber: String,
        trackingItemID: TrackingItem.IDValue,
        deletedAt: Date? = nil
    ) {
        self.trackingNumber = trackingNumber
        self.$trackingItem.id = trackingItemID
        self.deletedAt = deletedAt
    }
}

extension TrackingItemReference: Parameter {}

extension QueryBuilder where Model: TrackingItemReference {
    @discardableResult func filter(trackingNumbers: [String]) -> Self {
        guard !trackingNumbers.isEmpty else {
            return self
        }
        let regexSuffixGroup = trackingNumbers.map {
            $0.suffix(12)
        }.joined(separator: "|")
        let fullRegex = "^.*(\(regexSuffixGroup))$"
        
        return self.group(.or) { builder in
            builder.filter(.sql(raw: "\(TrackingItemReference.schema).tracking_number"), .custom("~*"), .bind(fullRegex))
            builder.group(.and) { andBuilder in
                let fullRegex2 = "^.*(\(regexSuffixGroup))\\d{4}$"
                andBuilder.filter(.sql(raw: "char_length(\(TrackingItemReference.schema).tracking_number)"), .equal, .bind(32))
                andBuilder.filter(.sql(raw: "\(TrackingItemReference.schema).tracking_number"), .custom("~*"), .bind(fullRegex2))
            }
        }
    }
}
