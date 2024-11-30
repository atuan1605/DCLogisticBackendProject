import Vapor
import Foundation
import Fluent
import SQLKit

struct TrackingItemReportController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("reports")
        
        groupedRoutes.get("total", use: getTotalTrackingItemHandler)
        groupedRoutes.get(use: getTrackingItemsHandler)
        groupedRoutes.get("count", use: getTrackingItemsCountHandler)
    }
    
    private func getTrackingItemsCountHandler(req: Request) async throws -> TrackingItemCountByDateOutput {
        let input = try req.query.decode(GetTrackingItemReportsQueryInput.self)
        let fromDate = input.fromDate
        let toDate = input.toDate
        let now = Date()
        
        struct RowOutput: Content {
            var total: Int
            var files: Int
            var flyingBack: Int
            var unflyingBack: Int
        }
        
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        
        var queryString: SQLQueryString = """
            select count(*) as \(ident: "total"),
            sum(case when ad.images is not null then 1 else 0 end) as \(ident: "files"),
            sum(case when ad.boxed_at is not null then 1 else 0 end) as \(ident: "flyingBack"),
            sum(case when ad.boxed_at is null then 1 else 0 end) as \(ident: "unflyingBack")
            FROM
            (select ti.deleted_at, tip.boxed_at, p.images, ti.received_at_us_at, ti.agent_code, ti.warehouse_id
                from tracking_item_pieces as tip
                left join tracking_items as ti on ti.id = tip.tracking_item_id
                left join (select distinct on (products.tracking_item_id) * from products where products.images is not null and array_length(products.images, 1) > 0) as p on p.tracking_item_id = ti.id) as ad
            WHERE ad.deleted_at > \(bind: now)
            AND DATE(ad.received_at_us_at) >= \(bind: fromDate)
            AND DATE(ad.received_at_us_at) <= \(bind: toDate)
        """
        if let agentIDs = input.agentIDs, agentIDs.count > 0 {
            let agentIDsString = "'" + agentIDs.joined(separator: "', '") + "'"
            let agentQuery: SQLQueryString = """
            AND ad.agent_code IN (\(unsafeRaw: agentIDsString))
        """
            queryString = queryString + " " + agentQuery
        }
        if let warehouseIDs = input.warehouseIDs, warehouseIDs.count > 0 {
            let warehouseIDsString = "'" + warehouseIDs.map{ $0.uuidString }.joined(separator: "', '") + "'"
            let warehouseQuery: SQLQueryString = """
            AND ad.warehouse_id IN (\(unsafeRaw: warehouseIDsString))
        """
            queryString = queryString + " " + warehouseQuery
        }
        let results: [TrackingItemCountByDateOutput]
        do {
            results = try await sqlDB.raw(queryString).all(decoding: TrackingItemCountByDateOutput.self)
            print(results)
        } catch {
            print(String(reflecting: error))
            throw error
        }
        
        return results.first ?? .init(items: [])
    }
    
    private func getTrackingItemsHandler(req: Request) async throws -> Page<TrackingItemPieceReportOutput> {
        let input = try req.query.decode(GetTrackingItemReportsQueryInput.self)
        let now = Date()
        struct RowOutput: Content {
            var total: Int
            var id: TrackingItemPiece.IDValue?
            var trackingNumber: String?
            var information: String?
            var receivedAtUSAt: Date?
            var flyingBackAt: Date?
            var files: [String]?
            var receivedAtVNAt: Date?
            var customerCodes: String?
        }
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        
        var queryString: SQLQueryString = """
        select count(*) OVER () as \(ident: "total"),
        ad.information as \(ident: "information"),
        ad.id as \(ident: "id"),
        ad.boxed_at as \(ident: "flyingBackAt"),
        ad.tracking_number as \(ident: "trackingNumber"),
        ad.images as \(ident: "files"),
        ad.received_at_vn_at as \(ident: "receivedAtVNAt"),
        ad.received_at_us_at as \(ident: "receivedAtUSAt"),
        STRING_AGG(DISTINCT ad.customer_code, ', ') as \(ident: "customerCodes")
        FROM
            (select ti.deleted_at, tip.boxed_at, p.images, ti.received_at_us_at, ti.received_at_vn_at, ti.tracking_number, tip.id, tip.information, ti.agent_code, ti.warehouse_id, c.customer_code
                from tracking_item_pieces as tip
                left join tracking_items as ti on ti.id = tip.tracking_item_id
                left join tracking_item_customers tic ON tic.tracking_item_id = ti.id
                left join customers c ON c.id = tic.customer_id
                left join (select distinct on (products.tracking_item_id) * from products where products.images is not null and array_length(products.images, 1) > 0) as p on p.tracking_item_id = ti.id) as ad
        WHERE ad.deleted_at > \(bind: now)
        
        """
        if let searchStrings = input.searchStrings {
            let regexSuffixGroup = searchStrings.joined(separator: "|")
            let searchTrackingNumberQueryString: SQLQueryString = """
            AND ad.tracking_number ~* '^.*(\(raw: regexSuffixGroup))$'
        
        """
            queryString = queryString + searchTrackingNumberQueryString
        } else {
            let fromDate = input.fromDate
            let toDate = input.toDate
            
            let dateQueryString: SQLQueryString = """
                    AND DATE(ad.received_at_us_at) >= \(bind: fromDate)
                    AND DATE(ad.received_at_us_at) <= \(bind: toDate)
                
                """
            queryString = queryString + dateQueryString

            if let searchType = input.searchType {
                switch searchType {
                case .unflyingBack:
                    let unflyingBackQuery: SQLQueryString = """
                        AND ad.boxed_at IS NULL
                    
                    """
                    queryString = queryString + unflyingBackQuery
                    break
                case .flyingBack:
                    let flyingBackQuery: SQLQueryString = """
                        AND ad.boxed_at IS NOT NULL
                    
                    """
                    queryString = queryString + flyingBackQuery
                    break
                case .files:
                    let filesQuery: SQLQueryString = """
                        AND ad.images IS NOT NULL
                        AND array_length(ad.images, 1) > 0
                    
                    """
                    queryString = queryString + filesQuery
                    break
                default:
                    break
                }
            }
        }
        if let agentIDs = input.agentIDs {
            let agentIDsString = "'" + agentIDs.joined(separator: "', '") + "'"
            let agentQuery: SQLQueryString = """
            AND ad.agent_code IN (\(raw: agentIDsString))
        """
            queryString = queryString + " " + agentQuery
        }
        if let warehouseIDs = input.warehouseIDs {
            let warehouseIDsString = "'" + warehouseIDs.map{ $0.uuidString }.joined(separator: "', '") + "'"
            let warehouseQuery: SQLQueryString = """
            AND ad.warehouse_id IN (\(raw: warehouseIDsString))
        """
            queryString = queryString + " " + warehouseQuery
        }
        
        let sortedQuery: SQLQueryString = """
        GROUP BY \(ident: "id"), \(ident: "information"), \(ident: "flyingBackAt"), \(ident: "trackingNumber"), \(ident: "receivedAtVNAt"), \(ident: "receivedAtUSAt"), \(ident: "files")
        ORDER BY \(ident: "files") DESC, \(ident: "flyingBackAt") DESC, \(ident: "receivedAtUSAt") DESC
        limit \(bind: input.per)
        offset \(bind: input.per * (input.page - 1))
    """
        queryString = queryString + sortedQuery
        
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(queryString).all(decoding: RowOutput.self)
            print(results)
        } catch {
            print(String(reflecting: error))
            throw error
        }
        let total = results.first?.total ?? 0
        
        let items: [TrackingItemPieceReportOutput] = results.map {
            return TrackingItemPieceReportOutput(
                id: $0.id,
                trackingNumber: $0.trackingNumber,
                information: $0.information,
                receivedAtUSAt: $0.receivedAtUSAt,
                flyingBackAt: $0.flyingBackAt,
                files: $0.files,
                receivedAtVNAt: $0.receivedAtVNAt,
                customers: $0.customerCodes
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
    
    private func getTotalTrackingItemHandler(req: Request) async throws -> Page<TotalTrackingItemByDateOutput> {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        let now = Date()
        let input = try req.query.decode(TotalTrackingItemQueryInput.self)
        
        struct RowOutput: Content {
            var total: Int
            var receivedAtUSAt: Date
            var allItems: Int
            var flyingBackItems: Int
            var itemWithFiles: Int
            var unflyingBackItems: Int
        }
        var query: SQLQueryString = """
            SELECT
              DATE(ad.received_at_us_at) as \(ident: "receivedAtUSAt"),
              COUNT(CASE WHEN ad.boxed_at IS NOT NULL THEN 1 END) as \(ident: "flyingBackItems"),
              COUNT(CASE WHEN ad.boxed_at IS NULL THEN 1 END) as \(ident: "unflyingBackItems"),
              COUNT(CASE WHEN ad.images IS NOT NULL THEN 1 END) as \(ident: "itemWithFiles"),
              COUNT(*) as \(ident: "allItems"),
              COUNT(*) OVER () as \(ident: "total")
            FROM
              (select ti.deleted_at, tip.boxed_at, p.images, ti.received_at_us_at, ti.agent_code, ti.warehouse_id
                from tracking_item_pieces as tip
                left join tracking_items as ti on ti.id = tip.tracking_item_id
                left join (select distinct on (products.tracking_item_id) * from products where products.images is not null and array_length(products.images, 1) > 0) as p on p.tracking_item_id = ti.id) as ad
            WHERE ad.deleted_at > \(bind: now)
        
        """
        let fromDate = input.fromDate
        let toDate = input.toDate
        
        if fromDate != toDate {
            let toDateQueryString: SQLQueryString = """
                AND DATE(ad.received_at_us_at) >= \(bind: fromDate)
                AND DATE(ad.received_at_us_at) <= \(bind: toDate)
            
            """
            query = query + toDateQueryString
        } else {
            let toDateQueryString: SQLQueryString = """
                AND DATE(ad.received_at_us_at) = \(bind: toDate)::DATE
               
            """
            query = query + toDateQueryString
        }
        if let agentIDs = input.agentIDs, agentIDs.count > 0 {
            let agentIDsString = "'" + agentIDs.joined(separator: "', '") + "'"
            let agentQuery: SQLQueryString = """
            AND ad.agent_code IN (\(unsafeRaw: agentIDsString))
        """
            query = query + " " + agentQuery
        }
        if let warehouseIDs = input.warehouseIDs, warehouseIDs.count > 0 {
            let warehouseIDsString = "'" + warehouseIDs.map{ $0.uuidString }.joined(separator: "', '") + "'"
            let warehouseQuery: SQLQueryString = """
            AND ad.warehouse_id IN (\(unsafeRaw: warehouseIDsString))
        """
            query = query + " " + warehouseQuery
        }
        
            let sortedQuery: SQLQueryString = """
            GROUP BY \(ident: "receivedAtUSAt")
            ORDER BY \(ident: "receivedAtUSAt") DESC
            limit \(bind: input.per)
            offset \(bind: input.per * (input.page - 1))
        """
            query = query + sortedQuery
        
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(query).all(decoding: RowOutput.self)
            print(results)
        } catch {
            print(String(reflecting: error))
            throw error
        }
        let total = results.first?.total ?? 0
        
        let items: [TotalTrackingItemByDateOutput] = results.map{
            return TotalTrackingItemByDateOutput(
                receivedAtUSAt: $0.receivedAtUSAt,
                allItems: $0.allItems,
                flyingBackItems: $0.flyingBackItems,
                itemWithFiles: $0.itemWithFiles,
                unflyingBackItems: $0.unflyingBackItems
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
}
