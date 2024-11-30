import Foundation
import Fluent
import Vapor

struct PaginateShipmentOutput: Content {
    let id: TrackingItem.IDValue
    let trackingNumber: String
    let products: [ProductOutput]
    let box: BoxOutput?
    let agentID: String?
    let shipment: ShipmentOutput?
    let boxedAt: Date?
    let productDescription: String
}

extension TrackingItem {
    
    func toPaginateShipmentOutput(db: Database) async throws -> PaginateShipmentOutput {
        let id = try self.requireID()
        let trackingNumber = self.trackingNumber
        let products = self.products.map { $0.toOutput() }
        let productDescription = self.products.description
        let box = try await self.box?.toOutput(on: db)
        let agentID = self.agentCode
        let shipment = try await self.box?.shipment?.outputWithoutBoxes(on: db)
        return PaginateShipmentOutput(id: id, trackingNumber: trackingNumber, products: products, box: box, agentID: agentID, shipment: shipment, boxedAt: self.boxedAt, productDescription: productDescription)
    }
}
