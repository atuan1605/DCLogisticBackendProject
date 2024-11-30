import Vapor
import Foundation
import Fluent

struct GetPackBoxesCommitedListOutput: Content {
    let grouped: [String: [GetPackBoxesCommitedOutput]]
}

extension GetPackBoxesCommitedListOutput {
    init(items: [PackBox], on db: Database) async throws {
        try await items.asyncForEach { packbox in
            try await packbox.$trackingItems.load(on: db)
        }
        let targetPackBoxes = items.filter { item in
            !item.trackingItems.isEmpty
        }
        let packBoxes = try await targetPackBoxes.asyncMap({
            return try await $0.toListCommitedOutput(on: db)
        })
        self.grouped = Dictionary(grouping: packBoxes) { packBox in
            guard let commitedAt = packBox.commitedAt else {
                return "N/A"
            }
            return commitedAt.toISODate()
        }
    }
}
