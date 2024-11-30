import Foundation
import Vapor
import Fluent

struct TrackingReceivedAtVNController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("receivedAtVN")
        
        groupedRoutes.group(ScopeCheckMiddleware(requiredScope: .vnInventory)) {
            $0.get(use: getReceivedAtVNItemsHandler)
        }

        let trackingItemRoutes = routes
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())
        let boxRoutes = trackingItemRoutes
            .grouped("boxes")
            .grouped(Box.parameterPath)
            .grouped(BoxIdentifyingMiddleware())
        boxRoutes.get("pieces","receivedAtVN", use: getTrackingItemPiecesHandler)
        
        let pieceRoutes = trackingItemRoutes
            .grouped("pieces")
            .grouped(TrackingItemPiece.parameterPath)
            .grouped(TrackingItemPieceIdentifyingMiddleware())
        
        pieceRoutes.group(ScopeCheckMiddleware(requiredScope: .updateTrackingItems)) {
            $0.post("moveToUnboxed", use: moveToReceivedAtVNWarehouse)
        }
    }
    
    private func getReceivedAtVNItemsHandler(req: Request) async throws -> GetReceivedAtVNItemsOutput {
        let receivedAtVnItems = try await TrackingItem.query(on: req.db)
            .with(\.$customers)
            .filter(\.$deliveredAt == nil)
            .filter(\.$packBoxCommitedAt == nil)
            .filter(\.$packedAtVNAt == nil)
            .filter(\.$receivedAtVNAt != nil)
            .all()
        return GetReceivedAtVNItemsOutput(items: receivedAtVnItems)
    }
    
    private func moveToReceivedAtVNWarehouse(req: Request) async throws -> MoveItemToReceivedAtVNWarehouseOutput {
        let trackingItem = try req.requireTrackingItem()
        let piece = try req.requiredTrackingItemPiece()
        guard piece.$box.id != nil else {
            throw AppError.boxIDIsNil
        }
        let trackingItemPiecesCount = try await trackingItem.$pieces.query(on: req.db)
            .filter(\.$receivedAtVNAt == nil)
            .all().count
        
        guard let targetBox = try await piece.$box.get(on: req.db) else {
            throw AppError.boxNotFound
        }
        
        if trackingItemPiecesCount == 1 {
            if let payload = try await trackingItem.moveToStatus(to: .receivedAtVNWarehouse, database: req.db) {
                try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
            }
            try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: .receivedAtVNWarehouse))
            try await trackingItem.save(on: req.db)
        }
        let now = Date()
        piece.receivedAtVNAt = now
        try await piece.save(on: req.db)
        try await targetBox.$pieces.load(on: req.db)
        return try await MoveItemToReceivedAtVNWarehouseOutput(box: targetBox, on: req.db)
    }
    
    private func getTrackingItemPiecesHandler(req: Request) async throws -> [GetTrackingItemPieceOutput] {
        let item = try req.requireTrackingItem()
        let boxID = try req.requireBox().requireID()
        let trackingItemPieces = try await item.$pieces.query(on: req.db)
            .filter(\.$flyingBackAt != nil)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$box.$id == boxID)
            .with(\.$trackingItem)
            .all()
        return trackingItemPieces.map {
            $0.output(trackingNumber: item.trackingNumber)
        }
    }
}
