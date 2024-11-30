import Vapor
import Foundation
import Fluent

struct AgentIdentifyingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let agentID = request.parameters.get(Agent.parameter, as: Agent.IDValue.self) {
            let agent = try await Agent.find(agentID, on: request.db)
            request.agent = agent
        }
        return try await next.respond(to: request)
    }
}

struct AgentKey: StorageKey {
    typealias Value = Agent
}

extension Request {
    var agent: Agent? {
        get {
            self.storage[AgentKey.self]
        }
        set {
            self.storage[AgentKey.self] = newValue
        }
    }
    
    func requireAgent() throws -> Agent {
        guard let agent = self.agent else {
            throw AppError.agentNotFound
        }
        return agent
    }
}

