import Foundation
import Vapor
import Fluent

final class BoxCustomItem: Model, @unchecked Sendable {
    static let schema: String = "box_custom_items"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "box_id")
    var box: Box

    @Field(key: "reference")
    var reference: String

    @Field(key: "details")
    var details: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(
        boxID: Box.IDValue,
        reference: String,
        details: String
    ) {
        self.$box.id = boxID
        self.reference = reference
        self.details = details
    }
}

extension BoxCustomItem: Parameter { }
