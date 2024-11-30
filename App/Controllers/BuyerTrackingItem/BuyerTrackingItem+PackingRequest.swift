import Vapor
import Foundation
import Fluent
import SQLKit

struct PackingRequestController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("packingRequests")
        groupedRoutes.get(use: getPackingRequestsHandler)
        groupedRoutes.get("total", use: getPackingRequestsTotalHandler)
        groupedRoutes.put("deposit", use: updatePackingRequestDepositHandler)
    }
    
    private func updatePackingRequestDepositHandler(req: Request) async throws -> HTTPResponseStatus {
        let input = try req.content.decode(UpdateBuyerTrackingItemsDepositInput.self)
        try await BuyerTrackingItem.query(on: req.db)
            .filter(\.$id ~~ input.buyerTrackingItemIDs)
            .set(\.$paidAt, to: Date())
            .update()
        req.appendUserAction(.assignDeposit(buyerTrackingItemIDs: input.buyerTrackingItemIDs))
        return .ok
    }
    
    private func getPackingRequestsHandler(req: Request) async throws -> Page<GetPackingRequestOutput> {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        let input = try req.query.decode(GetTrackingPackingRequestInput.self)
        
        struct RowOutput: Content {
            var total: Int
            var createdAt: Date?
            var id: BuyerTrackingItem.IDValue?
            var trackingNumber: String?
            var packingRequest: String?
            var packingRequestState: BuyerTrackingItem.PackingRequestState?
            var customerCodes: String?
            var packingRequestNote: String?
            var files: [String]?
        }
        let requestType = "'" + [BuyerTrackingItem.RequestType.specialRequest.rawValue,
                           BuyerTrackingItem.RequestType.quantityCheck.rawValue,
                           BuyerTrackingItem.RequestType.holdTracking.rawValue,
                           BuyerTrackingItem.RequestType.returnTracking.rawValue]
            .joined(separator: "', '") + "'"
        var query: SQLQueryString = """
        WITH file_data AS (
            SELECT
                bti.id as bti_id,
                UNNEST(p.images) as image
            FROM
                buyer_tracking_items bti
                INNER JOIN buyer_tracking_item_link_view blv ON blv.buyer_tracking_item_id = bti.id
                INNER JOIN tracking_items ti ON ti.id = blv.tracking_item_id
                LEFT JOIN products p ON p.tracking_item_id = ti.id
        )
        SELECT
            bti.id as \(ident: "id"),
            ti.tracking_number as \(ident: "trackingNumber"),
            bti.packing_request as \(ident: "packingRequest"),
            bti.created_at as \(ident: "createdAt"),
            bti.packing_request_state as \(ident: "packingRequestState"),
            STRING_AGG(DISTINCT c.customer_code, ', ') as \(ident: "customerCodes"),
            COALESCE(ARRAY_AGG(DISTINCT fd.image) FILTER (WHERE fd.image IS NOT NULL), '{}') as \(ident: "files"),
            COUNT(*) OVER () as \(ident: "total"),
            bti.packing_request_note as \(ident: "packingRequestNote")
        FROM
            buyer_tracking_items bti
            INNER JOIN buyer_tracking_item_link_view blv ON blv.buyer_tracking_item_id = bti.id
            INNER JOIN tracking_items ti ON ti.id = blv.tracking_item_id
            LEFT JOIN tracking_item_customers tic ON tic.tracking_item_id = ti.id
            LEFT JOIN customers c ON c.id = tic.customer_id
            LEFT JOIN file_data fd ON fd.bti_id = bti.id
            WHERE
            bti.request_type in (\(raw: requestType))
            AND bti.packing_request is not null
            AND (ti.deleted_at IS NULL or ti.deleted_at > now())
        """
        if let searchStrings = input.searchStrings {
            let regexSuffixGroup = searchStrings.joined(separator: "|")
            let searchTrackingNumberQueryString: SQLQueryString = """
            AND bti.tracking_number ~* '^.*(\(raw: regexSuffixGroup))$'
        """
            query = query + " " + searchTrackingNumberQueryString
        }
        
        if let status = input.status {
            switch status {
            case .processed:
                let processedQueryString: SQLQueryString = """
            AND bti.packing_request_state = 'processed'
            """
                query = query + " " + processedQueryString
                break
            case .unprocessed:
                let holdQueryString: SQLQueryString = """
            AND bti.packing_request_state is NULL
            """
                query = query + " " + holdQueryString
                break
            }
        }
        
        if let agentID = input.agentID {
            let agentQuery: SQLQueryString = """
            AND ti.agent_code = \(bind: agentID)
        """
            query = query + " " + agentQuery
        }
        
        let pagedQuery: SQLQueryString = """
            GROUP BY bti.id, ti.tracking_number, bti.packing_request, bti.created_at, bti.packing_request_state, bti.packing_request_note
            ORDER BY bti.updated_at desc
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
        let items: [GetPackingRequestOutput] = results.map{
            return GetPackingRequestOutput(
                id: $0.id,
                createdAt: $0.createdAt,
                trackingNumber: $0.trackingNumber,
                customerCodes: $0.customerCodes,
                packingRequest: $0.packingRequest,
                packingRequestState: $0.packingRequestState,
                files: $0.files,
                packingRequestNote: $0.packingRequestNote
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
    
    private func getPackingRequestsTotalHandler(req: Request) async throws -> GetTrackingItemPackingRequestTotalOutput {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        let query = try req.buyerTrackingItemLinkViews.getPackingRequest(by: nil)
        struct RowOutput: Content {
            var total: Int
            var id: BuyerTrackingItemLinkView.IDValue?
            var trackingNumber: String?
            var packingRequest: String?
            var status: PackingRequestStatus
        }
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(query).all(decoding: RowOutput.self)
        } catch {
            throw error
        }
        let items: [GetTrackingItemPackingRequestOutput] = results.map{
            return GetTrackingItemPackingRequestOutput(
                id: $0.id,
                trackingNumber: $0.trackingNumber,
                packingRequest: $0.packingRequest,
                status: $0.status
            )
        }
        return .init(total: items.count, processed: items.filter { $0.status == .processed}.count, unprocessed: items.filter { $0.status == .unprocessed }.count)
    }
}
