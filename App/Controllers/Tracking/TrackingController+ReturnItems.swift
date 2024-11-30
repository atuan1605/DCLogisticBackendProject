import Vapor
import Foundation
import Fluent
import SQLKit

struct ReturnedItemController : RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("returnedItems")
        groupedRoutes.get(use: getReturnItemsHandler)
        let returnedItemRoutes = groupedRoutes
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())
        returnedItemRoutes.put(use: updateReturnedItemHandler)
    }
    
    private func updateReturnedItemHandler(req: Request) async throws -> HTTPResponseStatus {
        let input = try req.content.decode(UpdateReturnedItemInput.self)
        let trackingItem = try req.requireTrackingItem()
        
        if input.holdState != .holding {
            try await trackingItem.$buyerTrackingItems.load(on: req.db)
            guard let buyerTrackingItem = trackingItem.buyerTrackingItems.first else {
                throw AppError.buyerTrackingItemNotFound
            }
            if input.holdState == .continueDelivering {
                trackingItem.returnRequestAt = nil
                req.appendUserAction(.assignReturnRequest(trackingItemID: try trackingItem.requireID(), isReturn: true))
            }
            buyerTrackingItem.packingRequestState = .processed
            req.appendUserAction(.updatePackingRequestState(buyerTrackingItemID: try buyerTrackingItem.requireID(), state: .processed))
            try await buyerTrackingItem.save(on: req.db)
        }
        trackingItem.holdStateAt = Date()
        trackingItem.holdState = input.holdState
        req.appendUserAction(.updateTrackingItemHoldState(trackingItemID: try trackingItem.requireID(), holdState: input.holdState))
        if trackingItem.hasChanges {
            try await trackingItem.save(on: req.db)
        }
        return .ok
    }
    
    private func getReturnItemsHandler(req: Request) async throws -> Page<GetReturnedTrackingItemOutput> {
        let input = try req.query.decode(GetReturnedTrackingItemInput.self)
        
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        struct RowOutput: Content {
            var total: Int
            var id: TrackingItem.IDValue?
            var trackingNumber: String
            var customerCode: String?
            var holdRequestContent: String?
            var holdState: TrackingItem.HoldState?
            var holdStateAt: Date?
            var returnRequestAt: Date?
            var updatedBy: String?
            var packingRequestNote: String?
        }
        
        var query: SQLQueryString = """
        WITH filtered_action_loggers AS (
            SELECT DISTINCT ON ((type->'assignReturnRequest'->>'trackingItemID')::uuid)
                (type->'assignReturnRequest'->>'trackingItemID')::uuid AS target_id,
                action_loggers.created_at,
                (type->'assignReturnRequest'->>'isReturn') AS isReturn,
                user_id as userID
            FROM action_loggers
            WHERE (type->>'assignReturnRequest')::jsonb->>'isReturn' = 'true'
            ORDER BY (type->'assignReturnRequest'->>'trackingItemID')::uuid, action_loggers.created_at DESC
            )
            SELECT
                COUNT(*) OVER () as \(ident: "total"),
                ti.id as \(ident: "id"),
                ti.tracking_number as \(ident: "trackingNumber"),
                STRING_AGG(DISTINCT c.customer_code, ', ') as \(ident: "customerCode"),
                STRING_AGG(DISTINCT bti.packing_request, ', ') as \(ident: "holdRequestContent"),
                ti.hold_state as \(ident: "holdState"),
                ti.hold_state_at as \(ident: "holdStateAt"),
                ti.return_request_at as \(ident: "returnRequestAt"),
                u.username as \(ident: "updatedBy"),
                bti.packing_request_note as \(ident: "packingRequestNote")
            FROM
                tracking_items ti
            LEFT JOIN buyer_tracking_item_link_view blv ON blv.tracking_item_id = ti.id
            LEFT JOIN buyer_tracking_items bti ON blv.buyer_tracking_item_id = bti.id
            LEFT JOIN tracking_item_customers tic ON tic.tracking_item_id = ti.id
            LEFT JOIN customers c ON c.id = tic.customer_id
            LEFT JOIN filtered_action_loggers fal ON fal.target_id = ti.id
            LEFT JOIN users u ON u.id = fal.userID
            WHERE
                (ti.deleted_at IS NULL OR ti.deleted_at > now())
        """

        if let searchStrings = input.searchStrings {
            let regexSuffixGroup = searchStrings.joined(separator: "|")
            let searchTrackingNumberQueryString: SQLQueryString = """
            AND ti.tracking_number ~* '^.*(\(raw: regexSuffixGroup))$'
        """
            query = query + " " + searchTrackingNumberQueryString
        }
        switch input.holdState {
            case .holding:
            let holdingQueryString: SQLQueryString = """
            AND ti.hold_state = 'holding'
            AND ti.return_request_at is not null
            AND ti.broken_product_flag_at is null
        """
                query = query + " " + holdingQueryString
                break
            case .returnProduct:
            let returnProductQueryString: SQLQueryString = """
            AND ti.hold_state = 'returnProduct'
            AND ti.return_request_at is not null
        """
            query = query + " " + returnProductQueryString
                break
            case .continueDelivering:
            let continueDeliveringQueryString: SQLQueryString = """
            AND ti.hold_state = 'continueDelivering'
            AND ti.return_request_at is null
        """
            query = query + " " + continueDeliveringQueryString
                break
        case .none:
            let noneQueryString: SQLQueryString = """
            AND ti.hold_state is null
            AND ti.return_request_at is not null
            AND ti.broken_product_flag_at is null
        """
            query = query + " " + noneQueryString
        }
        
        if let fromDate = input.fromDate {
            let dateQueryString: SQLQueryString = """
                    AND DATE(ti.hold_state_at) >= \(bind: fromDate)
                """
            query = query + " " + dateQueryString
        }
        
        if let toDate = input.toDate {
            let dateQueryString: SQLQueryString = """
                    AND DATE(ti.hold_state_at) <= \(bind: toDate)
                """
            query = query + " " + dateQueryString
        }
        
        if let status = input.status {
            if status == .packingRequest {
                let packingRequestQueryString: SQLQueryString = """
                        AND bti.packing_request is not null
                        AND bti.packing_request <> ''
                    """
                query = query + " " + packingRequestQueryString
            }
            if status == .holded {
                let holdedItemQueryString: SQLQueryString = """
                        AND (bti.packing_request is null or bti.packing_request = '')
                    """
                query = query + " " + holdedItemQueryString
            }
        }
        let pagedQuery: SQLQueryString = """
            GROUP BY ti.id, ti.tracking_number, ti.hold_state, bti.created_at, bti.packing_request_state, u.username, bti.packing_request_note
            ORDER BY ti.updated_at desc
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
        let items: [GetReturnedTrackingItemOutput] = results.map{
            var targetHoldRequestContent: String? = nil
            if let content = $0.holdRequestContent, !content.isEmpty {
                targetHoldRequestContent = content
            }
            return GetReturnedTrackingItemOutput(
                id: $0.id,
                trackingNumber: $0.trackingNumber,
                customerCode: $0.customerCode,
                holdRequestContent: targetHoldRequestContent,
                holdState: $0.holdState,
                holdStateAt: $0.holdStateAt,
                returnRequestAt: $0.returnRequestAt,
                updatedBy: $0.updatedBy,
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
}
