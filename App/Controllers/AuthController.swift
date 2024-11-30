import Foundation
import Vapor
import Fluent
import Crypto
import SQLKit

struct AuthController: RouteCollection {
    func boot(routes: Vapor.RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("auth")
        groupedRoutes.post("refreshToken", use: refreshTokenHandler)
        groupedRoutes.post("requestResetPassword", use: requestResetPasswordHandler)
        groupedRoutes.post("resetPassword", use: resetPasswordHandler)

        let basicAuthMiddleware = User.authenticator()
        let guardAuthMiddleware = User.guardMiddleware()

        let protected = groupedRoutes.grouped(
            basicAuthMiddleware,
            guardAuthMiddleware
        )
        protected.post("login", use: loginHandler)
        
        let buyerRoutes = groupedRoutes.grouped("buyers")
        buyerRoutes.post("validateResetPasswordToken", use: validateResetPasswordTokenHandler)
        buyerRoutes.post("register", use: registerBuyerHandler)
        buyerRoutes.post("refreshToken", use: refreshBuyerTokenHandler)
        buyerRoutes.post("resetPassword", use: resetBuyerPasswordHandler)
        buyerRoutes.post("requestResetPassword", use: requestResetBuyerPasswordHandler)
        
        let passwordProtected = buyerRoutes.grouped(BuyerBasicAuthenticator())
        passwordProtected.post("login", use: loginBuyerHandler)
        let protectedBuyer = buyerRoutes.grouped(
            BuyerJWTAuthenticator(),
            Buyer.guardMiddleware()
        )
        protectedBuyer.get("me", use: getMeHandler)
    }
    
