import Vapor
import Foundation
import Fluent

struct GetLotPaginatedOnWebOutput: Content {
    var id: Lot.IDValue?
    var lotIndex: String
    var createdAt: Date?
    var boxes: [BoxOutput]?
}

extension Lot {
    func toPaginateOutput(on db: Database) async throws -> GetLotPaginatedOnWebOutput {
        return await .init(
            id: self.id,
            lotIndex: self.lotIndex,
            createdAt: self.createdAt,
            boxes: try self.boxes.asyncMap({ try await
                $0.toOutput(on: db) })
        )
    }
    
    func toPaginateOutput() -> GetLotPaginatedOnWebOutput {
        return .init(
            id: self.id,
            lotIndex: self.lotIndex,
            createdAt: self.createdAt,
            boxes: self.boxes.map { $0.output() }
        )
    }
    
    func getBoxesOutput() async throws -> GetLotPaginatedOnWebOutput {
            return await .init(
                id: self.id,
                lotIndex: self.lotIndex,
                createdAt: self.createdAt,
                boxes: try self.boxes.asyncMap({
                    try await $0.toListOutput()
                })
            )
    }
}
