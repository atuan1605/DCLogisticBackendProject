import Vapor
import Foundation
import Fluent

struct GetShipmentPaginatedOnWebOutput: Content {
    var id: Shipment.IDValue?
    var shipmentCode: String
    var createdAt: Date?
    var boxes: [BoxOutput]?
    var commitedAt: Date?
}

extension Shipment {
    func output() -> GetShipmentPaginatedOnWebOutput {
        return .init(
            id: self.id,
            shipmentCode: self.shipmentCode,
            createdAt: self.createdAt,
            boxes: self.boxes.map({ $0.output() }),
            commitedAt: self.commitedAt
        )
    }

    func toListOutput(groupedChain: [String?: [TrackingItem]], on db: Database) async throws -> GetShipmentPaginatedOnWebOutput {
        return await .init(
            id: self.id,
            shipmentCode: self.shipmentCode,
            createdAt: self.createdAt,
            boxes: try self.boxes.asyncMap({ try await $0.toOutput(groupedChain: groupedChain, on: db) }),
            commitedAt: self.commitedAt
        )
    }
}
