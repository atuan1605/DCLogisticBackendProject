import Vapor

struct AssignAgentInput: Content {
    var agentIDs: [Agent.IDValue : Int]
}
