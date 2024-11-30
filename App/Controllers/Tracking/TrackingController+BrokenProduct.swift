import Vapor
import Foundation
import Fluent

struct BrokenProductController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("brokenProducts")
        groupedRoutes.group(ScopeCheckMiddleware(requiredScope: .trackingItems)) {
            $0.get("paginated", use: getBrokenProductsHandler)
        }
    }

    private func getBrokenProductsHandler(request: Request) async throws -> Page<TrackingItemOutput> {
        let input = try request.query.decode(GetBrokenProductQueryInput.self)
        var query = TrackingItem.query(on: request.db)
            .group(.and) { group in
                group
                    .filter(\.$brokenProduct.$description != nil)
                    .filter(\.$brokenProduct.$description != "")
            }
            .filter(\.$brokenProduct.$flagAt != nil)
            .sort(\.$brokenProduct.$flagAt, .descending)
        
        if let agentID = input.agentID {
            query = query.filter(\.$agentCode == agentID)
        }
        if let customerFeedback = input.customerFeedback {
            query = query.filter(\.$brokenProduct.$customerFeedback == customerFeedback)
        }
        let page = try await query.paginate(for: request)
        let items = await page.items.asyncMap({
            return $0.output()
        })
        return .init(items: items, metadata: page.metadata)
    }
}
