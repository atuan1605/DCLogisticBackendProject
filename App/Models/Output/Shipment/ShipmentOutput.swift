import Vapor
import Foundation
import Fluent

struct ShipmentOutput: Content {
    let id: Shipment.IDValue?
    let shipmentCode: String
    let commitedAt: Date?
    let boxesCount: Int?
    let trackingitemsCount: Int?
    let boxes: [BoxWithTotalsOutput]?
    let totalWeight: Double?
}

extension Shipment {
    func output(on db: Database) async throws -> ShipmentOutput{
        let boxes = try await self.$boxes.get(on: db)
        return .init(
            id: self.id,
            shipmentCode: self.shipmentCode,
            commitedAt: self.commitedAt,
            boxesCount: self.$boxes.value?.count,
            trackingitemsCount: nil,
            boxes: try await boxes.asyncMap{
                return try await $0.toCommitedOutput(on: db)
            },
            totalWeight: boxes.compactMap(\.weight).reduce(0, +)
        )
    }
    
    func outputWithoutBoxes(on db: Database) async throws -> ShipmentOutput{
        let boxes = try await self.$boxes.get(on: db)
        return .init(
            id: self.id,
            shipmentCode: self.shipmentCode,
            commitedAt: self.commitedAt,
            boxesCount: self.$boxes.value?.count,
            trackingitemsCount: nil,
            boxes: nil,
            totalWeight: boxes.compactMap(\.weight).reduce(0, +)
        )
    }

    func processingOutput() async throws -> ShipmentOutput {
        let boxes = self.boxes
        let pieces = boxes.flatMap { $0.pieces }
        return .init(
            id: self.id,
            shipmentCode: self.shipmentCode,
            commitedAt: self.commitedAt,
            boxesCount: boxes.count,
            trackingitemsCount: try pieces.compactMap { $0.trackingItem }.removingDuplicates{ $0.id }.count,
            boxes: nil,
            totalWeight: boxes.compactMap(\.weight).reduce(0, +)
        )
    }
    
    func doneOutput() async throws -> ShipmentOutput {
        let boxes = self.boxes
        let pieces = boxes.flatMap { $0.pieces }
        return .init(
            id: self.id,
            shipmentCode: self.shipmentCode,
            commitedAt: self.commitedAt,
            boxesCount: boxes.count,
            trackingitemsCount: try pieces.compactMap { $0.trackingItem }.removingDuplicates{ $0.id }.count,
            boxes: nil,
            totalWeight: boxes.compactMap(\.weight).reduce(0, +)
        ) 
    }
}
