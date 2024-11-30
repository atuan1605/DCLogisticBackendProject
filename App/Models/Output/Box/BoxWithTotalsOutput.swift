import Vapor
import Foundation
import Fluent

struct BoxWithTotalsOutput: Content {
    let id: Box.IDValue?
    let name: String
    let remainingItems: Int
    let totalTrackingItems: Int
    let itemCount: Int
    let customItemCount: Int
}

extension Box {
    func toCommitedOutput(on db: Database) async throws -> BoxWithTotalsOutput {
        let trackingItemPieces = try await self.$pieces.get(on: db)
        let customItemCount = try await self.$customItems.query(on: db).count()
        let remainingItems = trackingItemPieces.filter { $0.receivedAtVNAt == nil }
        return .init(
            id: self.id,
            name: self.name,
            remainingItems: remainingItems.count,
            totalTrackingItems: trackingItemPieces.count,
            itemCount: customItemCount + trackingItemPieces.count,
            customItemCount: customItemCount
        )
    }
}
