import Foundation
import Vapor
import Fluent

final class UserAgent: Model, @unchecked Sendable {
    static let schema: String = "user_agents"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "agent_id")
    var agent: Agent

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @OptionalField(key: "index")
    var index: Int?
    
    init() { }

    init(userID: User.IDValue, agentID: Agent.IDValue, index: Int? = nil) {
        self.$user.id = userID
        self.$agent.id = agentID
        self.index = index
    }
}
