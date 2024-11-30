import Foundation
import SQLKit
import Vapor
import Fluent

struct TrackingReceivedAtUSController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("receivedAtUS")
        groupedRoutes.group(ScopeCheckMiddleware(requiredScope: .usInventory)) {
            $0.get(use: getReceivedAtUSItemsHandler)
            $0.get("paginated", use: getReceivedAtUSPaginatedHandler)
            $0.post(use: createHandler)
            $0.post("register", use: registerHandler)
            $0.get("protracted", use: getProtractedItemsHandler)
            $0.get("sourceWarehouses", use: getTrackingItemBySourceWarehousesHandler)
            $0.get("destinationWarehouses", use: getTrackingItemByDestinationWarehousesHandler)
            $0.put("warehouses", use: switchTrackingToAnotherWarehouseHandler)
        }
    }
    
    private func switchTrackingToAnotherWarehouseHandler(req: Request) async throws -> GetTrackingByWarehousesOutput {
        let input = try req.content.decode(ChangeWarehouseInput.self)
        guard input.sourceWarehouseID != input.destinationWarehouseID else {
            throw AppError.invalidInput
        }
        let warehouses = try await Warehouse.query(on: req.db)
            .filter(\.$id ~~ [input.sourceWarehouseID, input.destinationWarehouseID])
            .all()
        guard let sourceWarehouse = warehouses.first(where: {$0.id == input.sourceWarehouseID}) else {
            throw AppError.warehouseNotFound
        }
        guard let destinationWarehouse = warehouses.first(where: {$0.id == input.destinationWarehouseID}) else {
            throw AppError.warehouseNotFound
        }
        let user = try req.requireAuthUser()
        var targetTracking = try await TrackingItem.query(on: req.db)
            .filter(trackingNumbers: [input.trackingNumber])
            .filterDeli()
            .filter(\.$warehouse.$id == input.sourceWarehouseID)
            .first()
        
        if targetTracking == nil {
            let trackingReference = try await TrackingItemReference.query(on: req.db)
                .filter(trackingNumbers: [input.trackingNumber])
                .first()
            if let trackingItemReference = trackingReference {
                targetTracking = try await TrackingItem.query(on: req.db)
                    .filter(\.$id == trackingItemReference.$trackingItem.id)
                    .filterDeli()
                    .filter(\.$warehouse.$id == input.sourceWarehouseID)
                    .first()
            }
        }
        guard
            let trackingItem = targetTracking
        else {
            throw AppError.trackingItemNotFound
        }
        
        try req.appendUserAction(.switchTrackingToAnotherWarehouse(trackingItemID: trackingItem.requireID(), trackingNumber: trackingItem.trackingNumber, sourceWarehouseID: sourceWarehouse.requireID(), destinationWarehouseID: destinationWarehouse.requireID(), sourceWarehouseName: sourceWarehouse.name, destinationWarehouseName: destinationWarehouse.name))
        trackingItem.$warehouse.id = input.destinationWarehouseID
        try await trackingItem.save(on: req.db)
            
        return trackingItem.toWarehouseOutput(updatedBy: user.username)
    }
    
    private func getTrackingItemBySourceWarehousesHandler(req: Request) async throws -> Page<GetTrackingByWarehousesOutput> {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        let input = try req.query.decode(GetTrackingByWarehousesInput.self)
        
        struct RowOutput: Content {
            var total: Int
            var id: TrackingItem.IDValue?
            var trackingNumber: String
            var receivedAtUSAt: Date?
            var updatedAt: Date?
            var warehouseID: Warehouse.IDValue?
        }
        
        var queryString: SQLQueryString = """
            WITH filter_tracking AS (
                SELECT
                    (type->'switchTrackingToAnotherWarehouse'->>'trackingID')::uuid AS filter_tracking_id,
                    created_at,
                    ROW_NUMBER() OVER (PARTITION BY (type->'switchTrackingToAnotherWarehouse'->>'trackingID')::uuid ORDER BY created_at DESC) AS row_num
                FROM action_loggers
                WHERE (type->'switchTrackingToAnotherWarehouse')::jsonb->>'destinationWarehouseID' = '\(raw: input.destinationWarehouseID.uuidString)'
                AND (type->'switchTrackingToAnotherWarehouse')::jsonb->>'sourceWarehouseID' = '\(raw: input.sourceWarehouseID.uuidString)'
            )
            SELECT
                ti.id as \(ident: "id"),
                ti.tracking_number as \(ident: "trackingNumber"),
                ti.received_at_us_at as \(ident: "receivedAtUSAt"),
                ti.updated_at as \(ident: "updatedAt"),
                ti.warehouse_id \(ident: "warehouseID"),
                COUNT(*) OVER () as \(ident: "total")
            FROM tracking_items ti
            WHERE ti.received_at_us_at is not null
              AND ti.boxed_at is null
              AND ti.repacked_at is null
              AND ti.flying_back_at is null
              AND ti.archived_at is null
              AND ti.received_at_vn_at is null
              AND (ti.deleted_at IS NULL or ti.deleted_at > now())
                AND (
                    (ti.warehouse_id = \(bind: input.sourceWarehouseID))
                  OR
                    (ti.id IN (
                        SELECT filter_tracking_id
                        FROM filter_tracking
                        WHERE row_num = 1
                    ) AND ti.warehouse_id = \(bind: input.destinationWarehouseID))
                )
        """
        
        if let fromDate = input.fromDate {
            let queryFromDate: SQLQueryString = """
            AND DATE(ti.received_at_us_at) >= \(bind: fromDate)
        """
            queryString = queryString + " " + queryFromDate
        }
        
        if let toDate = input.toDate {
            let queryToDate: SQLQueryString = """
            AND DATE(ti.received_at_us_at) <= \(bind: toDate)
        """
            queryString = queryString + " " + queryToDate
        }
        
        let pagedQuery: SQLQueryString = """
            GROUP BY \(ident: "id"), \(ident: "trackingNumber"), \(ident: "receivedAtUSAt"), \(ident: "updatedAt"), \(ident: "warehouseID")
            ORDER BY \(ident: "receivedAtUSAt") DESC
            LIMIT \(bind: input.per)
            OFFSET \(bind: input.per * (input.page - 1))
        """
        queryString = queryString + " " + pagedQuery
        
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(queryString).all(decoding: RowOutput.self)
        } catch {
            throw error
        }
        
        let total = results.first?.total ?? 0
        let items: [GetTrackingByWarehousesOutput] = results.map {
            return GetTrackingByWarehousesOutput(
                id: $0.id,
                trackingNumber: $0.trackingNumber,
                receivedAtUSAt: $0.receivedAtUSAt,
                updatedAt: $0.updatedAt,
                warehouseID: $0.warehouseID
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
    
    private func getTrackingItemByDestinationWarehousesHandler(req: Request) async throws -> Page<GetTrackingByWarehousesOutput> {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        let input = try req.query.decode(GetTrackingByWarehousesInput.self)
        struct RowOutput: Content {
            var total: Int
            var id: TrackingItem.IDValue?
            var trackingNumber: String
            var receivedAtUSAt: Date?
            var updatedAt: Date?
            var warehouseID: Warehouse.IDValue?
            var updatedBy: String?
        }
        var queryString: SQLQueryString = """
            WITH filter_tracking AS (
                SELECT
                    (type->'switchTrackingToAnotherWarehouse'->>'trackingID')::uuid AS filter_tracking_id,
                    created_at,
                    ROW_NUMBER() OVER (PARTITION BY (type->'switchTrackingToAnotherWarehouse'->>'trackingID')::uuid ORDER BY created_at DESC) AS row_num,
                    user_id as userID
                FROM action_loggers
                WHERE (type->'switchTrackingToAnotherWarehouse')::jsonb->>'destinationWarehouseID' = '\(raw: input.destinationWarehouseID.uuidString)'
                  AND (type->'switchTrackingToAnotherWarehouse')::jsonb->>'sourceWarehouseID' = '\(raw: input.sourceWarehouseID.uuidString)'
            )
            SELECT
                ti.id as \(ident: "id"),
                ti.tracking_number as \(ident: "trackingNumber"),
                ti.received_at_us_at as \(ident: "receivedAtUSAt"),
                ti.updated_at as \(ident: "updatedAt"),
                ti.warehouse_id \(ident: "warehouseID"),
                u.username as \(ident: "updatedBy"),
                COUNT(*) OVER () as \(ident: "total")
            FROM tracking_items ti
            LEFT JOIN filter_tracking ft ON ft.filter_tracking_id = ti.id
            LEFT JOIN users u ON u.id = ft.userID
            WHERE ti.received_at_us_at is not null
              AND ti.boxed_at is null
              AND ti.repacked_at is null
              AND ti.flying_back_at is null
              AND ti.archived_at is null
              AND ti.received_at_vn_at is null
              AND (ti.deleted_at IS NULL or ti.deleted_at > now())
              AND (ti.id IN (
                      SELECT filter_tracking_id
                      FROM filter_tracking
                      WHERE row_num = 1
                  )
            AND ti.warehouse_id = \(bind: input.destinationWarehouseID))
        """
        if let fromDate = input.fromDate {
            let queryFromDate: SQLQueryString = """
            AND DATE(ti.updated_at) >= \(bind: fromDate)
        """
            queryString = queryString + " " + queryFromDate
        }
        
        if let toDate = input.toDate {
            let queryToDate: SQLQueryString = """
            AND DATE(ti.updated_at) <= \(bind: toDate)
        """
            queryString = queryString + " " + queryToDate
        }
        
        let pagedQuery: SQLQueryString = """
            GROUP BY ti.id, \(ident: "trackingNumber"), \(ident: "receivedAtUSAt"), \(ident: "updatedAt"), \(ident: "warehouseID"), \(ident: "updatedBy")
            ORDER BY \(ident: "updatedAt") DESC
            LIMIT \(bind: input.per)
            OFFSET \(bind: input.per * (input.page - 1))
        """
        queryString = queryString + " " + pagedQuery
        
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(queryString).all(decoding: RowOutput.self)
        } catch {
            throw error
        }
        let total = results.first?.total ?? 0
        let items: [GetTrackingByWarehousesOutput] = results.map {
            return GetTrackingByWarehousesOutput(
                id: $0.id,
                trackingNumber: $0.trackingNumber,
                receivedAtUSAt: $0.receivedAtUSAt,
                updatedAt: $0.updatedAt,
                warehouseID: $0.warehouseID,
                updatedBy: $0.updatedBy
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
    
    private func getReceivedAtUSPaginatedHandler(req: Request) async throws -> Page<GetReceivedAtUsTrackingItemsByDateOutput> {
        let input = try req.query.decode(GetTrackingItemQueryInput.self)
        let query = TrackingItem.query(on: req.db)
            .filter(\.$receivedAtUSAt != nil)
            .sort(\.$receivedAtUSAt, .descending)
            .filter(\.$agentCode == input.agentID.uppercased().trimmingCharacters(in: .whitespacesAndNewlines))
        
        if let searchStrings = input.searchStrings {
            query.filter(searchStrings: searchStrings, includeAlternativeRef: true)
        }
        
        if let fromDate = input.fromDate {
            query.filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
        }
        if let toDate = input.toDate {
            query.filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"), .lessThanOrEqual, .bind(toDate))
        }
        
        if let warehouseID = input.warehouseID {
            query.filter(\.$warehouse.$id == warehouseID)
        }
        
        let page = try await query
            .paginate(for: req)
        
        return .init(
            items: page.items.map { $0.toReceivedAtUSByDate() },
            metadata: page.metadata
        )
    }
    
    
    private func getReceivedAtUSItemsHandler(req: Request) async throws -> GetReceivedAtUSItemsOutput {
        let receivedAtUSItems = try await TrackingItem.query(on: req.db)
            .with(\.$customers)
            .filterReceivedAtUS()
            .all()
        
        return GetReceivedAtUSItemsOutput(items: receivedAtUSItems)
    }
    
    private func createHandler(request: Request) async throws -> TrackingItemOutput {
        try CreateTrackingItemInput.validate(content: request)
        let input = try request.content.decode(CreateTrackingItemInput.self)
        let user = try request.requireAuthUser()
        try await user.$warehouses.load(on: request.db)
        try await user.$agents.load(on: request.db)
        guard user.warehouses.first(where: { $0.id == input.warehouseID}) != nil else {
            throw AppError.permissionDenied
        }
        guard user.agents.first(where: { $0.id == input.agentCode}) != nil else {
            throw AppError.permissionDenied
        }
        guard input.trackingNumber.isValidTrackingNumber() else {
            throw AppError.invalidInput
        }
        var targetTracking = try await TrackingItem.query(on: request.db)
            .filter(\.$trackingNumber == input.trackingNumber)
            .first()
        if targetTracking == nil {
            let query = TrackingItem.query(on: request.db)
            query.filter(trackingNumbers: [input.trackingNumber])
            targetTracking = try await query.first()
        }
        if let targetTracking = targetTracking {
            if targetTracking.status == .registered {
                targetTracking.trackingNumber = input.trackingNumber
                targetTracking.agentCode = input.agentCode
                targetTracking.$warehouse.id = input.warehouseID
                if input.agentCode == nil {
                    if let payload = try await targetTracking.moveToStatus(to: .receivedAtUSWarehouse, database: request.db) {
                        try await request.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                    }
                } else {
                    if let payload = try await targetTracking.moveToStatus(to: .repacking, database: request.db) {
                        try await request.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                    }
                }
                try await targetTracking.save(on: request.db)
                try request.appendUserAction(.assignTrackingItemStatus(trackingNumber: targetTracking.trackingNumber, trackingItemID: targetTracking.requireID(), status: targetTracking.status))
                if let trackingReferencesInput = input.trackingReferences, targetTracking.isValidToAddTrackingReferences {
                    let existedTrackingReferences = try await TrackingItemReference.query(on: request.db)
                        .filter(trackingNumbers: trackingReferencesInput)
                        .all()
                    let existedTrackingReferenceNumbers = existedTrackingReferences.map { $0.trackingNumber }
                    var insertedTrackingReferenceNumber = trackingReferencesInput
                    existedTrackingReferenceNumbers.forEach { existedBarCode in
                        insertedTrackingReferenceNumber = insertedTrackingReferenceNumber.filter { $0.suffix(12) != existedBarCode.suffix(12) }
                    }
                    let trackingReferences = try insertedTrackingReferenceNumber.map { TrackingItemReference.init(trackingNumber: $0, trackingItemID: try targetTracking.requireID(), deletedAt: targetTracking.deletedAt)
                    }
                    try await trackingReferences.create(on: request.db)
                }
                return targetTracking.output()
            }
            else {
                throw AppError.trackingNumberAlreadyOnSystem
            }
        }
        else {
            //Add tracking item
            let trackingItem = try input.toTrackingItem()
            let label = try await Label.query(on: request.db)
                .filter(\.$simplifiedTrackingNumber == trackingItem.trackingNumber)
                .first()
            if let label = label {
                guard label.$agent.id == trackingItem.agentCode && label.$warehouse.id == trackingItem.$warehouse.id else {
                    throw AppError.agentCodeDoesntMatch
                }
            }
            if trackingItem.agentCode == nil {
                if let payload = try await trackingItem.moveToStatus(to: .receivedAtUSWarehouse, database: request.db) {
                    try await request.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                }
            } else {
                if let payload = try await trackingItem.moveToStatus(to: .repacking, database: request.db) {
                    try await request.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                }
            }
            try await request.db.transaction { transactionDB in
                try await trackingItem.save(on: transactionDB)
                let trackingItemID = try trackingItem.requireID()
                if let label = label {
                    label.$trackingItem.id = trackingItemID
                    try await label.save(on: transactionDB)
                }
                try request.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: trackingItem.status))
                let defaultPiece = TrackingItemPiece(
                    information: "default",
                    trackingItemID: trackingItemID)
                try await defaultPiece.save(on: transactionDB)
                try request.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: trackingItem.status))
                if trackingItem.agentCode != nil {
                    try request.appendUserAction(.assignTrackingItemAgentCode(trackingItemID: trackingItem.requireID(), agentCode: trackingItem.agentCode))
                }
                if let trackingReferencesInput = input.trackingReferences, trackingItem.isValidToAddTrackingReferences {
                    let existedTrackingReferences = try await TrackingItemReference.query(on: request.db)
                        .filter(trackingNumbers: trackingReferencesInput)
                        .all()
                    let existedTrackingReferenceNumbers = existedTrackingReferences.map { $0.trackingNumber }
                    var insertedTrackingReferenceNumber = trackingReferencesInput
                    existedTrackingReferenceNumbers.forEach { existedBarCode in
                        insertedTrackingReferenceNumber = insertedTrackingReferenceNumber.filter { $0.suffix(12) != existedBarCode.suffix(12) }
                    }
                    let trackingReferences = try insertedTrackingReferenceNumber.map { TrackingItemReference.init(trackingNumber: $0, trackingItemID: try trackingItem.requireID(), deletedAt: trackingItem.deletedAt)}
                    try await trackingReferences.create(on: transactionDB)
                }
            }
            try await trackingItem.$trackingItemReferences.load(on: request.db)
            return trackingItem.output()
        }
    }
    
    private func registerHandler(request: Request) async throws -> TrackingItemOutput {
        try CreateTrackingItemInput.validate(content: request)
        let input = try request.content.decode(CreateTrackingItemInput.self)
        let existingTrackingItem = try await TrackingItem.query(on: request.db)
            .filter(trackingNumbers: [input.trackingNumber])
            .first()
        
        guard existingTrackingItem == nil else {
            throw AppError.trackingNumberAlreadyOnSystem
        }
        
        let trackingItem = try input.toTrackingItem()
        
        if let payload = try await trackingItem.moveToStatus(to: .registered, database: request.db) {
            try await request.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
        }
        try await trackingItem.save(on: request.db)
        let defaultPiece = TrackingItemPiece(
            information: "default",
            trackingItemID: try trackingItem.requireID()
        )
        try await defaultPiece.save(on: request.db)
        try request.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: trackingItem.status))
        return trackingItem.output()
    }
    
    private func getProtractedItemsHandler(req: Request) async throws -> GetProtractedTrackingItemsOutput {
        let input = try req.query.decode(GetProtractedTrackingItemsInput.self)
        let protractDayLimit = 3.0
        let protractDate = Date().addingTimeInterval(.oneDay*(-protractDayLimit))
        let query = TrackingItem.query(on: req.db)
            .filterReceivedAtUS()
            .filter(\.$agentCode == input.agentID)
            .filter(\.$receivedAtUSAt <= protractDate)
            .sort(\.$receivedAtUSAt, .ascending)
        
        if let warehouseID = input.warehouseID {
            query.filter(\.$warehouse.$id == warehouseID)
        }
        
        let items = try await query.all()
        return GetProtractedTrackingItemsOutput(items: items)
    }
}

