import Foundation
import Vapor
import Fluent

struct TrackingRepackedController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group(ScopeCheckMiddleware(requiredScope: [.usInventory])) {
            let groupedRoutes = $0.grouped("repacked")
            groupedRoutes.get( use: getRepackedItemsHandler)
            groupedRoutes.get("totals", use: getRepackedTotalsHandler)
//            groupedRoutes.get("paginated", use: getRepackedItemsPaginatedHandler)
            groupedRoutes.get("protracted", use: getProtractedItemsHandler)
        }
        
        let trackingItemRoutes = routes
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())
        
        trackingItemRoutes.group(ScopeCheckMiddleware(requiredScope: .updateTrackingItems)) {
            $0.post("moveBackToPacking", use: moveBackToPackingHandler)
        }
    }

    private func moveBackToPackingHandler(request: Request) async throws -> TrackingItemOutput {
        let trackingItem = try request.requireTrackingItem()

        guard trackingItem.status == .repacked else {
            throw AppError.cantRevertToRepackingIfItemNotRepacked
        }

        trackingItem.chain = nil
        _ = try await trackingItem.moveToStatus(to: .repacking, database: request.db)

        try await trackingItem.save(on: request.db)
        try request.appendUserAction(.assignChain(trackingItemID: trackingItem.requireID(), chain: nil))
        try request.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: .repacking))

        return trackingItem.output()
    }

    private func getRepackedItemsHandler(request: Request) async throws -> GetRepackedItemsOutput2 {
        let chainItems = try await TrackingItem.query(on: request.db)
            .with(\.$customers)
            .filter(\.$chain != nil)
            .filter(\.$repackedAt != nil)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$flyingBackAt == nil)
            .filter(\.$boxedAt == nil)
            .all()
        return GetRepackedItemsOutput2(items: chainItems)
    }

    private func getRepackedTotalsHandler(request: Request) async throws -> GetRepackedTotalsOutput {
        let repackedItems = try await TrackingItem.query(on: request.db)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$flyingBackAt == nil)
            .filter(\.$boxedAt == nil)
            .filter(\.$repackedAt != nil)
            .all()
        
        return try GetRepackedTotalsOutput(items: repackedItems)
    }
    
//    private func getRepackedItemsPaginatedHandler(req: Request) async throws -> Page<GetRepackedItemsPaginatedOutput> {
//        let input = try req.query.decode(GetRepackedItemsQueryInput.self)
//
//        let query = TrackingItem.query(on: req.db)
//            .filterRepacked()
//            .with(\.$products)
//            .sort(\.$repackedAt, .descending)
//            .filter(\.$agentCode == input.agentID.uppercased().trimmingCharacters(in: .whitespacesAndNewlines))
//
//        if let searchStrings = input.searchStrings {
//            query.filter(searchStrings: searchStrings, includeAlternativeRef: true)
//        }
//
//        if let fromDate = input.fromDate {
//            query.filter(.sql(raw: "\(TrackingItem.schema).repacked_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
//        }
//        if let toDate = input.toDate {
//            query.filter(.sql(raw: "\(TrackingItem.schema).repacked_at::DATE"), .lessThanOrEqual, .bind(toDate))
//        }
//
//        if let products = input.products {
//            query.join(Product.self, on: \Product.$trackingItem.$id == \TrackingItem.$id)
//                .filter(products: products)
//                .unique()
//                .fields(for: TrackingItem.self)
//        }
//
//        let page = try await query.paginate(for: req)
//
//        return .init(
//            items: try await page.items.asyncMap({ try await $0.toRepackedOutput(on: req.db)
//            }),
//            metadata: page.metadata)
//    }
    
    private func getProtractedItemsHandler(req: Request) async throws -> GetProtractedTrackingItemsOutput {
        let input = try req.query.decode(GetProtractedTrackingItemsInput.self)
        let protractDayLimit = 3.0
        let protractDate = Date().addingTimeInterval(.oneDay*(-protractDayLimit))
        let repackedItems = try await TrackingItem.query(on: req.db)
            .filter(\.$agentCode == input.agentID)
            .filterRepacked()
            .filter(\.$repackedAt <= protractDate)
            .sort(\.$repackedAt, .ascending)
            .all()
        
        return GetProtractedTrackingItemsOutput(items: repackedItems)
    }
}
