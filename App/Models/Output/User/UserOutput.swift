import Foundation
import Vapor
import Fluent

struct UserOutput: Content {
    var id: User.IDValue?
    var username: String?
    var createdAt: Date?
    var updatedAt: Date?
    var scopes: String
    var agentCodes: [Agent.IDValue]?
    var warehouses: [String]?
    var isExternal: Bool?
    var agentSetting: AgentOutput?
    

    internal init(
        id: User.IDValue? = nil,
        username: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        scopes: String,
        agentCodes: [Agent.IDValue]? = nil,
        warehouses: [String]? = nil,
        isExternal: Bool? = nil,
        agentSetting: AgentOutput? = nil
    ) {
        self.id = id
        self.username = username
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.scopes = scopes
        self.agentCodes = agentCodes
        self.warehouses = warehouses
        self.isExternal = isExternal
        self.agentSetting = agentSetting
    }
}

extension User {
    func output(on db: Database) async throws -> UserOutput {
        try await .init(
            id: self.id,
            username: self.username,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            scopes: self.scopes.toString(),
            agentCodes: self.requireSortedAgents(on: db).compactMap({ $0.id }),
            warehouses: self.requireSortedWarehouses(on: db).map{ $0.name },
            isExternal: self.isExternal,
            agentSetting: self.$agents.value?.first?.output()
        )
    }
}