extension QueryBuilder where Model: TrackingItem {
    @discardableResult func filterRepacking() -> Self {
        return self.group(.and) { andBuilder in
            andBuilder.filter(\.$deliveredAt == nil)
            andBuilder.filter(\.$archivedAt == nil)
            andBuilder.filter(\.$packBoxCommitedAt == nil)
            andBuilder.filter(\.$packedAtVNAt == nil)
            andBuilder.filter(\.$receivedAtVNAt == nil)
            andBuilder.filter(\.$flyingBackAt == nil)
            andBuilder.filter(\.$boxedAt == nil)
            andBuilder.filter(\.$repackedAt == nil)
            andBuilder.filter(\.$repackingAt != nil)
        }
    }
    
    @discardableResult func filterBoxed() -> Self {
        return self.group(.and) { andBuilder in
            andBuilder.filter(\.$deliveredAt == nil)
            andBuilder.filter(\.$archivedAt == nil)
            andBuilder.filter(\.$packBoxCommitedAt == nil)
            andBuilder.filter(\.$packedAtVNAt == nil)
            andBuilder.filter(\.$receivedAtVNAt == nil)
            andBuilder.filter(\.$flyingBackAt == nil)
            andBuilder.filter(\.$boxedAt != nil)
        }
    }
    
    @discardableResult func filterRepacked() -> Self {
        return self.group(.and) { andBuilder in
            andBuilder.filter(\.$deliveredAt == nil)
            andBuilder.filter(\.$archivedAt == nil)
            andBuilder.filter(\.$packBoxCommitedAt == nil)
            andBuilder.filter(\.$packedAtVNAt == nil)
            andBuilder.filter(\.$receivedAtVNAt == nil)
            andBuilder.filter(\.$flyingBackAt == nil)
            andBuilder.filter(\.$boxedAt == nil)
            andBuilder.filter(\.$repackedAt != nil)
        }
    }
    
