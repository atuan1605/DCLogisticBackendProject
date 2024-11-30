import Foundation
import Fluent
import Vapor

struct PaginateLotOutput: Content {
    let id: TrackingItem.IDValue
    let trackingNumber: String
    let products: [ProductOutput]
    let box: BoxOutput?
    let agentID: String?
    let lot: LotOutput?
    let boxedAt: Date?
    let productDescription: String
}

extension TrackingItem {
    
    func toPaginateLotOutput(db: Database) async throws -> PaginateLotOutput {
        let id = try self.requireID()
        let trackingNumber = self.trackingNumber
        let products = self.products.map { $0.toOutput() }
        let productDescription = self.products.description
        let box = try await self.box?.toOutput(on: db)
        let agentID = self.agentCode
        let lot = try await self.box?.lot?.outputWithoutBoxes(on: db)
        return PaginateLotOutput(id: id, trackingNumber: trackingNumber, products: products, box: box, agentID: agentID, lot: lot, boxedAt: self.boxedAt, productDescription: productDescription)
    }
}
