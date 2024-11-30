import Foundation
import Vapor
import Fluent

final class BuyerTrackingItemLinkView: Model, @unchecked Sendable {
    static let schema: String = "buyer_tracking_item_link_view"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "buyer_tracking_item_id")
    var buyerTrackingItem: BuyerTrackingItem

    @Parent(key: "tracking_item_id")
    var trackingItem: TrackingItem

    @Field(key: "buyer_tracking_number")
    var buyerTrackingNumber: String

    @Field(key: "tracking_item_tracking_number")
    var trackingItemTrackingNumber: String

    init() { }
}

