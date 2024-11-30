import Vapor
import Foundation
import Fluent

struct TrackingItemPieceInBoxOutput: Content {
    var id: TrackingItemPiece.IDValue?
    var trackingID: TrackingItem.IDValue?
    var trackingNumber: String
    var files: [String]?
    var productDescription: String?
    var chain: String?
    var totalTrackingInChain: Int?
    var receivedAtVNAt: Date?
    var information: String?
}

extension TrackingItemPiece {
    func toOutput(on db: Database) async throws -> TrackingItemPieceInBoxOutput {
        let trackingItem = try await self.$trackingItem.get(on: db)
        trackingItem.$products.value = try await trackingItem.$products.get(on: db)
        var files = trackingItem.files
        if files.isEmpty, let product = trackingItem.$products.value?.first {
            files = product.images
        }
        let trackingInChainCount = try await TrackingItem.query(on: db)
            .filter(\.$chain == trackingItem.chain)
            .count()
        return .init(
            id: self.id,
            trackingID: try trackingItem.requireID(),
            trackingNumber: trackingItem.trackingNumber,
            files: files,
            productDescription: trackingItem.$products.value?.description,
            chain: trackingItem.chain,
            totalTrackingInChain: trackingInChainCount,
            receivedAtVNAt: self.receivedAtVNAt,
            information: self.information
        )
    }
    
    func toOutput(totalTrackingInChain: Int?) throws -> TrackingItemPieceInBoxOutput {
        guard let trackingItem = self.$trackingItem.value else {
            throw AppError.unknown
        }
        var files = trackingItem.files
        if files.isEmpty, let product = trackingItem.$products.value?.first {
            files = product.images
        }
        return .init(
            id: self.id,
            trackingID: try trackingItem.requireID(),
            trackingNumber: trackingItem.trackingNumber,
            files: files,
            productDescription: trackingItem.$products.value?.description,
            chain: trackingItem.chain,
            totalTrackingInChain: totalTrackingInChain,
            receivedAtVNAt: self.receivedAtVNAt,
            information: self.information
        )
    }
}
