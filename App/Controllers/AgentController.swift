import Foundation
import Vapor
import Fluent

struct AgentController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("agents")

        let authenticated = groupedRoutes
            .grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())

        authenticated.get("list", use: getListHandler)
        authenticated.get(use: getAgentsHandler)
        let scopeRoute = authenticated .grouped(ScopeCheckMiddleware(requiredScope: [.updateAgent]))
        scopeRoute.post(use: createAgentHandler)
        
        let agentRoutes = scopeRoute
            .grouped(Agent.parameterPath)
            .grouped(AgentIdentifyingMiddleware())
        agentRoutes.put(use: updateAgentHandler)
    }
    
    private func getListHandler(req: Request) async throws -> [AgentOutput] {
        let input = try req.query.decode(GetAgentQueryInput.self)
        var query = Agent.query(on: req.db)
        if let searchString = input.searchString {
            query = query.filter(.sql(raw: "\(Agent.schema).name"),
                                 .custom("ILIKE"),
                                 .bind("%\(searchString)%"))
        }
        let agents = try await query
            .sort(\.$createdAt, .descending)
            .all()
        return agents.map{ $0.output() }
    }
    
    private func updateAgentHandler(req: Request) async throws -> AgentOutput {
        let agent = try req.requireAgent()
        let input = try req.content.decode(UpdateAgentInput.self)
        if let isInactive = input.isInactive {
            if isInactive && agent.inactiveAt == nil {
                let now = Date()
                agent.inactiveAt = now
                if try await agent.$users.query(on: req.db).count() > 0 {
                    try await UserAgent.query(on: req.db)
                        .filter(\.$agent.$id == agent.requireID())
                        .delete()
                }
            } else if !isInactive && agent.inactiveAt != nil {
                agent.inactiveAt = nil
            }
            try await agent.save(on: req.db)
        }
        return agent.output()
    }
    
    private func createAgentHandler(req: Request) async throws -> AgentOutput {
        try CreateAgentInput.validate(content: req)
        let user = try req.requireAuthUser()
        let input = try req.content.decode(CreateAgentInput.self)
        let newAgent = input.toAgent()
        try await newAgent.save(on: req.db)
        try await user.$agents.attach(newAgent, method: .ifNotExists, on: req.db)
        try req.appendUserAction(.createAgent(agentID: newAgent.requireID()))
        return newAgent.output()
    }

    private func getAgentsHandler(request: Request) async throws -> [String] {
        let user = try request.requireAuthUser()
        let userID = try user.requireID()
        let agents = try await user.$agents.query(on: request.db)
            .filter(\.$inactiveAt == nil)
            .all()
        let agentIDs = agents.compactMap(\.id)
        let userAgents = try await UserAgent.query(on: request.db)
            .filter(\.$user.$id == userID)
            .filter(\.$agent.$id ~~ agentIDs)
            .sort(\.$index, .ascending)
            .all(\.$agent.$id)
        return userAgents
    }
}
