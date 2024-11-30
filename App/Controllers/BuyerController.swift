import Vapor
import Foundation
import Fluent

struct BuyerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("buyers")
        let protected = groupedRoutes.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )
        protected.group(ScopeCheckMiddleware(requiredScope: [.verifyBuyer])) {
            $0.get(use: getBuyersHandler)
            $0.put(use: verifyBuyerHandler)
        }
        protected.group(ScopeCheckMiddleware(requiredScope: [.editPackingRequestLeft])) {
            $0.get("verified", use: getVerifiedBuyerHandler)
            $0.put("packingRequest", use: updatePackingRequestHandler)
        }
    }
    
    private func updatePackingRequestHandler(req: Request) async throws -> BuyerOutput {
        let input = try req.content.decode(UpdateBuyerInput.self)
        guard let buyer = try await Buyer.query(on: req.db)
            .filter(\.$id == input.id)
            .first()
        else {
            throw AppError.buyerNotFound
        }
        
        buyer.packingRequestLeft = input.packingRequest
        try await buyer.save(on: req.db)
        return buyer.output()
    }
    
    private func getVerifiedBuyerHandler(req: Request) async throws -> Page<BuyerOutput> {
        let input = try req.query.decode(GetBuyerQueryInput.self)
        let user = try req.requireAuthUser()
        let agentIDs = try await user.$agents.query(on: req.db).all(\.$id)
        var query = Buyer.query(on: req.db)
            .filter(\.$agent.$id ~~ agentIDs)
            .filter(\.$verifiedAt != nil)
            .sort(\.$packingRequestLeft, .ascending)
        
        if let email = input.email {
            query.filter(.sql(raw: "\(Buyer.schema).email"), .custom("ILIKE"), .bind("%\(email)%"))
        }
        if let fromDate = input.fromDate {
            query = query.filter(.sql(raw: "\(Buyer.schema).created_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
        }
        if let toDate = input.toDate {
            query = query.filter(.sql(raw: "\(Buyer.schema).created_at::DATE"), .lessThanOrEqual, .bind(toDate))
        }
        let page = try await query
            .paginate(for: req)
        let items = page.items.map {
            return $0.output()
        }
        return .init(items: items, metadata: page.metadata)
    }
    
    private func getBuyersHandler(req: Request) async throws -> Page<BuyerOutput> {
        let input = try req.query.decode(GetBuyerQueryInput.self)
        let user = try req.requireAuthUser()
        let agentIDs = try await user.$agents.query(on: req.db).all(\.$id)
        var query = Buyer.query(on: req.db)
            .filter(\.$agent.$id ~~ agentIDs)
            .filter(\.$verifiedAt == nil)
            .sort(\.$createdAt, .descending)
        
        if let email = input.email {
            query.filter(.sql(raw: "\(Buyer.schema).email"), .custom("ILIKE"), .bind("%\(email)%"))
        }
        if let fromDate = input.fromDate {
            query = query.filter(.sql(raw: "\(Buyer.schema).created_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
        }
        if let toDate = input.toDate {
            query = query.filter(.sql(raw: "\(Buyer.schema).created_at::DATE"), .lessThanOrEqual, .bind(toDate))
        }
        let page = try await query
            .paginate(for: req)
        let items = page.items.map {
            return $0.output()
        }
        return .init(items: items, metadata: page.metadata)
    }
    
    private func verifyBuyerHandler(req: Request) async throws -> HTTPResponseStatus {
        let input = try req.content.decode(VerifyBuyerInput.self)
        var existedCustomer = try await Customer.query(on: req.db)
            .filter(\.$customerCode == input.customerCode)
            .first()
        if existedCustomer == nil {
            let newCustomer = Customer(customerName: input.customerCode, customerCode: input.customerCode, agentID: "DC", socialLinks: .init())
            try await newCustomer.create(on: req.db)
            existedCustomer = newCustomer
        }
        
        guard let existedCustomer = existedCustomer else {
            throw AppError.customerNotFound
        }
        guard let buyer = try await Buyer.query(on: req.db)
            .filter(\.$id == input.buyerID)
            .first()
        else {
            throw AppError.buyerNotFound
        }
        if let customerEmail = existedCustomer.email?.normalizeString(),
           customerEmail != buyer.email.normalizeString() && !customerEmail.isEmpty {
            throw AppError.customerAlreadyHaveEmail
        }
        if existedCustomer.email.isNilOrEmpty() {
            existedCustomer.email = buyer.email
            try await existedCustomer.save(on: req.db)
        }
        
        let now = Date()
        buyer.verifiedAt = now
        try await buyer.save(on: req.db)
        return .ok
    }
    
}