    private func getMeHandler(request: Request) async throws -> BuyerOutput {
        guard let sqlDB = request.db as? SQLDatabase else {
            throw AppError.unknown
        }
        guard let buyer = request.auth.get(Buyer.self)
        else {
            throw AppError.buyerNotFound
        }
        let buyerEmail = buyer.email.normalizeString()
        struct RowOutput: Content {
            var customerCode: String?
        }
        let query: SQLQueryString = """
            select c.customer_code as \(ident: "customerCode") from \(ident: Customer.schema) c
            where LOWER(TRIM(c.email)) = \(bind: buyerEmail)
        """
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(query).all(decoding: RowOutput.self)
        } catch {
            print(String(reflecting: error))
            throw error
        }
        let customerCode = results.first?.customerCode
        return buyer.outputWithCustomer(customerCode: customerCode)
    }
    
    private func requestResetBuyerPasswordHandler(request: Request) async throws -> HTTPResponseStatus {
        let input = try request.content.decode(RequestResetBuyerPasswordInput.self)

        guard let buyer = try await Buyer.query(on: request.db)
            .filter(\.$email == input.email)
            .first()
        else {
            throw Abort(.notFound, reason: "Yêu cầu không hợp lệ")
        }
        
        let newResetPasswordToken = try buyer.generateResetPasswordToken()
        try await newResetPasswordToken.save(on: request.db)
        try request.emails.sendResetPasswordEmail(for: buyer, resetPasswordToken: newResetPasswordToken)
        return .ok
    }

    
    private func loginBuyerHandler(request: Request) async throws -> BuyerLoginOutput {
        let buyer = try request.auth.require(Buyer.self)

        guard buyer.verifiedAt != nil else {
            throw AppError.buyerNotVerified
        }

        let payload = try buyer.accessTokenPayload()
        let accessToken = try request.jwt.sign(payload)
        let refreshToken = try buyer.generateToken()
        
        try await refreshToken.save(on: request.db)

        return BuyerLoginOutput.init(
            refreshToken: refreshToken.value,
            accessToken: accessToken,
            expiredAt: refreshToken.expiredAt,
            buyer: buyer.output()
        )
    }
    
    private func validateResetPasswordTokenHandler(request: Request) async throws -> HTTPResponseStatus {
        let input = try request.content.decode(ValidateResetPasswordTokenInput.self)

        guard (try await BuyerResetPasswordToken.query(on: request.db)
            .filter(\.$value == input.token)
            .first()) != nil
        else {
            throw Abort(.badRequest, reason: "Mã đặt lại mật khẩu không hợp lệ")
        }
        return .ok
    }
    
    private func resetBuyerPasswordHandler(request: Request) async throws -> HTTPResponseStatus {
        let input = try request.content.decode(ResetPasswordInput.self)
        
        guard input.password == input.confirmPassword else {
            throw AppError.confirmPasswordDoesntMatch
        }
        guard let buyer = try await Buyer.query(on: request.db)
            .join(BuyerResetPasswordToken.self, on: \BuyerResetPasswordToken.$buyer.$id == \Buyer.$id)
            .filter(BuyerResetPasswordToken.self, \.$value == input.resetPasswordToken)
            .unique()
            .fields(for: Buyer.self)
            .first()
        else {
            throw AppError.invalidInput
        }
        
        let newPassword = try Bcrypt.hash(input.password)
        buyer.passwordHash = newPassword
        
        try await buyer.save(on: request.db)
        
        try await BuyerResetPasswordToken.query(on: request.db)
            .filter(\.$buyer.$id == buyer.requireID())
            .delete()
        
        return .ok
    }
    
    private func refreshBuyerTokenHandler(request: Request) async throws -> BuyerLoginOutput {
        let input = try request.content.decode(RefreshTokenInput.self)
        
        guard let token = try await BuyerToken.query(on: request.db)
                .filter(\.$value == input.refreshToken)
                .first()
        else {
            throw AppError.invalidInput
        }
        
        guard token.expiredAt >= Date() else {
            try await token.delete(on: request.db)
            throw AppError.expiredRefreshToken
        }

        let payload = Buyer.AccessTokenPayload(buyerID: token.$buyer.id)
        let accessToken = try request.jwt.sign(payload)
        
        let buyer = try await token.$buyer.get(on: request.db)
        
        return BuyerLoginOutput(
            refreshToken: token.value,
            accessToken: accessToken,
            expiredAt: payload.exp.value,
            buyer: buyer.output()
        )
    }

    func refreshTokenHandler(request: Request) async throws -> LoginOutput {
        let input = try request.content.decode(RefreshTokenInput.self)

        guard let token = try await Token.query(on: request.db)
                .filter(\.$value == input.refreshToken)
                .first()
        else {
            throw AppError.invalidInput
        }

        guard token.expiredAt >= Date() else {
            // het han
            try await token.delete(on: request.db)
            throw AppError.expiredRefreshToken
        }

        token.resetExpiredAtDate()
        try await token.save(on: request.db)
        let user = try await token.$user.get(on: request.db)

        return try .init(
            user: user,
            refreshToken: token.value,
            request: request)
    }

    func loginHandler(request: Request) async throws -> LoginOutput {
        let user = try request.auth.require(User.self)
        
        guard user.scopes.rawValue > 0 && user.inactiveAt == nil else {
            throw AppError.disabledUser
        }
        let refreshToken = try Token.generate(for: user)
        try await refreshToken.save(on: request.db)
        
        return try .init(
            user: user,
            refreshToken: refreshToken.value,
            request: request)
    }
    
    func requestResetPasswordHandler(req: Request) async throws -> HTTPResponseStatus {
        let input = try req.content.decode(RequestResetPasswordInput.self)
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == input.username)
            .first()
        else {
            throw AppError.usernameNotFound
        }
        
        let newResetPasswordToken = try user.generateResetPasswordToken()
        try await newResetPasswordToken.save(on: req.db)
        
        return .ok
    }
    
    private func resetPasswordHandler(request: Request) async throws -> HTTPResponseStatus {
        let input = try request.content.decode(ResetPasswordInput.self)
        
        guard input.password == input.confirmPassword else {
            throw AppError.confirmPasswordDoesntMatch
        }
        guard let user = try await User.query(on: request.db)
            .join(UserResetPasswordToken.self, on: \UserResetPasswordToken.$user.$id == \User.$id)
            .filter(UserResetPasswordToken.self, \.$value == input.resetPasswordToken)
            .unique()
            .fields(for: User.self)
            .first()
        else {
            throw AppError.invalidInput
        }
        
        let newPassword = try Bcrypt.hash(input.password)
        user.passwordHash = newPassword
        
        try await user.save(on: request.db)
        
        try await UserResetPasswordToken.query(on: request.db)
            .filter(\.$user.$id == user.requireID())
            .delete()
        
        return .ok
    }
    
    private func registerBuyerHandler(request: Request) async throws -> HTTPResponseStatus {
        try CreateBuyerInput.validate(content: request)

        let input = try request.content.decode(CreateBuyerInput.self)
        guard input.password == input.confirmPassword else {
            throw AppError.confirmPasswordDoesntMatch
        }

        let buyer = try input.buyer()

        try await buyer.save(on: request.db)
        
        return .ok
    }
}
