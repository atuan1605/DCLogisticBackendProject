import Foundation
import Vapor
import Fluent
import SQLKit

struct WarehouseController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("warehouses")

        let authenticated = groupedRoutes
            .grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())
        
        let scopeRoute = authenticated .grouped(ScopeCheckMiddleware(requiredScope: [.updateWarehouse]))
        
        scopeRoute.post(use: createWarehouseHandler)
        
        let warehouseRoutes = scopeRoute
            .grouped(Warehouse.parameterPath)
            .grouped(WarehouseIdentifyingMiddleware())
        warehouseRoutes.put(use: updateWarehouseHandler)
        
        authenticated.get("list", use: getListHandler)
        authenticated.get(use: getAllWarehouses)
        authenticated.get("totalTrackingByWarehouse", use: getTotalTrackingByWarehouseHandler)
        authenticated.get("trackingItems", use: getTrackingItemsByWarehouseHandler)
    }
    
    private func getTrackingItemsByWarehouseHandler(req: Request) async throws -> Page<GetTrackingItemByWarehouseOutput> {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        let input = try req.query.decode(GetTrackingItemByWarehouseInput.self)
        struct RowOutput: Content {
            var total: Int
            var trackingNumber: String
            var id: TrackingItem.IDValue?
            var receivedAtUSAt: Date?
            var files: [String]?
            var productName: String?
            var customers: String?
        }
        var query: SQLQueryString = """
            WITH file_data AS (
                SELECT
                    ti.id AS ti_id,
                    UNNEST(p.images) AS image,
                    p.description AS description
                FROM
                    tracking_items ti
                LEFT JOIN products p ON p.tracking_item_id = ti.id
            )
            SELECT
                COUNT(*) OVER () as \(ident: "total"),
                ti.id AS \(ident: "id"),
                ti.tracking_number AS \(ident: "trackingNumber"),
                ti.received_at_us_at AS \(ident: "receivedAtUSAt"),
                STRING_AGG(DISTINCT c.customer_code, ', ' ORDER BY c.customer_code) AS \(ident: "customers"),
                fd.description \(ident: "productName"),
                COALESCE(ARRAY_AGG(DISTINCT fd.image) FILTER (WHERE fd.image IS NOT NULL), '{}') AS \(ident: "files")
            FROM
                tracking_items ti
            LEFT JOIN
                tracking_item_customers tic ON ti.id = tic.tracking_item_id
            LEFT JOIN
                customers c ON tic.customer_id = c.id
            LEFT JOIN
                file_data fd ON fd.ti_id = ti.id
            WHERE ti.agent_code = \(bind: input.agentID)
            AND ti.warehouse_id = \(bind: input.warehouseID)
            AND (ti.deleted_at IS NULL or ti.deleted_at > now())
        """
        if let fromDate = input.fromDate {
            let dateQuery: SQLQueryString = """
            AND DATE(ti.received_at_us_at) >= \(bind: fromDate)
        """
            query = query + " " + dateQuery
        }
        if let toDate = input.toDate {
            let dateQuery: SQLQueryString = """
            AND DATE(ti.received_at_us_at) <= \(bind: toDate)
        """
            query = query + " " + dateQuery
        }
        let groupedQuery: SQLQueryString = """
            GROUP BY ti.id, ti.tracking_number, ti.received_at_us_at, fd.description
        """
        query = query + " " + groupedQuery
        if let sortedType = input.sortedType, let orderType = input.orderType {
            var sortedQuery: SQLQueryString = """
        """
            switch sortedType {
            case .customerCode:
                sortedQuery = """
            ORDER BY customers \(raw: orderType.rawValue)
            """
                break
            case .date:
                sortedQuery = """
            ORDER BY ti.received_at_us_at \(raw: orderType.rawValue)
            """
                break
            case .productName:
                sortedQuery = """
            ORDER BY fd.description \(raw: orderType.rawValue)
            """
                break
            case .trackingNumber:
                sortedQuery = """
            ORDER BY ti.tracking_number \(raw: orderType.rawValue)
            """
                break
            }
            query = query + " " + sortedQuery
        }
        let pagedQuery: SQLQueryString = """
            limit \(bind: input.per)
            offset \(bind: input.per * (input.page - 1))
        """
        query = query + " " + pagedQuery
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(query).all(decoding: RowOutput.self)
        } catch {
            throw error
        }
        let total = results.first?.total ?? 0
        let items: [GetTrackingItemByWarehouseOutput] = results.map {
            return GetTrackingItemByWarehouseOutput(
                id: $0.id,
                trackingNumber: $0.trackingNumber,
                receivedAtUSAt: $0.receivedAtUSAt,
                files: $0.files,
                productName: $0.productName,
                customers: $0.customers
            )
        }
        return Page(
            items: items,
            metadata: .init(
                page: input.page,
                per: input.per,
                total: total
            )
        )
    }
    
    private func createWarehouseHandler(req: Request) async throws -> WarehouseOutput {
        try CreateWarehouseInput.validate(content: req)
        let input = try req.content.decode(CreateWarehouseInput.self)
        let newWarehouse = input.toWarehouse()
        try await newWarehouse.save(on: req.db)
        try req.appendUserAction(.createWarehouse(warehouseID: newWarehouse.requireID()))
        return newWarehouse.output()
    }
    
    private func updateWarehouseHandler(req: Request) async throws -> WarehouseOutput {
        let warehouse = try req.requireWarehouse()
        let input = try req.content.decode(UpdateWarehouseInput.self)
        if let isInactive = input.isInactive {
            if isInactive && warehouse.inactiveAt == nil {
                let now = Date()
                warehouse.inactiveAt = now
                try req.appendUserAction(.updateWarehouse(warehouseID: warehouse.requireID(), inactiveAt: now))
                if try await warehouse.$users.query(on: req.db).count() > 0 {
                    try await UserWarehouse.query(on: req.db)
                        .filter(\.$warehouse.$id == warehouse.requireID())
                        .delete()
                }
            } else if !isInactive && warehouse.inactiveAt != nil {
                warehouse.inactiveAt = nil
                try req.appendUserAction(.updateWarehouse(warehouseID: warehouse.requireID(), inactiveAt: nil))
            }
            try await warehouse.save(on: req.db)
        }
        return warehouse.output()
    }
    
    private func getListHandler(request: Request) async throws -> [WarehouseOutput] {
        let user = try request.requireAuthUser()
        
        let warehouses = try await user.$warehouses.query(on: request.db)
            .filter(Warehouse.self, \.$inactiveAt == nil)
            .sort(UserWarehouse.self, \.$index, .ascending)
            .all()
        return warehouses.map { $0.output() }
    }
    
    private func getAllWarehouses(req: Request) async throws -> [WarehouseOutput] {
        let input = try req.query.decode(GetWarehouseQueryInput.self)
        var query = Warehouse.query(on: req.db)
        if let searchString = input.searchString {
            query = query.filter(.sql(raw: "\(Warehouse.schema).name"),
                                 .custom("ILIKE"),
                                 .bind("%\(searchString)%"))
        }
        let warehouses = try await query
            .filter(\.$inactiveAt == nil)
            .sort(\.$createdAt, .descending)
            .all()
        return warehouses.map{ $0.output() }
    }
    
    private func getTotalTrackingByWarehouseHandler(request: Request) async throws -> [WarehouseForTotalTrackingOutput] {
        let input = try request.query.decode(TrackingStatsByWarehouseInput.self)
        
        let user = try request.requireAuthUser()
        let warehouses = try await user.$warehouses.query(on: request.db)
            .sort(UserWarehouse.self, \.$index, .ascending)
            .all()
        let warehouseIDs = try warehouses.map { try $0.requireID() }
        var query = TrackingItem.query(on: request.db)
            .filter(\.$agentCode == input.agentID)
            .filter(\.$warehouse.$id ~~ warehouseIDs)
            .with(\.$warehouse)
            
        if let fromDate = input.fromDate {
            query = query.filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
        }
        if let toDate = input.toDate {
            query = query.filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"), .lessThanOrEqual, .bind(toDate))
        }
        
        let trackingItems = try await query.all()

        return warehouses.map { $0.totalOutput(trackingItems: trackingItems )}
    }
}