    @discardableResult func filterReceivedAtUS() -> Self {
        return self.group(.and) { andBuilder in
            andBuilder.filter(\.$packedAtVNAt == nil)
            andBuilder.filter(\.$deliveredAt == nil)
            andBuilder.filter(\.$archivedAt == nil)
            andBuilder.filter(\.$packBoxCommitedAt == nil)
            andBuilder.filter(\.$packedAtVNAt == nil)
            andBuilder.filter(\.$receivedAtVNAt == nil)
            andBuilder.filter(\.$flyingBackAt == nil)
            andBuilder.filter(\.$boxedAt == nil)
            andBuilder.filter(\.$repackedAt == nil)
            andBuilder.filter(\.$repackingAt == nil)
            andBuilder.filter(\.$receivedAtUSAt != nil)
        }
    }
    
    @discardableResult func filterRegistered() -> Self {
        return self.group(.and) { andBuilder  in
            andBuilder.filter(\.$registeredAt != nil)
            andBuilder.filter(\.$receivedAtUSAt == nil)
            andBuilder.filter(\.$repackingAt == nil)
        }
    }
    
    @discardableResult func filterDeli() -> Self {
        return self.group(.and) { andBuilder in
            andBuilder.filter(\.$deliveredAt == nil)
            andBuilder.filter(\.$archivedAt == nil)
            andBuilder.filter(\.$packBoxCommitedAt == nil)
            andBuilder.filter(\.$packedAtVNAt == nil)
            andBuilder.filter(\.$receivedAtVNAt == nil)
            andBuilder.filter(\.$flyingBackAt == nil)
            andBuilder.filter(\.$boxedAt == nil)
            andBuilder.filter(\.$repackedAt == nil)
            andBuilder.filter(\.$receivedAtUSAt != nil)
        }
    }
    
