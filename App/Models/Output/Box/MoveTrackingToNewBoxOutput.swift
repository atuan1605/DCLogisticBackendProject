import Fluent
import Foundation
import Vapor

struct MoveTrackingToNewBoxOutput: Content {
    var oldBoxCount: Int
    var newBoxCount: Int
    var changedItems: [TrackingItemPieceInBoxOutput]
}

extension MoveTrackingToNewBoxOutput {
    init(oldBoxCount: Int, newBoxCount: Int, items: [TrackingItemPiece], on db: Database) async throws {
        self.oldBoxCount = oldBoxCount
        self.newBoxCount = newBoxCount
        self.changedItems = try await items.asyncMap { try await $0.toOutput(on: db)}
    }
}
