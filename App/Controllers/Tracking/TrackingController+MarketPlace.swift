import Foundation
import Vapor
import Fluent

struct TrackingMarketPlaceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("marketPlaces")
        groupedRoutes.get("files", use: getTrackingFilesHandler)
    }
    
    private func getTrackingFilesHandler(req: Request) async throws -> [String] {
        let input = try req.query.decode(GetDCTrackingItemInput.self)
        let query = TrackingItem.query(on: req.db)
            .group(.or) { builder in
                builder.filter(trackingNumbers: [input.trackingNumber])
                builder.filter(alternativeRefs: [input.trackingNumber])
            }
        guard let trackingItem = try await query
            .with(\.$products)
            .first() else {
            throw AppError.trackingItemNotFound
        }
        let files = trackingItem.files
        let productFiles = trackingItem.products.flatMap {
            return $0.images
        }
        return [files, productFiles].flatMap({ $0 })
    }
}
