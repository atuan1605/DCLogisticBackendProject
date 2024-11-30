import Vapor
import Foundation

struct UpdateBoxInput: Content {
    var agentCodes: [String]?
    var name: String?
    var weight: Double?
}


