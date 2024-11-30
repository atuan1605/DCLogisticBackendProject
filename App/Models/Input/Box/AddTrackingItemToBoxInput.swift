import Foundation
import Vapor

struct AddTrackingItemToBoxInput: Content {
    var trackingItemID: TrackingItem.IDValue
    var trackingItemPieceID: TrackingItemPiece.IDValue?
}
