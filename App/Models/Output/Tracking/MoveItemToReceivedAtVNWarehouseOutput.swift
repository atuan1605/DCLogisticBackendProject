import Vapor
import Foundation
import Fluent

struct MoveItemToReceivedAtVNWarehouseOutput: Content {
    let boxName: String
    let remainingItemsCount: Int
    let totalItemsCount: Int
}

extension MoveItemToReceivedAtVNWarehouseOutput {
    init(box: Box, on db: Database) async throws {
        let trackingItemPieces = try await box.$pieces.get(on: db)
        let remainingItems = trackingItemPieces.filter {
            $0.receivedAtVNAt == nil
        }
        self.boxName = box.name
        self.remainingItemsCount = remainingItems.count
        self.totalItemsCount = trackingItemPieces.count
    }
}
