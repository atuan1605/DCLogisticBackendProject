import Foundation
import Vapor
import Fluent
import JWT

final class User: Model, @unchecked Sendable {
    static let schema: String = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Field(key: "scopes")
    var scopes: Scope

    @Children(for: \.$user)
    var userAgents: [UserAgent]
    
    @Children(for: \.$user)
    var userWarehouses: [UserWarehouse]

    @Siblings(through: UserAgent.self, from: \.$user, to: \.$agent)
    var agents: [Agent]
    
    @Siblings(through: UserWarehouse.self, from: \.$user, to: \.$warehouse)
    var warehouses: [Warehouse]
    
    @OptionalField(key: "isExternal")
    var isExternal: Bool?
    
    @OptionalField(key: "inactive_at")
    var inactiveAt: Date?

    init() { }

    init(
        username: String,
        passwordHash: String,
        scopes: User.Scope,
        isExternal: Bool? = nil
    ) {
        self.username = username
        self.passwordHash = passwordHash
        self.scopes = scopes
        self.isExternal = isExternal
    }
}

extension User: ModelAuthenticatable {
    static var usernameKey: KeyPath<User, Field<String>> {
        return \User.$username
    }
    
    static var passwordHashKey: KeyPath<User, Field<String>> {
        return \User.$passwordHash
    }
    
