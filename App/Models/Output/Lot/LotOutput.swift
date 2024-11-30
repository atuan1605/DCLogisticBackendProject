import Vapor
import Foundation
import Fluent

struct LotOutput: Content {
    let id: Lot.IDValue?
    let lotIndex: String
    let boxesCount: Int?
    let trackingItemsCount: Int?
    let boxes: [BoxWithTotalsOutput]?
    let totalWeight: Double?
}

extension Lot {
    func output(on db: Database) async throws -> LotOutput {
        let boxes = try await self.$boxes.get(on: db)
        let pieces = boxes.flatMap { $0.pieces }
        return .init(
            id: self.id,
            lotIndex: self.lotIndex,
            boxesCount: boxes.count,
            trackingItemsCount: try pieces.compactMap { $0.trackingItem }.removingDuplicates{ $0.id }.count,
            boxes: try await boxes.asyncMap {
                return try await $0.toCommitedOutput(on: db)
            },
            totalWeight: boxes.compactMap(\.weight).reduce(0, +)
            )
    }
    
    func outputWithoutBoxes(on db: Database) async throws -> LotOutput {
        let boxes = try await self.$boxes.get(on: db)
        return .init(
            id: self.id,
            lotIndex: self.lotIndex,
            boxesCount: self.$boxes.value?.count,
            trackingItemsCount: nil,
            boxes: nil,
            totalWeight: boxes.compactMap(\.weight).reduce(0, +)
        )
    }
    
}
