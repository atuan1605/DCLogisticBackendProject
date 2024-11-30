import Foundation
import Vapor
import Fluent
import SQLKit

struct TrackingRepackingController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group(ScopeCheckMiddleware(requiredScope: .usInventory)) {
            let groupedRoutes = $0.grouped("repacking")
            groupedRoutes.get(use: getRepackingItemsHandler)
            groupedRoutes.get("totals", use: getRepackingTotalsHandler)
            groupedRoutes.get("paginated", use: getRepackingPaginatedHandler)
        }

        let trackingItemRoutes = routes
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())

        trackingItemRoutes.group(ScopeCheckMiddleware(requiredScope: [.updateTrackingItems])) {
            $0.post("moveToPacked", use: moveToPackedHandler)
        }

        let productsRoutes = trackingItemRoutes.grouped("products")

        productsRoutes.group(ScopeCheckMiddleware(requiredScope: [.updateTrackingItems])) {
            $0.post(use: createProductHandler)

            let productRoutes = $0
                .grouped(Product.parameterPath)
                .grouped(ProductIdentifyingMiddleware())

            productRoutes.patch(use: updateProductHandler)
            productRoutes.delete(use: deleteProductHandler)
        }

        productsRoutes.group(ScopeCheckMiddleware(requiredScope: .trackingItems)) {
            $0.get("productNameSuggestions", use: getProductNameSuggestionsHandler)
        }
    }
    
    private func getRepackingPaginatedHandler(req: Request) async throws -> Page<TrackingItemOutput> {
        let input = try req.query.decode(GetTrackingItemQueryInput.self)

        let query = TrackingItem.query(on: req.db)
            .filterRepacking()

        if let searchStrings = input.searchStrings {
            query.filter(searchStrings: searchStrings, includeAlternativeRef: true)
        }

        if let fromDate = input.fromDate {
            query.filter(.sql(raw: "\(TrackingItem.schema).repacking_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
        }
        if let toDate = input.toDate {
            query.filter(.sql(raw: "\(TrackingItem.schema).repacking_at::DATE"), .lessThanOrEqual, .bind(toDate))
        }

        let page = try await query
            .paginate(for: req)

        return .init(
            items: page.items.map { $0.output() },
            metadata: page.metadata
        )
    }

    private func moveToPackedHandler(request: Request) async throws -> TrackingItemOutput {
        let trackingItem = try request.requireTrackingItem()
        let trackingItemID = try trackingItem.requireID()
        let input = try request.content.decode(MoveToPackedInput.self)
        
        var targetChain = UUID().uuidString

        if
            let chain = input.chain,
            let referenceTrackingItem = try await TrackingItem
            .query(on: request.db)
            .filter(\.$id != trackingItemID)
            .filter(\.$chain == chain)
            .first()
        {
            guard referenceTrackingItem.agentCode == trackingItem.agentCode else {
                throw AppError.invalidAgentCodeForChain
            }
            targetChain = chain
        }
        trackingItem.chain = targetChain
        if let payload = try await trackingItem.moveToStatus(to: .repacked, database: request.db) {
            try await request.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
        }
        try await trackingItem.save(on: request.db)
        try request.appendUserAction(.assignChain(trackingItemID: trackingItem.requireID(), chain: targetChain))
        try request.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: .repacked))
        return trackingItem.output()
    }

    private func getProductNameSuggestionsHandler(request: Request) async throws -> [String] {
        guard let trackingItemID = request.parameters.get(TrackingItem.parameter, as: TrackingItem.IDValue.self) else {
            throw AppError.invalidInput
        }
        guard let trackingItem = try await TrackingItem.query(on: request.db)
            .filter(\.$id == trackingItemID)
            .first() else {
            throw AppError.trackingItemNotFound
        }
        if
            let agentCode = trackingItem.agentCode,
            let sqlDB = request.db as? SQLDatabase
        {
            struct QueryRow: Content {
                var keyword: String
                var count: Int
            }
            let topDescriptions = try await sqlDB.raw("""
            select p.description as \(ident: "keyword"), count(distinct p.id) as \(ident: "count")
            from products p
            left join tracking_items ti on ti.id = p.tracking_item_id
            where ti.agent_code = \(bind: agentCode) and p.description <> \(bind: "")
            group by p.description
            order by count(distinct p.id) desc
            limit 5;
            """).all(decoding: QueryRow.self)

            var products = ["iPad", "Laptop", "Airpod"]
            let topProducts = topDescriptions.map(\.keyword)
            products.insert(contentsOf: topProducts, at: 0)
            products.removeDuplicates()
            products = products.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            return Array(products.prefix(10))
        }
        return ["iPad", "Laptop", "Airpod"]
    }

    private func getRepackingTotalsHandler(request: Request) async throws -> GetRepackingTotalsOutput {
        let repackingItems = try await TrackingItem.query(on: request.db)
            .filterRepacking()
            .all()

        return try GetRepackingTotalsOutput(items: repackingItems)
    }

    private func getRepackingItemsHandler(req : Request) async throws -> GetRepackingItemsOutput {
        let repackingItems = try await TrackingItem.query(on: req.db)
            .with(\.$customers)
            .filterRepacking()
            .all()
        return GetRepackingItemsOutput(items: repackingItems)
    }

    
    private func deleteProductHandler(request: Request) async throws -> HTTPResponseStatus {
        let product = try request.requireProduct()
        try await product.delete(on: request.db)
        let trackingItem = try request.requireTrackingItem()
        let allProductIDs = try await trackingItem.$products.query(on: request.db)
            .all(\.$id)
        try request.appendUserAction(.assignProducts(trackingItemID: trackingItem.requireID(), productIDs: allProductIDs))
        return .ok
    }

    private func updateProductHandler(request: Request) async throws -> ProductOutput {
        try UpdateProductInput.validate(content: request)
        let input = try request.content.decode(UpdateProductInput.self)
        let trackingItem = try request.requireTrackingItem()
        let trackingID = try trackingItem.requireID()
        let updatedProduct = try await request.db.transaction { transaction in
            let product = try request.requireProduct()
            if let images = input.images, images != product.images {
                product.images = images
                try request.appendUserAction(.assignProductImages(trackingItemID: trackingID, productID: product.requireID(), images: images))
            }
            if let description = input.description, description != product.description {
                product.description = description
                try request.appendUserAction(.assignProductDescription(trackingItemID: trackingID, productID: product.requireID(), description: description))
            }
            if let quantity = input.quantity, quantity != product.quantity {
                product.quantity = quantity
                try request.appendUserAction(.assignProductQuantity(trackingItemID: trackingID, productID: product.requireID(), quantity: quantity))
            }
            
            if product.hasChanges {
                try await product.save(on: transaction)
            }
            return product
        }
        return updatedProduct.toOutput()
    }

    private func createProductHandler(request: Request) async throws -> ProductOutput {
        let trackingItem = try request.requireTrackingItem()

        guard trackingItem.status.power >= TrackingItem.Status.repacking.power else {
            throw AppError.cantAddProductToTrackingItemBelowRepacking
        }

        let trackingItemID = try trackingItem.requireID()

        let productCount = try await trackingItem.$products.query(on: request.db).count()

        let newProduct = Product(
            trackingItemID: trackingItemID,
            images: [],
            index: productCount,
            description: "",
            quantity: 0
        )

        try await newProduct.save(on: request.db)
        
        let allProductIDs = try await trackingItem.$products.query(on: request.db)
            .all(\.$id)
        try request.appendUserAction(.assignProducts(trackingItemID: trackingItem.requireID(), productIDs: allProductIDs))
        return newProduct.toOutput()
    }
}