    func verify(password: String) throws -> Bool{
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension User {
    struct AccessTokenPayload: JWTPayload {
        var issuer: IssuerClaim
        var issuedAt: IssuedAtClaim
        var exp: ExpirationClaim
        var sub: SubjectClaim
        var username: String

        init(issuer: String = "LogisticsVapor",
             issuedAt: Date = Date(),
             expirationAt: Date = Date().addingTimeInterval(.oneDay),
             userID: User.IDValue,
             username: String
        ) {
            self.issuer = IssuerClaim(value: issuer)
            self.issuedAt = IssuedAtClaim(value: issuedAt)
            self.exp = ExpirationClaim(value: expirationAt)
            self.sub = SubjectClaim(value: userID.description)
            self.username = username
        }

        func verify(using signer: JWTSigner) throws {
            guard self.issuer.value == "LogisticsVapor" else {
                throw AppError.invalidJWTIssuer
            }

            try self.exp.verifyNotExpired()
        }
    }

    func accessTokenPayload() throws -> AccessTokenPayload {
        return try AccessTokenPayload(userID: self.requireID(), username: self.username)
    }
    
    func hasRequiredScope(for requiredScopes: User.Scope) -> Bool {
        return self.scopes.isSuperset(of: requiredScopes)
    }
}

extension User {
    func requireSortedAgents(on db: Database) async throws -> [Agent] {
        let userAgents = try await self.$userAgents.get(on: db)
        return try await userAgents.sorted(by: { lhs, rhs -> Bool in
            let lhsIndex = lhs.index ?? 0
            let rhsIndex = rhs.index ?? 0
            return lhsIndex < rhsIndex
        }).asyncMap { userAgent in
            return try await userAgent.$agent.get(on: db)
        }
    }

    func requireSortedWarehouses(on db: Database) async throws -> [Warehouse] {
        let warehouses = try await self.$userWarehouses.get(on: db)
        return try await warehouses.sorted(by: { lhs, rhs -> Bool in
            let lhsIndex = lhs.index ?? 0
            let rhsIndex = rhs.index ?? 0
            return lhsIndex < rhsIndex
        }).asyncMap { userWarehouse in
            return try await userWarehouse.$warehouse.get(on: db)
        }
    }
}

extension User: Parameter { }

extension User {
    struct Scope: OptionSet, Codable, SetAlgebra {
        let rawValue: Int
        
        static let trackingItems = Scope(rawValue: 1 << 0)
        static let updateTrackingItems = Scope(rawValue: 1 << 1)

        static let usInventory = Scope(rawValue: 1 << 2)

        static let usWarehouse: Scope = [.usInventory, .trackingItems, .updateTrackingItems]

        static let shipmentList = Scope(rawValue: 1 << 3)
        static let packShipment = Scope(rawValue: 1 << 4)

        static let shipments: Scope = [.shipmentList, .packShipment, .trackingItems, .updateTrackingItems]

        static let usAppAccess: Scope = [ .usWarehouse, .shipments]
        
        static let vnInventory = Scope(rawValue: 1 << 5)

        static let vnWarehouse: Scope = [.vnInventory, .trackingItems, .updateTrackingItems]

        static let deliveryList = Scope(rawValue: 1 << 6)
        static let packDelivery = Scope(rawValue: 1 << 7)

        static let deliveries: Scope = [.deliveryList, .packDelivery, .trackingItems, .updateTrackingItems]

        static let customers = Scope(rawValue: 1 << 8)
        static let updateCustomers = Scope(rawValue: 1 << 9)

        static let vnAppAccess: Scope = [.vnWarehouse, .deliveries, .customers]
        static let vnAppAdmin: Scope = [vnAppAccess, .updateCustomers]

        static let userList = Scope(rawValue: 1 << 10)
        static let updateUsers = Scope(rawValue: 1 << 11)
        static let users: Scope = [.userList, .updateUsers]
        
        static let verifyBuyer = Scope(rawValue: 1 << 12)
        static let editPackingRequestLeft = Scope(rawValue: 1 << 13)
        static let buyers: Scope = [.verifyBuyer, .editPackingRequestLeft]
        
        static let warehouseList = Scope(rawValue: 1 << 14)
        static let updateWarehouse = Scope(rawValue: 1 << 15)
        static let warehouses: Scope = [.warehouseList, .updateWarehouse]
        static let agentTracking = Scope(rawValue: 1 << 16)
        
        static let camera = Scope(rawValue: 1 << 17)
        
        static let updateAgent = Scope(rawValue: 1 << 18)
        static let agentList = Scope(rawValue: 1 << 19)
        static let agents: Scope = [.agentList, .updateAgent]
        static let allAccess: Scope = [.usAppAccess, .vnAppAdmin, .users, .buyers, .warehouses, .agentTracking, .camera, .agents]

        func toString() -> String {
            var scopeString = [String]()
                
            if self.contains(.trackingItems) {
                scopeString.append("trackingItems")
            }
            if self.contains(.agentTracking) {
                scopeString.append("agentTracking")
            }
            if self.contains(.updateTrackingItems) {
                scopeString.append("updateTrackingItems")
            }
            if self.contains(.usInventory) {
                scopeString.append("usInventory")
            }
            if self.contains(.shipmentList) {
                scopeString.append("shipmentList")
            }
            if self.contains(.packShipment) {
                scopeString.append("packShipment")
            }
            if self.contains(.vnInventory) {
                scopeString.append("vnInventory")
            }
            if self.contains(.deliveryList) {
                scopeString.append("deliveryList")
            }
            if self.contains(.packDelivery) {
                scopeString.append("packDelivery")
            }
            if self.contains(.customers) {
                scopeString.append("customers")
            }
            if self.contains(.updateCustomers) {
                scopeString.append("updateCustomers")
            }
            if self.contains(.userList) {
                scopeString.append("userList")
            }
            if self.contains(.updateUsers) {
                scopeString.append("updateUsers")
            }
            if self.contains(.users) {
                scopeString.append("users")
            }
            if self.contains(.deliveries) {
                scopeString.append("deliveries")
            }
            if self.contains(.vnWarehouse) {
                scopeString.append("vnWarehouse")
            }
            if self.contains(.shipments) {
                scopeString.append("shipments")
            }
            if self.contains(.usWarehouse) {
                scopeString.append("usWarehouse")
            }
            if self.contains(.usAppAccess) {
                scopeString.append("usAppAccess")
            }
            if self.contains(.vnAppAdmin) {
                scopeString.append("vnAppAdmin")
            }
            if self.contains(.verifyBuyer) {
                scopeString.append("verifyBuyer")
            }
            if self.contains(.editPackingRequestLeft) {
                scopeString.append("editPackingRequestLeft")
            }
            if self.contains(.buyers) {
                scopeString.append("buyers")
            }
            if self.contains(.warehouseList) {
                scopeString.append("warehouseList")
            }
            if self.contains(.updateWarehouse) {
                scopeString.append("updateWarehouse")
            }
            if self.contains(.warehouses) {
                scopeString.append("warehouses")
            }
            if self.contains(.vnAppAccess) {
                scopeString.append("vnAppAccess")
            }
            if self.contains(.camera) {
                scopeString.append("camera")
            }
            if self.contains(.updateAgent) {
                scopeString.append("updateAgent")
            }
            if self.contains(.agentList) {
                scopeString.append("agentList")
            }
            if self.contains(.agents) {
                scopeString.append("agents")
            }
            if self.contains(.allAccess) {
                scopeString.append("allAccess")
            }
            
            return scopeString.joined(separator: ", ")
        }
    }
}
