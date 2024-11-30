import Vapor
import Foundation

struct GetReturnItemOutput: Content {
    var trackingItemID: TrackingItem.IDValue?
    var trackingNumber: String
    var pieceID: TrackingItemPiece.IDValue?
    var trackingItemPieceInfo: String?
    var boxID: Box.IDValue?
    var boxName: String?
    var status: ReturnStatus?
    
}
enum ReturnStatus: String, Content {
    case processed
    case unprocessed
}
