import Vapor
import Foundation
import Fluent

struct GetAgentOutput: Content {
    let agent: Agent.IDValue?
    let index: Int
}

extension UserAgent {
    func output(on db: Database) async throws -> GetAgentOutput {
        let agent = try await self.$agent.get(on: db)
        return .init(
            agent: agent.id, index: self.index ?? 0
        )
    }
}

