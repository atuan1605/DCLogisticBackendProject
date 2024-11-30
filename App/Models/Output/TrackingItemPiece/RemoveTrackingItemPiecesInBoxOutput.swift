import Vapor
import Foundation
import Fluent

struct RemoveTrackingItemPiecesInBoxOutput: Content {
    var pieceIDs: [TrackingItemPiece.IDValue]
    var trackingCount: Int
}

extension RemoveTrackingItemPiecesInBoxOutput {
    init(pieceIDs: [TrackingItemPiece.IDValue], count: Int, on db: Database) async throws {
        self.pieceIDs = pieceIDs
        self.trackingCount = count
    }
}
