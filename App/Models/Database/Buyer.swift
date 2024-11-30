import Fluent
import Vapor
import JWT

final class Buyer: Model, @unchecked Sendable {
    static let schema = "buyers"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "email")
    var email: String

    @Field(key: "phoneNumber")
    var phoneNumber: String

    @Field(key: "packing_request_left")
    var packingRequestLeft: Int

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @OptionalField(key: "verified_at")
    var verifiedAt: Date?
    
    @OptionalParent(key: "agent_id")
    var agent: Agent?
    
    @Field(key: "is_public_images")
    var isPublicImages: Bool
    
//    @Field(key: "available_deposit")
//    var availableDeposit: Int
    
    @Field(key: "is_admin")
    var isAdmin: Bool

    init() { }

    init(id: UUID? = nil,
         username: String,
         passwordHash: String,
         email: String,
         phoneNumber: String,
         verifiedAt: Date? = nil,
         createdAt: Date? = nil,
         updatedAt: Date? = nil,
         deletedAt: Date? = nil,
         agentID: Agent.IDValue
    ) {
        self.id = id
        self.username = username
        self.passwordHash = passwordHash
        self.email = email
        self.phoneNumber = phoneNumber
        self.packingRequestLeft = 0
        self.verifiedAt = verifiedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.$agent.id = agentID
        self.isAdmin = false
        self.isPublicImages = true
    }
}

extension Buyer: ModelAuthenticatable {
    static let usernameKey: KeyPath<Buyer, Field<String>> = \.$username
    static let passwordHashKey: KeyPath<Buyer, Field<String>> = \.$passwordHash

    func verify(password: String) throws -> Bool {
        return try Bcrypt.verify(password, created: self.passwordHash)
    }
}

extension Buyer {
    struct AccessTokenPayload: JWTPayload {
        var issuer: IssuerClaim
        var issuedAt: IssuedAtClaim
        var exp: ExpirationClaim
        var sub: SubjectClaim

        init(issuer: String = "Metis-API",
             issuedAt: Date = Date(),
             expirationAt: Date = Date().addingTimeInterval(60*60*2),
             buyerID: Buyer.IDValue) {
            self.issuer = IssuerClaim(value: issuer)
            self.issuedAt = IssuedAtClaim(value: issuedAt)
            self.exp = ExpirationClaim(value: expirationAt)
            self.sub = SubjectClaim(value: buyerID.description)
        }

        func verify(using signer: JWTSigner) throws {
            try self.exp.verifyNotExpired()
        }
    }

    func accessTokenPayload() throws -> AccessTokenPayload {
        return try AccessTokenPayload(buyerID: self.requireID())
    }
}

extension Buyer {
    func generateToken() throws -> BuyerToken {
        try .init(
            value: .randomCode(),
            buyerID: self.requireID()
        )
    }
    
    func normalizeEmail() -> String {
        return self.email.normalizeString()
    }
}

extension Buyer: Parameter { }

