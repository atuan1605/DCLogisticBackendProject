import Vapor
import Foundation
import Fluent

extension ShipmentController {
    func registerCommitedRoutes(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("commited")
        
        groupedRoutes.get(use: getShipmentsCommitedHandler)
        groupedRoutes.grouped("processing").get(use: getProcessingShipmentsHandler)
        groupedRoutes.grouped("done").get(use: getDoneShipmentsHandler)
        
        let boxesRoutes = groupedRoutes
            .grouped(Shipment.parameterPath)
            .grouped(ShipmentIdentifyingMiddleware())
            .grouped("boxes")
            .grouped(Box.parameterPath)
            .grouped(BoxIdentifyingMiddleware())
        
        boxesRoutes.get(use: getBoxDetailHandler)
    }
    
    private func getShipmentsCommitedHandler(req: Request) async throws -> [ShipmentOutput] {
        let shipments = try await Shipment.query(on: req.db)
            .filter(\.$commitedAt != nil)
            .join(Box.self, on: \Box.$shipment.$id == \Shipment.$id)
            .join(TrackingItemPiece.self, on: \TrackingItemPiece.$box.$id == \Box.$id)
            .filter(TrackingItemPiece.self, \.$flyingBackAt != nil)
            .unique()
            .fields(for: Shipment.self)
            .all()
        return try await shipments.asyncMap{
            return try await $0.output(on: req.db)
        }
    }
    
    private func getProcessingShipmentsHandler(req: Request) async throws -> [ShipmentOutput] {
        let shipments = try await Shipment.query(on: req.db)
            .filter(\.$commitedAt != nil)
            .join(Box.self, on: \Box.$shipment.$id == \Shipment.$id, method: .left)
            .join(TrackingItemPiece.self, on: \TrackingItemPiece.$box.$id == \Box.$id, method: .left)
            .filter(TrackingItemPiece.self, \.$flyingBackAt != nil)
            .filter(TrackingItemPiece.self, \.$receivedAtVNAt == nil)
            .with(\.$boxes) {
                $0.with(\.$pieces) {
                    $0.with(\.$trackingItem)
                }
            }
            .unique()
            .fields(for: Shipment.self)
            .all()
        return try await shipments.asyncMap { try await $0.processingOutput() }.sorted(by: { $0.commitedAt!.compare($1.commitedAt!) == .orderedDescending })
    }
    
    private func getDoneShipmentsHandler(req: Request) async throws -> [ShipmentOutput] {
        let shipments = try await Shipment.query(on: req.db)
        .filter(\.$commitedAt != nil)
        .join(Box.self, on: \Box.$shipment.$id == \Shipment.$id)
        .join(TrackingItem.self, on: \TrackingItem.$box.$id == \Box.$id)
        .filter(TrackingItem.self, \.$flyingBackAt != nil)
        .filter(TrackingItem.self, \.$receivedAtVNAt != nil)
        .filter(TrackingItem.self, \.$packedAtVNAt == nil)
        .filter(TrackingItem.self, \.$packBoxCommitedAt == nil)
        .filter(TrackingItem.self, \.$deliveredAt == nil)
        .with(\.$boxes) {
            $0.with(\.$pieces) {
                $0.with(\.$trackingItem)
            }
        }
        .unique()
        .fields(for: Shipment.self)
        .all()
        var targetShipments: [Shipment] = []
        shipments.forEach{ shipment in
            let count = shipment.boxes.filter {
                $0.pieces.allSatisfy { piece in
                    piece.receivedAtVNAt != nil
                }
            }
            .map { $0.pieces }.flatMap { $0 }.count
            if count > 0 {
                targetShipments.append(shipment)
            }
        }
        return try await targetShipments.asyncMap {
            try await  $0.doneOutput() }.sorted(by: { $0.commitedAt!.compare($1.commitedAt!) == .orderedDescending })
    }
    
    private func getBoxDetailHandler(req: Request) async throws -> BoxCommitedDetailOutput {
        _ = try req.requireCommitedShipment()
        let box = try req.requireBox()
        let boxID = try box.requireID()
        
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$flyingBackAt != nil)
            .join(TrackingItemPiece.self, on: \TrackingItemPiece.$trackingItem.$id == \TrackingItem.$id)
            .filter(TrackingItemPiece.self, \.$box.$id == boxID)
            .filter(TrackingItemPiece.self, \.$receivedAtVNAt == nil)
            .unique()
            .fields(for: TrackingItem.self)
            .all()
        
        return BoxCommitedDetailOutput(items: trackingItems)
    }
}