    @discardableResult func filter(
        searchStrings: [String],
        includeAlternativeRef: Bool
    ) -> Self {
        guard !searchStrings.isEmpty else {
            return self
        }
        
        return self.group(.or) { builder in
            builder.filter(agentCodes: searchStrings)
            builder.filter(trackingNumbers: searchStrings)
            if includeAlternativeRef {
                builder.filter(alternativeRefs: searchStrings)
            }
        }
    }
    
    @discardableResult func filter(trackingNumbers: [String]) -> Self {
        guard !trackingNumbers.isEmpty else {
            return self
        }
        
        let regexSuffixGroup = trackingNumbers.map {
            $0.suffix(12)
        }.joined(separator: "|")
        let fullRegex = "^.*(\(regexSuffixGroup))$"
        
        return self.group(.or) { builder in
            builder.filter(.sql(raw: "\(TrackingItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex))
            builder.group(.and) { andBuilder in
                let fullRegex2 = "^.*(\(regexSuffixGroup))\\d{4}$"
                andBuilder.filter(.sql(raw: "char_length(\(TrackingItem.schema).tracking_number)"), .equal, .bind(32))
                andBuilder.filter(.sql(raw: "\(TrackingItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex2))
            }
        }
    }
    
    @discardableResult func filter(alternativeRefs: [String]) -> Self {
        guard !alternativeRefs.isEmpty else {
            return self
        }
        
        let regexSuffixGroup = alternativeRefs.joined(separator: "|")
        let fullRegex = "^(\(regexSuffixGroup))$"
        
        return self.filter(.sql(raw: "\(TrackingItem.schema).alternative_ref"), .custom("~*"), .bind(fullRegex))
    }
    
    @discardableResult func filter(agentCodes: [String]) -> Self {
        guard !agentCodes.isEmpty else {
            return self
        }
        
        let regexSuffixGroup = agentCodes.joined(separator: "|")
        let agentCodeRegex = "^.*(\(regexSuffixGroup)).*"
        
        return self.filter(.sql(raw: "\(TrackingItem.schema).agent_code"), .custom("~*"), .bind(agentCodeRegex))
    }
    
    @discardableResult func filter(products: [String]) -> Self {
        guard !products.isEmpty else {
            return self
        }
        
        let regexSuffixGroup = products.joined(separator: "|")
        let productsRegex = "^.*(\(regexSuffixGroup)).*"
        
        return self.filter(.sql(raw: "\(Product.schema).description"), .custom("~*"), .bind(productsRegex))
    }
}
