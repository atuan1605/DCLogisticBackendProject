import Foundation
import Vapor

struct GetCustomerCodeInputRequiredInput: Content {
    var agentIDs: [Agent.IDValue]?
}
