import Vapor
import Foundation

struct AddTrackingItemsToNewBoxInput: Content {
    var trackingPieceIDs: [TrackingItemPiece.IDValue]
    var boxID: Box.IDValue
}
