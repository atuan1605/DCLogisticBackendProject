import Vapor
import Foundation
import Fluent

struct GetPackBoxesListOutput: Content {
    let grouped: [String: [GetPackBoxesOutput]]
}

extension GetPackBoxesListOutput {
    init(items: [PackBox], on db: Database) async throws {
        let packBoxes = try await items.asyncMap({
            return try await $0.toListOutput(on: db)
        })
        self.grouped = Dictionary(grouping: packBoxes) { packbox in
            guard let createdAt = packbox.createdAt else {
                return "N/A"
            }
            return createdAt.toISODate()
        }
    }
}
