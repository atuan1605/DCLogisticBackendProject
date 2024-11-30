import Foundation
import Vapor
import Fluent

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("users")
        groupedRoutes.post(use: createHandler)
        
        let protected = groupedRoutes.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )
        protected.get("me", use: getUserHandler)
        
        protected.group(ScopeCheckMiddleware(requiredScope: .userList)) {
            $0.get("scopes", use: getScopesHandler)
            $0.get(use: getUsersHandler)
            let userRoute = $0
                .grouped(User.parameterPath)
                .grouped(UserIdentifyingMiddleware())
            userRoute.get(use: getUserDetailsHandler)
            userRoute.get("timeline", use: getUserTimeLineHandler)
            userRoute.get("token", use: resetPasswordTokenHandler)
        }
        protected.group(ScopeCheckMiddleware(requiredScope: .updateUsers)) {
            let userIdentifiedRoutes = $0
                .grouped(User.parameterPath)
                .grouped(UserIdentifyingMiddleware())
            
            userIdentifiedRoutes.post("assignAgents", use: assignAgentsHandler)
            userIdentifiedRoutes.post("assignWarehouses", use: assignWarehousesHandler)
            userIdentifiedRoutes.patch("updateScope", use: updateScopeHandler)
            userIdentifiedRoutes.put(use: updateUserHandler)
        }
    }
    
    private func updateUserHandler(req: Request) async throws -> HTTPResponseStatus {
        let user = try req.requireUser()
        let userID = try user.requireID()
        let loginUserID = try req.requireAuthUser().requireID()
        
        guard userID != loginUserID else {
            throw AppError.userCantSelfUpdate
        }
        let input = try req.content.decode(UpdateUserInput.self)
        if input.inactiveUser {
            user.inactiveAt = Date()
            try req.appendUserAction(.assignInactiveUser(userID: user.requireID()))
            try await user.save(on: req.db)
        }
        return .ok
    }

    private func createHandler(request: Request) async throws -> UserOutput {
        try CreateUserInput.validate(content: request)
        let input = try request.content.decode(CreateUserInput.self)
        let newUser = try input.toUser()
        try await newUser.save(on: request.db)
        if let agentID = input.agentID, let isExternal = input.isExternal, isExternal {
            guard let agent = try await Agent.query(on: request.db)
                .filter(\.$id == agentID)
                .first()
            else {
                throw AppError.agentNotFound
            }
            try await newUser.$agents.attach(agent, on: request.db)
        }
        try request.appendUserAction(.assignUser(userID: newUser.requireID()))
        return try await newUser.output(on: request.db)
    }

    private func assignAgentsHandler(request: Request) async throws -> HTTPResponseStatus {
        let user = try request.requireUser()
        let input = try request.content.decode(AssignAgentInput.self)
        
        let agents = try await Agent.query(on: request.db)
            .filter(\.$id ~~ input.agentIDs.keys)
            .all()
        
        if agents.isEmpty {
            throw AppError.invalidInput
        }
        try await request.db.transaction { db in
            try await user.$agents.detachAll(on: db)
            try await agents.asyncForEach { agent in
                let agentID = try agent.requireID()
                try await user.$agents.attach(agent, method: .ifNotExists, on: db) { userAgent in
                    userAgent.index = input.agentIDs[agentID]
                }
            }
            try request.appendUserAction(.assignAgents(agentIDs: agents.map { try $0.requireID() }, userID: user.requireID()))
        }
        return .ok
    }
    
    private func assignWarehousesHandler(request: Request) async throws -> HTTPResponseStatus {
        let user = try request.requireUser()
        let input = try request.content.decode([AssignWarehouseInput].self)
        let warehouseIDs = input.map(\.warehouseID)
        let warehouses = try await Warehouse.query(on: request.db)
            .filter(\.$id ~~ warehouseIDs)
            .all()
        
        if warehouses.isEmpty {
            throw AppError.invalidInput
        }
        
        try await request.db.transaction { db in
            try await user.$warehouses.detachAll(on: db)
            try await warehouses.asyncForEach { warehouse in
                let warehouseID = try warehouse.requireID()
                try await user.$warehouses.attach(warehouse, method: .ifNotExists, on: db) {
                    userWarehouse in
                    userWarehouse.index = input.first { $0.warehouseID == warehouseID }?.index
                }
            }
            try request.appendUserAction(.assignWarehouses(warehouseIDs: warehouseIDs, userID: user.requireID()))
        }
        return .ok
    }
    
    private func updateScopeHandler(req: Request) async throws -> UserOutput {
        let user = try req.requireUser()
        let userID = try user.requireID()
        let loginUserID = try req.requireAuthUser().requireID()
        
        guard userID != loginUserID else {
            throw AppError.userCantSelfUpdate
        }
        let input = try req.content.decode(UpdateScopeInput.self)
        var targetScope: User.Scope = []
        input.scope.forEach {
            if $0 == User.Scope.trackingItems.toString() {
                targetScope.insert(.trackingItems)
            }
            if $0 == User.Scope.updateTrackingItems.toString() {
                targetScope.insert(.updateTrackingItems)
            }
            if $0 == User.Scope.usInventory.toString() {
                targetScope.insert(.usInventory)
            }
            if $0 == User.Scope.shipmentList.toString() {
                targetScope.insert(.shipmentList)
            }
            if $0 == User.Scope.packShipment.toString() {
                targetScope.insert(.packShipment)
            }
            if $0 == User.Scope.vnInventory.toString() {
                targetScope.insert(.vnInventory)
            }
            if $0 == User.Scope.deliveryList.toString() {
                targetScope.insert(.deliveryList)
            }
            if $0 == User.Scope.packDelivery.toString() {
                targetScope.insert(.packDelivery)
            }
            if $0 == User.Scope.customers.toString() {
                targetScope.insert(.customers)
            }
            if $0 == User.Scope.updateCustomers.toString() {
                targetScope.insert(.updateCustomers)
            }
            if $0 == User.Scope.userList.toString() {
                targetScope.insert(.userList)
            }
            if $0 == User.Scope.updateUsers.toString() {
                targetScope.insert(.updateUsers)
            }
            if $0 == User.Scope.verifyBuyer.toString() {
                targetScope.insert(.verifyBuyer)
            }
            if $0 == User.Scope.editPackingRequestLeft.toString() {
                targetScope.insert(.editPackingRequestLeft)
            }
            if $0 == User.Scope.warehouseList.toString() {
                targetScope.insert(.warehouseList)
            }
            if $0 == User.Scope.updateWarehouse.toString() {
                targetScope.insert(.updateWarehouse)
            }
            if $0 == User.Scope.agentTracking.toString() {
                targetScope.insert(.agentTracking)
            }
            if $0 == User.Scope.camera.toString() {
                targetScope.insert(.camera)
            }
            if $0 == User.Scope.agentList.toString() {
                targetScope.insert(.agentList)
            }
            if $0 == User.Scope.updateAgent.toString() {
                targetScope.insert(.updateAgent)
            }
        }
        user.scopes = targetScope
        
        try await user.save(on: req.db)
        
        try req.appendUserAction(.updateUserScope(userID: user.requireID(), scopes: input.scope))
            
        return try await user.output(on: req.db)
    }
    
    private func getUserHandler(req: Request) async throws -> UserOutput {
        let user = try req.requireAuthUser()
        user.$agents.value = try await user.$agents.query(on: req.db)
            .all()
            
        return try await user.output(on: req.db)
    }
    
    private func getScopesHandler(req: Request) async throws -> ScopeTreeOutput {
        let user = try req.requireAuthUser()
        return user.scopes.toTree()
    }
    
    private func getUsersHandler(req: Request) async throws -> [UserOutput] {
        let input = try req.query.decode(GetUserQueryInput.self)
        
        var query = User.query(on: req.db)
            .filter(\.$inactiveAt == nil)
            .sort(\.$createdAt, .descending)
            .with(\.$agents)
            .with(\.$warehouses)
        
        if let agentID = input.agentCode {
            query = query.join(UserAgent.self, on: \UserAgent.$user.$id == \User.$id)
                .filter(UserAgent.self, \.$agent.$id == agentID)
        }
        
        if let warehouseID = input.warehouseID {
            query = query.join(UserWarehouse.self, on: \UserWarehouse.$user.$id == \User.$id)
                .filter(UserWarehouse.self, \.$warehouse.$id == warehouseID)
        }
        if let username = input.username {
            query = query.filter(.sql(raw: "\(User.schema).username"),
                                 .custom("ILIKE"),
                                 .bind("%\(username)%"))
        }
        let users = try await query
            .unique()
            .fields(for: User.self)
            .all()
        return try await users.asyncMap { try await $0.output(on: req.db) }
    }
    
    private func getUserDetailsHandler(req: Request) async throws -> UserOutput {
        let user = try req.requireUser()
        return try await user.output(on: req.db)
    }
    
    private func getUserTimeLineHandler(req: Request) async throws -> [UserTimeLineOutput] {
        let userID = try req.requireUser().requireID()
        
        let actions = try await ActionLogger.query(on: req.db)
            .group(.or) { builder in
                let targetActionTypes: [ActionLogger.ActionType.CodingKeys] = [
                    .assignUser,
                    .assignWarehouses,
                    .assignAgents,
                    .updateUserScope
                ]
                targetActionTypes.forEach { actionType in
                    builder.filter(.sql(raw: "(type->>'\(actionType.rawValue)')::jsonb->>'userID'"), .equal, .bind(userID.uuidString))
                }
            }
            .sort(\.$createdAt, .descending)
            .with(\.$user)
            .all()
        return actions.map {
            .init(
                id: userID,
                action: $0.type,
                username: $0.user?.username ?? "N/A",
                createdAt: $0.createdAt
            )
        }
    }
    
    private func resetPasswordTokenHandler(req: Request) async throws -> String {
        let userID = try req.requireUser().requireID()
        guard let token = try await UserResetPasswordToken.query(on: req.db)
            .filter(\.$user.$id == userID)
            .first()
        else {
            return .init()
        }
        return token.value
    }
}
