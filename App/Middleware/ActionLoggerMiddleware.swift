import Foundation
import Vapor
import Fluent

struct ActionLoggerMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        
        if !request.actionLoggers.isEmpty && response.status == .ok {
            try await request.actionLoggers.create(on: request.db)
        }

        return response
    }
}

struct ActionLoggerKeys: StorageKey {
    typealias Value = [ActionLogger]
}

extension Request {
	var actionLoggers: [ActionLogger] {
        get {
			self.storage[ActionLoggerKeys.self] ?? []
        }
        set {
            self.storage[ActionLoggerKeys.self] = newValue
        }
    }

    func appendUserAction(_ actionType: ActionLogger.ActionType) {
		let userID = try? self.requireAuthUserID()
		let logger = ActionLogger(userID: userID, agentIdentifier: "User", type: actionType)
        self.actionLoggers.append(logger)
    }
    
    func appendBuyerAction(_ actionType: ActionLogger.ActionType) {
        let buyerID = try? self.requireAuthBuyerID()
        let logger = ActionLogger(
            buyerID: buyerID,
            agentIdentifier: "Buyer",
            type: actionType)
        self.actionLoggers.append(logger)
    }

	func appendAgentAction(identifier: String, _ actionType: ActionLogger.ActionType) {
		let logger = ActionLogger(userID: nil, agentIdentifier: identifier, type: actionType)
		self.actionLoggers.append(logger)
	}
}
