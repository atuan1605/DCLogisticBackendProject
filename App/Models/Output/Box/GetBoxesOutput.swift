import Vapor
import Foundation
import Fluent

struct GetBoxesOutput: Content {
    let name: String
    let grouped: [String: [BoxesListOutput]]
}

extension GetBoxesOutput {
    init(name: String, items: [Box], on db: Database) async throws {
        let outputBoxes = try await items.asyncMap({
            return try await $0.toUncommitedOutput(on: db)
        })
        self.name = name
        self.grouped = Dictionary.init(grouping: outputBoxes) { box in
            guard let boxedAt = box.createdAt else {
                return "N/A"
            }
            return boxedAt.toISODate()
        }
    }
}
