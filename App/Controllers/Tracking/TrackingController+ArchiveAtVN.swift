import Vapor
import Foundation
import Fluent

struct TrackingArchiveAtVnController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group(ScopeCheckMiddleware(requiredScope: .vnInventory)) {
            let groupedRoutes = $0.grouped("archived")
            groupedRoutes.get(use: getArchivedItemsHandler)
            
            let trackingItemRoutes = groupedRoutes
                .grouped(TrackingItem.parameterPath)
                .grouped(TrackingItemIdentifyingMiddleware())
            
            trackingItemRoutes.group(ScopeCheckMiddleware(requiredScope: .updateTrackingItems)) {
                $0.post("moveToUnboxed", use: moveToUnboxed)
            }
        }
       
        routes.group(ScopeCheckMiddleware(requiredScope: .updateTrackingItems)) {
            $0.post("moveToArchived", use: moveToArchived)
        }
    }

    private func getArchivedItemsHandler(req: Request) async throws -> GetArchivedItemsOutput {
        let archiveAtVNItems = try await TrackingItem.query(on: req.db)
            .filter(\.$deliveredAt == nil)
            .filter(\.$packBoxCommitedAt == nil)
            .filter(\.$packedAtVNAt == nil)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$archivedAt != nil)
            .with(\.$box){
                $0.with(\.$shipment)
            }
            .all()
        return GetArchivedItemsOutput(items: archiveAtVNItems)
    }
    
    private func moveToArchived(req: Request) async throws -> TrackingItemOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .updateTrackingItems) else {
            throw AppError.invalidScope
        }
        try UpdateTrackingItemToArchivedInput.validate(content: req)
        let input = try req.content.decode(UpdateTrackingItemToArchivedInput.self)
        
        let existingTrackingItem = try await TrackingItem.query(on: req.db)
            .filter(trackingNumbers: [input.trackingNumber])
            .first()

        guard existingTrackingItem == nil else {
            throw AppError.trackingNumberAlreadyOnSystem
        }

        let trackingItem = try input.toTrackingItem()
        
        if let payload = try await trackingItem.moveToStatus(to: .archiveAtVN, database: req.db) {
            try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
        }
        
        let shipment = try await Shipment.query(on: req.db).filter(\.$shipmentCode == input.shipmentCode).first()
        let box = try await shipment?.$boxes.query(on: req.db).filter(\.$name == input.boxName).first()
        if let shipment = shipment, let box = box {
            trackingItem.$box.id = box.id
            try await trackingItem.save(on: req.db)
            try req.appendUserAction(.assignShipment(trackingItemID: trackingItem.requireID(), shipmentID: shipment.requireID().uuidString))
        }
        else {
            try await trackingItem.save(on: req.db)
            try req.appendUserAction(.assignShipment(trackingItemID: trackingItem.requireID(), shipmentID: input.shipmentCode))
        }
        try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: .archiveAtVN))
        
        return trackingItem.output()
    }
    
    private func moveToUnboxed(req: Request) async throws -> TrackingItemOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .vnWarehouse) else {
            throw AppError.invalidScope
        }
        let trackingItem = try req.requireTrackingItem()
        _ = try trackingItem.requireID()
        let customerCount = try await trackingItem.$customers.query(on: req.db).count()
        guard trackingItem.agentCode != nil, customerCount > 0
        else {
            throw AppError.itemIsNotEnoughInformation
        }

        if let payload = try await trackingItem.moveToStatus(to: .receivedAtVNWarehouse, database: req.db) {
            try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
        }
        try await trackingItem.save(on: req.db)
        try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: .receivedAtVNWarehouse))
        
        return trackingItem.output()
    }
}
