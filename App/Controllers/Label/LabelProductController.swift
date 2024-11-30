import Vapor
import Foundation
import Fluent
import SQLKit

struct LabelProductController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("labelProducts")
        let authenticated = groupedRoutes
            .grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())
        authenticated.post(use: createLabelProductHandler)
        authenticated.get(use: getLabelProductsHandler)
        authenticated.get("list", use: getLabelProductListHandler)
        
        let labelProductRoutes = authenticated.grouped(LabelProduct.parameterPath)
            .grouped(LabelProductIdentifyingMiddleWare())
        labelProductRoutes.put(use: updateLabelProductHandler)
        labelProductRoutes.delete(use: deleteLabelProductHandler)
    }
    
    private func deleteLabelProductHandler(req: Request) async throws -> HTTPResponseStatus {
        let labelProduct = try req.requireLabelProduct()
        try await labelProduct.delete(on: req.db)
        return .ok
    }
    
    private func getLabelProductListHandler(request: Request) async throws -> [LabelProductOutput] {
        
        let query = LabelProduct.query(on: request.db)
            .sort(\.$createdAt, .descending)
        
        if let searchString = try? request.query.get(String.self, at: "term") {
            query.filter(.sql(raw: "\(LabelProduct.schema).name"), .custom("ILIKE"), .bind("%\(searchString)%"))
        }
        
        let labelProducts = try await query
            .all()

        return labelProducts.map {
            $0.output()
        }
    }
    
    private func updateLabelProductHandler(req: Request) async throws -> LabelProductOutput {
        let input = try req.content.decode(UpdateLabelProductInput.self)
        let existedLabelProduct = try await LabelProduct.query(on: req.db)
            .filter(names: [input.name])
            .first()
        guard existedLabelProduct == nil else {
            throw AppError.labelProductIsAlreadyExisted
        }
        let labelProduct = try req.requireLabelProduct()
        
        labelProduct.name = input.name
        try await labelProduct.save(on: req.db)
        try req.appendUserAction(.updateLabelProduct(labelProductID: labelProduct.requireID(), name: labelProduct.name))
        return labelProduct.output()
    }
    
    private func createLabelProductHandler(req: Request) async throws -> LabelProductOutput {
        let input = try req.content.decode(CreateLabelProductInput.self)
        let existedProductsCount = try await LabelProduct.query(on: req.db).withDeleted().count()
        let formattedCount = (existedProductsCount + 1).formatNumber(minimumOf: 3)
        let existedLabelProduct = try await LabelProduct.query(on: req.db)
            .filter(names: [input.name])
            .first()
        guard existedLabelProduct == nil else {
            throw AppError.labelProductIsAlreadyExisted
        }
        let newLabelProduct = LabelProduct(code: formattedCount, name: input.name)
        try await newLabelProduct.save(on: req.db)
        return newLabelProduct.output()
    }
    
    private func getLabelProductsHandler(req: Request) async throws -> [LabelProductOutput] {
        let labelProducts = try await LabelProduct.query(on: req.db)
            .all()
        return labelProducts.map{ $0.output() }
    }
}

extension QueryBuilder where Model: LabelProduct {
    @discardableResult
    func filter(names: [String]) -> Self {
        guard !names.isEmpty else {
            return self
        }

        let regexSuffixGroup = names.joined(separator: "|")
        let fullRegex = "^.*(\(regexSuffixGroup))$"
        return self.filter(.sql(raw: "\(LabelProduct.schema).name"),.custom("~*"), .bind(fullRegex))
    }
}
