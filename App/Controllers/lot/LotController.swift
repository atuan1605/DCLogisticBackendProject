import Vapor
import Fluent
import Foundation
import SQLKit

struct LotController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("lots")

        let protected = groupedRoutes
            .grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())

        let scopeRoutes = protected.grouped(ScopeCheckMiddleware(requiredScope: .shipmentList))

        scopeRoutes.get("list", use: getLotListHandler)
        scopeRoutes.get(use: getLotsHandler)
        scopeRoutes.post(use: createLotHandler)

        let paginateRoutes = scopeRoutes.grouped("paginated")
        paginateRoutes.get("list", use: getLotListPaginatedHandler)
        paginateRoutes.get(use: getPaginateLotsOutput)

        let lotRoutes = scopeRoutes
            .grouped(Lot.parameterPath)
            .grouped(LotIdentifyingMiddleWare())

        lotRoutes.get(use: getLotHandler)
        lotRoutes.get("details", use: getLotDetailsHandler)
        lotRoutes.get("returnItems", use: getReturnItemsHandler)
        lotRoutes.delete(use: deleteLotHandler)
        lotRoutes.patch(use: updateLotHandler)
        lotRoutes.get("totals", use: getBoxesTotalsHandler)
        lotRoutes.delete("removeReturnItem", TrackingItemPiece.parameterPath, use: removeReturnItemHandler)

        let boxesRoutes = lotRoutes.grouped("boxes")
        boxesRoutes.get(use: getBoxesHandler)
        boxesRoutes.post(use: createBoxHandler)

        let boxRoutes = boxesRoutes
                .grouped(Box.parameterPath)
                .grouped(BoxIdentifyingMiddleware())
        boxRoutes.get(use: getBoxDetailHandler)
        boxRoutes.delete(use: deleteBoxesHandler)
        boxRoutes.patch(use: updateBoxHandler)

        let trackingItemsRoute = boxRoutes.grouped("trackingItems")
        trackingItemsRoute.post(use: addTrackingItemToBoxHandler)
        trackingItemsRoute.post("changeBox", use: addTrackingItemToNewBoxHandler)
        trackingItemsRoute.delete(TrackingItemPiece.parameterPath, use: deleteTrackingItemHandler)

        let customItemsRoute = boxRoutes.grouped("customItems")
        customItemsRoute.post(use: addCustomItemToBoxHandler)
        customItemsRoute.delete(BoxCustomItem.parameterPath, use: deleteCustomItemFromBoxHandler)
    }

    private func removeReturnItemHandler(req: Request) async throws -> GetReturnItemOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let input = try req.content.decode(RemoveReturnItemFromBoxInput.self)
        guard
            let pieceID = req.parameters.get(TrackingItemPiece.parameter, as: TrackingItemPiece.IDValue.self),
            let piece = try await TrackingItemPiece.find(pieceID, on: req.db)
        else {
            throw AppError.trackingItemPieceNotFound
        }
        let trackingItem = try await piece.$trackingItem.get(on: req.db)
        try await trackingItem.$pieces.load(on: req.db)
        try await req.db.transaction({ database in
            if trackingItem.returnRequestAt != nil {
                try req.appendUserAction(.assignReturnItem(trackingItemID: trackingItem.requireID(), trackingNumber: trackingItem.trackingNumber, pieceID: pieceID, trackingItemPieceInfo: piece.information, boxID: input.boxID, boxName: input.boxName, status: input.status))
                _ = try await trackingItem.moveToStatus(to: .repacked, database: database)
                piece.$box.id = nil
                piece.boxedAt = nil
                try await piece.save(on: database)
                try await trackingItem.save(on: database)
            }
        })
        
        return GetReturnItemOutput(
            trackingItemID: trackingItem.id,
            trackingNumber: trackingItem.trackingNumber,
            pieceID: pieceID,
            trackingItemPieceInfo: piece.information,
            boxID: input.boxID,
            boxName: input.boxName,
            status: input.status
            )
    }
    
    private func getReturnItemsHandler(req: Request) async throws -> Page<GetReturnItemOutput> {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        let lot = try req.requireLot()
        let boxes = try await lot.$boxes.query(on: req.db)
            .with(\.$pieces) {
                $0.with(\.$trackingItem)
            }
            .all()
        
        let boxIDString = "'" + boxes.compactMap { $0.id?.uuidString }.joined(separator: "', '") + "'"
        
        let pageRequest = try req.query.decode(PageRequest.self)
        struct RowOutput: Content {
            var total: Int
            var trackingItemID: TrackingItem.IDValue
            var trackingNumber: String
            var pieceID: TrackingItemPiece.IDValue
            var trackingItemPieceInfo: String?
            var boxID: Box.IDValue?
            var boxName: String?
            var status: ReturnStatus?
        }
        let query: SQLQueryString = """
        WITH ranked_rows AS (
            SELECT
                (type->'assignReturnItem'->>'trackingNumber') AS \(ident: "trackingNumber"),
                (type->'assignReturnItem'->>'trackingItemID') AS \(ident: "trackingItemID"),
                (type->'assignReturnItem'->>'pieceID') AS \(ident: "pieceID"),
                (type->'assignReturnItem'->>'trackingItemPieceInfo') AS \(ident: "trackingItemPieceInfo"),
                (type->'assignReturnItem'->>'boxID') AS \(ident: "boxID"),
                (type->'assignReturnItem'->>'boxName') AS \(ident: "boxName"),
                (type->'assignReturnItem'->>'status') AS \(ident: "status"),
                created_at,
                ROW_NUMBER() OVER (PARTITION BY (type->'assignReturnItem'->>'boxID'), (type->'assignReturnItem'->>'pieceID') ORDER BY created_at DESC) AS row_num
            FROM \(ident: ActionLogger.schema)
            WHERE (type->>'assignReturnItem')::jsonb->>'boxID' IN (\(raw: boxIDString))
            UNION
            SELECT
                ti.tracking_number AS \(ident: "trackingNumber"),
                ti.id::text AS \(ident: "trackingItemID"),
                tip.id::text AS \(ident: "pieceID"),
                tip.information AS \(ident: "trackingItemPieceInfo"),
                tip.box_id::TEXT AS \(ident: "boxID"),
                b.name AS \(ident: "boxName"),
                NULL AS \(ident: "status"),
                NULL AS created_at,
                1 AS row_num
            FROM \(ident: TrackingItem.schema) as ti
            INNER JOIN \(ident: TrackingItemPiece.schema) tip ON tip.tracking_item_id = ti.id
            INNER JOIN \(ident: Box.schema) b ON tip.box_id = b.id
            WHERE tip.box_id IN (\(raw: boxIDString))
            AND (ti.deleted_at IS NULL or ti.deleted_at > now())
            AND ti.return_request_at IS NOT NULL
        )
        SELECT *,
        COUNT(*) OVER() AS total
        FROM ranked_rows
            WHERE row_num = 1
            limit \(bind: pageRequest.per)
            offset \(bind: pageRequest.per * (pageRequest.page - 1))
            
        """
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(query).all(decoding: RowOutput.self)
            print(results)
        } catch {
            print(String(reflecting: error))
            throw error
        }
        let total = results.first?.total ?? 0
        let items: [GetReturnItemOutput] = results.map {
            return GetReturnItemOutput(
                trackingItemID: $0.trackingItemID,
                trackingNumber: $0.trackingNumber,
                pieceID: $0.pieceID,
                trackingItemPieceInfo: $0.trackingItemPieceInfo,
                boxID: $0.boxID,
                boxName: $0.boxName,
                status: $0.status
            )
        }
        
        return Page(
            items: items,
            metadata: .init(
                page: pageRequest.page,
                per: pageRequest.per,
                total: total
            )
        )
    }
    private func getLotListHandler(req: Request) async throws -> [LotOutput] {
        let boxIDs = try await Box.query(on: req.db)
            .join(Shipment.self, on: \Shipment.$id == \Box.$shipment.$id, method: .left)
            .group(.or) { builder in
                builder.filter(Shipment.self, \.$commitedAt == nil)
                builder.filter(Box.self, \.$shipment.$id == nil)
            }
            .all(\.$id)

        let query = Lot.query(on: req.db)
            .with(\.$boxes) {
                $0.with(\.$pieces) {
                    $0.with(\.$trackingItem)
                }
                $0.with(\.$customItems)
            }
            .join(Box.self, on: \Box.$lot.$id == \Lot.$id, method: .left)
            .group(.or) { builder in
                builder.filter(Box.self, \.$id ~~ boxIDs)
                builder.filter(.sql(raw: "\(Box.schema).id IS NULL"))
            }
            .unique()
            .fields(for: Lot.self)

        if let searchString = try? req.query.get(String.self, at: "q") {
            query.filter(.sql(raw: "\(Lot.schema).lot_index"),
                         .custom("ILIKE"),
                         .bind("%\(searchString)%"))
        }
        let lots = try await query.all()

        return lots.map {
            .init(
                id: $0.id,
                lotIndex: $0.lotIndex,
                boxesCount: nil,
                trackingItemsCount: nil,
                boxes: nil,
                totalWeight: nil)
        }
    }

    private func getLotListPaginatedHandler(req: Request) async throws -> Page<GetLotPaginatedOnWebOutput> {
        let boxIDs = try await Box.query(on: req.db)
            .join(Shipment.self, on: \Shipment.$id == \Box.$shipment.$id, method: .left)
            .group(.or) { builder in
                builder.filter(Shipment.self, \.$commitedAt == nil)
                builder.filter(Box.self, \.$shipment.$id == nil)
            }
            .all(\.$id)

        let query = Lot.query(on: req.db)
            .with(\.$boxes)
            .join(Box.self, on: \Box.$lot.$id == \Lot.$id, method: .left)
            .group(.or) { builder in
                builder.filter(Box.self, \.$id ~~ boxIDs)
                builder.filter(.sql(raw: "\(Box.schema).id IS NULL"))
            }
            .unique()
            .fields(for: Lot.self)
        
        if let searchString = try? req.query.get(String.self, at: "lotIndex") {
            query.filter(.sql(raw: "\(Lot.schema).lot_index"),
                         .custom("ILIKE"),
                         .bind("%\(searchString)%"))
        }

        let page = try await query.sort(\.$createdAt, .descending).paginate(for: req)
        return .init(
            items: page.items.map { $0.toPaginateOutput() },
            metadata: page.metadata)
    }

    private func getPaginateLotsOutput(req: Request) async throws -> Page<PaginateLotOutput> {
        let input = try req.query.decode(GetLotQueryInput.self)
        var query = TrackingItem.query(on: req.db)
            .filter(\.$flyingBackAt == nil)
            .filter(\.$boxedAt != nil)
            .with(\.$products)
            .with(\.$box) {
                $0.with(\.$lot)
            }
            .sort(\.$boxedAt, .descending)

        if let lotIDs = input.lotIDs {
            query = query
                .join(Box.self, on: \Box.$id == \TrackingItem.$box.$id)
                .join(Lot.self, on: \Box.$lot.$id == \Lot.$id)
                .filter(Lot.self, \.$id ~~ lotIDs.compactMap { UUID(uuidString: $0) })
        }

        if let agentID = input.agentID {
            query = query.filter(\.$agentCode == agentID)
        }

        if let fromDate = input.fromDate {
            query = query.filter(.sql(raw: "\(TrackingItem.schema).boxed_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
        }
        if let toDate = input.toDate {
            query = query.filter(.sql(raw: "\(TrackingItem.schema).boxed_at::DATE"), .lessThanOrEqual, .bind(toDate))
        }

        let page = try await query
            .paginate(for: req)
        let items = try await page.items.asyncMap({
            return try await $0.toPaginateLotOutput(db: req.db)
        })
        return .init(items: items, metadata: page.metadata)
    }

    private func getLotsHandler(req: Request) async throws -> [LotListOutput] {
        let boxIDs = try await Box.query(on: req.db)
            .join(Shipment.self, on: \Shipment.$id == \Box.$shipment.$id, method: .left)
            .group(.or) { builder in
                builder.filter(Shipment.self, \.$commitedAt == nil)
                builder.filter(Box.self, \.$shipment.$id == nil)
            }
            .all(\.$id)

        let lots = try await Lot.query(on: req.db)
            .with(\.$boxes) {
                $0.with(\.$pieces)
                $0.with(\.$customItems)
            }
            .join(Box.self, on: \Box.$lot.$id == \Lot.$id, method: .left)
            .group(.or) { builder in
                builder.filter(Box.self, \.$id ~~ boxIDs)
                builder.filter(.sql(raw: "\(Box.schema).id IS NULL"))
            }
            .unique()
            .fields(for: Lot.self)
            .sort(\.$createdAt, .descending)
            .all()

        return lots.map {
            $0.toListOutput()
        }
    }

    private func createLotHandler(req: Request) async throws -> LotListOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        try CreateLotInput.validate(content: req)
        let input = try req.content.decode(CreateLotInput.self)
        let newLot = input.toLot()

        try await newLot.save(on: req.db)
        try await newLot.$boxes.load(on: req.db)
        try req.appendUserAction(.createLot(lotID: newLot.requireID()))
        return newLot.toListOutput()
    }

    private func getLotHandler(req: Request) async throws -> LotOutput {
        let lot = try req.requireLot()
        lot.$boxes.value = try await lot.$boxes.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .with(\.$pieces) {
                $0.with(\.$trackingItem)
            }
            .with(\.$customItems)
            .all()
        return try await lot.output(on: req.db)
    }

    private func getLotDetailsHandler(req: Request) async throws -> GetLotPaginatedOnWebOutput {
        let lot = try req.requireLot()
        lot.$boxes.value = try await lot.$boxes.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .with(\.$pieces) {
                $0.with(\.$trackingItem)
            }
            .with(\.$customItems)
            .all()
        return try await lot.getBoxesOutput()
    }

    private func deleteLotHandler(req: Request) async throws -> HTTPResponseStatus {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let lot = try req.requireLot()
        let lotID = try lot.requireID()

        let boxes = try await Box.query(on: req.db)
            .filter(\.$lot.$id == lotID)
            .all()
        let boxIDs = try boxes.map { try $0.requireID() }
        guard boxes.allSatisfy ({ $0.$shipment.id == nil }) else {
            throw AppError.boxWasInShipment
        }
        try await req.db.transaction{ db in
            let trackingItemIDs = try await TrackingItem.query(on: db)
                .join(TrackingItemPiece.self, on: \TrackingItemPiece.$trackingItem.$id == \TrackingItem.$id)
                .filter(TrackingItemPiece.self, \.$box.$id ~~ boxIDs)
                .all(\.$id)
            
            try await TrackingItem.query(on: db)
                .filter(\.$id ~~ trackingItemIDs)
                .set(\.$boxedAt, to: nil)
                .update()
            
            try await TrackingItemPiece.query(on: db)
                .filter(\.$box.$id ~~ boxIDs)
                .set(\.$boxedAt, to: nil)
                .set(\.$box.$id, to: nil)
                .update()
    
            try await boxes.asyncForEach {
                try await $0.delete(on: db)
            }
            try await lot.delete(on: db)
            req.appendUserAction(.deleteLot(lotID: lotID))
        }
        return .ok
    }

    private func updateLotHandler(req: Request) async throws -> LotListOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let lot = try req.requireLot()
        try UpdateLotInput.validate(content: req)
        let input = try req.content.decode(UpdateLotInput.self)

        lot.lotIndex = input.lotIndex
        if lot.hasChanges {
            try await lot.save(on: req.db)
        }
        try await lot.$boxes.load(on: req.db)
        return lot.toListOutput()
    }

    private func getBoxesHandler(req: Request) async throws -> GetBoxesOutput {
        let lot = try req.requireLot()

        let boxes = try await lot.$boxes.get(on: req.db)
        return try await GetBoxesOutput.init(name: lot.lotIndex, items: boxes, on: req.db)
    }

    private func createBoxHandler(req: Request) async throws -> BoxesListOutput {
        let lot = try req.requireLot()
        let lotID = try lot.requireID()

        let boxCount = try await lot.$boxes.get(on: req.db).count
        let newBox = Box(
            name: "\(boxCount + 1)",
            weight: nil,
            lotID: lotID
        )
        try await newBox.save(on: req.db)
        try req.appendUserAction(.createBox(boxID: newBox.requireID()))
        return try await newBox.toUncommitedOutput(on: req.db)
    }

    private func getBoxesTotalsHandler(req: Request) async throws -> GetBoxedTotalsOutput {
        let lot = try req.requireLot()
        let lotID = try lot.requireID()

        let boxesID = try await Box.query(on: req.db)
            .filter(\.$lot.$id == lotID)
            .all(\.$id)
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$box.$id ~~ boxesID)
            .all()
        return try GetBoxedTotalsOutput(items: trackingItems)
    }

//    private func getUnboxedTotalsHandler(req: Request) async throws -> [String: Int] {
//        let lot = try req.requireLot()
//
//        let boxes = try await lot.$boxes.get(on: req.db)
//        return try await boxes.asyncReduce([:]) { carry, next in
//            let boxID = try next.requireID()
//            let trackingIDs = try await TrackingItemCustomer.query(on: req.db)
//                .field(\.$trackingItem.$id)
//                .unique()
//                .all(\.$trackingItem.$id)
//            let trackingItems = try await next.$trackingItems.query(on: req.db)
//                .filter(\.$agentCode != nil)
//                .filter(\.$agentCode != "")
//                .filter(\.$id ~~ trackingIDs)
//                .with(\.$products)
//                .all()
//
//            let trackingItemsWithProducts = trackingItems.filter { !$0.products.description.isEmpty }
//            var newCarry = carry
//            newCarry[boxID.uuidString] = trackingItemsWithProducts.count
//            return newCarry
//        }
//    }

    private func getBoxDetailHandler(request: Request) async throws -> BoxOutput {
        let box = try request.requireBox()
        try await box.$customItems.load(on: request.db)
        try await box.$lot.load(on: request.db)
        let pieces = try await box.$pieces.query(on: request.db)
            .with(\.$trackingItem) {
                $0.with(\.$products)
            }
            .all()
        let chains = pieces.map { $0.trackingItem }.compactMap { $0.chain }
        let chainTrackingItems = try await TrackingItem.query(on: request.db)
            .filter(\.$chain ~~ chains)
            .all()
        let groupedChain = try chainTrackingItems.grouped { $0.chain }
        box.$pieces.value = pieces
        
        return try await box.toOutput(groupedChain: groupedChain, on: request.db)
    }

    private func updateBoxHandler(request: Request) async throws -> BoxOutput {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let input = try request.content.decode(UpdateBoxInput.self)

        let box = try request.requireBox()
        let boxID = try box.requireID()
        let itemsAgentCodes = try await TrackingItem.query(on: request.db)
            .filter(\.$box.$id == boxID)
            .all(\.$agentCode)

        let validItemAgentCodes = itemsAgentCodes.compactMap { $0 }
        if let inputAgentCodes = input.agentCodes {
            guard validItemAgentCodes.allSatisfy( {inputAgentCodes.contains( $0 )} ) else {
                throw AppError.itemCantBeChange
            }
        }

        if let agentCodes = input.agentCodes, agentCodes != box.agentCodes {
            box.agentCodes = agentCodes
            request.appendUserAction(.assignBoxAgentCodes(boxID: boxID, agentCodes: agentCodes))
        }
        if let weight = input.weight, weight != box.weight {
            box.weight = weight
            request.appendUserAction(.assignBoxWeight(boxID: boxID, weight: weight))
        }
        if let name = input.name, name != box.name, name != "" {
            box.name = name
            request.appendUserAction(.assignBoxName(boxID: boxID, name: name))
        }

        if box.hasChanges {
            try await box.save(on: request.db)
        }
        try await box.$customItems.load(on: request.db)
        try await box.$lot.load(on: request.db)
        let pieces = try await box.$pieces.query(on: request.db)
            .with(\.$trackingItem) {
                $0.with(\.$products)
            }
            .all()
        let chains = pieces.map { $0.trackingItem }.compactMap { $0.chain }
        let chainTrackingItems = try await TrackingItem.query(on: request.db)
            .filter(\.$chain ~~ chains)
            .all()
        let groupedChain = try chainTrackingItems.grouped { $0.chain }
        box.$pieces.value = pieces
        return try await box.toOutput(groupedChain: groupedChain, on: request.db)
    }

    private func addTrackingItemToBoxHandler(request: Request) async throws -> [TrackingItemPieceInBoxOutput] {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let input = try request.content.decode(AddTrackingItemToBoxInput.self)
        let box = try request.requireBox()
        let boxID = try box.requireID()
        
        guard let trackingItem = try await TrackingItem.query(on: request.db)
            .filter(\.$id == input.trackingItemID)
            .first()
        else {
            throw AppError.trackingItemNotFound
        }
        if trackingItem.brokenProduct.customerFeedback == .returnProduct {
            throw AppError.trackingItemNotAllowedToScan
        }

        if let agentCode = trackingItem.agentCode {
            guard ((box.agentCodes?.contains( agentCode )) == true) else {
                throw AppError.agentCodeDoesntMatch
            }
        }

        let updatedTrackingItems = try await request.db.transaction { db in
            var targetTrackingItems = [trackingItem]
            let trackingItemPieces = try await TrackingItemPiece.query(on: db)
                .filter(\.$trackingItem.$id == trackingItem.requireID())
                .filter(\.$boxedAt == nil)
                .all()
            if trackingItemPieces.count == 1 {
                if let chain = trackingItem.chain {
                    targetTrackingItems = try await TrackingItem.query(on: db)
                        .filter(\.$chain == chain)
                        .all()
                } else {
                    trackingItem.chain = UUID().uuidString
                    try request.appendUserAction(.assignChain(trackingItemID: trackingItem.requireID(), chain: trackingItem.chain))
                }
                
                try await targetTrackingItems.asyncForEach { item in
                    
                    if let payload = try await item.moveToStatus(to: .boxed, database: db) {
                        try await request.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                    }
                    try await item.save(on: db)
                    guard let trackingItemPiece = try await item.$pieces.query(on: db)
                        .filter(\.$boxedAt == nil)
                        .first()
                    else {
                        throw AppError.trackingItemPieceNotFound
                    }
                    trackingItemPiece.$box.id = boxID
                    let now = Date()
                    trackingItemPiece.boxedAt = now
                    try request.appendUserAction(.assignBox(trackingItemID: item.requireID(), pieceID: trackingItemPiece.requireID(), boxID: boxID.uuidString))
                    try request.appendUserAction(.assignTrackingItemStatus(trackingNumber: item.trackingNumber, trackingItemID: item.requireID(), status: .boxed))
                    try await trackingItemPiece.save(on: db)
                }
            } else {
                guard let pieceID = input.trackingItemPieceID else {
                    throw AppError.invalidInput
                }
                trackingItem.chain = UUID().uuidString
                guard let trackingItemPiece = try await TrackingItemPiece.query(on: db)
                    .filter(\.$id == pieceID)
                    .with(\.$box)
                    .first()
                else {
                    throw AppError.trackingItemPieceNotFound
                }
                guard trackingItemPiece.$box.id == nil else {
                    throw AppError.trackingAlreadyInBox
                }
                trackingItemPiece.$box.id = boxID
                let now = Date()
                trackingItemPiece.boxedAt = now
                try await trackingItem.save(on: db)
                try await trackingItemPiece.save(on: db)
                try request.appendUserAction(.addTrackingItemPieceToBox(pieceID: trackingItemPiece.requireID(), boxID: boxID))
            }
            return targetTrackingItems
        }
        var targetPieces: [TrackingItemPiece] = []
        try await updatedTrackingItems.asyncForEach { tracking in
            let pieces = try await tracking.$pieces.get(on: request.db)
            if pieces.count > 1 {
                let targetPiece =  pieces.filter {
                    $0.id == input.trackingItemPieceID
                }
                targetPieces.append(contentsOf: targetPiece)
                if input.trackingItemPieceID == nil {
                    let sortedPieces = pieces.sorted(by: { lhs, rhs in
                        return lhs.boxedAt ?? Date() > rhs.boxedAt ?? Date()
                    })
                    if let firstItem = sortedPieces.first {
                        targetPieces.append(firstItem)
                    }
                }
            } else {
                targetPieces.append(contentsOf: pieces)
            }
        }
        return try await targetPieces.asyncMap{
            try await $0.toOutput(on: request.db)
        }
    }

    private func deleteBoxesHandler(request: Request) async throws -> HTTPResponseStatus {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let box = try request.requireBox()
        guard box.$shipment.id == nil else {
            throw AppError.boxWasInShipment
        }
        try await request.db.transaction { transaction in
			let trackingItemIDs = try await TrackingItem.query(on: transaction)
				.join(TrackingItemPiece.self, on: \TrackingItemPiece.$trackingItem.$id == \TrackingItem.$id)
				.filter(TrackingItemPiece.self, \.$box.$id == box.requireID())
				.all(\.$id)
			
            try await TrackingItem.query(on: transaction)
				.filter(\.$id ~~ trackingItemIDs)
                .set(\.$boxedAt, to: nil)
                .update()

            try await TrackingItemPiece.query(on: transaction)
                .filter(\.$box.$id == box.requireID())
                .set(\.$boxedAt, to: nil)
                .set(\.$box.$id, to: nil)
                .update()
            
            try request.appendUserAction(.deleteBox(boxID: box.requireID()))
            try await box.delete(on: transaction)
        }
        return .ok
    }

    private func deleteTrackingItemHandler(request: Request) async throws -> RemoveTrackingItemPiecesInBoxOutput {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let box = try request.requireBox()

        guard
            let pieceID = request.parameters.get(TrackingItemPiece.parameter, as: TrackingItemPiece.IDValue.self),
            let piece = try await TrackingItemPiece.find(pieceID, on: request.db)
        else {
            throw AppError.trackingItemPieceNotFound
        }
        let trackingItem = try await piece.$trackingItem.get(on: request.db)
		let trackingItemPieces = try await trackingItem.$pieces.get(on: request.db)
		
		let pieceIDs = try await request.db.transaction({ database in
			var pieces: [TrackingItemPiece] = []
			if trackingItemPieces.count > 1 {
				pieces.append(piece)
			} else {
				let chainedTrackingItems = try await TrackingItem.query(on: database)
					.filter(\.$chain == trackingItem.chain)
					.with(\.$pieces)
					.all()
				let allChainedPieces = chainedTrackingItems.map(\.pieces).flatMap { $0 }
				guard chainedTrackingItems.count == allChainedPieces.count else {
					throw AppError.invalidInput
				}
				pieces.append(contentsOf: allChainedPieces)
			}
			
			try await pieces.asyncForEach({ piece in
				let trackingItem = try await piece.$trackingItem.get(on: database)
				try request.appendUserAction(.assignBox(trackingItemID: piece.trackingItem.requireID(), pieceID: piece.requireID(), boxID: nil))
				piece.$box.id = nil
				piece.boxedAt = nil
				try await piece.save(on: database)
				if trackingItem.status != .repacked, trackingItem.status.power < TrackingItem.Status.flyingBack.power {
                    try request.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItem.requireID(), status: .repacked))
					_ = try await trackingItem.moveToStatus(to: .repacked, database: database)
					try await trackingItem.save(on: database)
				}
			})
			return pieces.compactMap(\.id)
		})
		
        let remainPiecesInBox = try await box.$pieces.query(on: request.db)
            .with(\.$trackingItem)
			.all()
		let trackingItemCount = remainPiecesInBox.map(\.trackingItem.id).removingDuplicates().count
		let customItemCount = try await box.$customItems.query(on: request.db).count()
        return try await .init(pieceIDs: pieceIDs, count: trackingItemCount + customItemCount, on: request.db)
    }

    private func addCustomItemToBoxHandler(request: Request) async throws -> BoxCustomItemOutput {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }

        let box = try request.requireBox()

        try CreateBoxCustomItemInput.validate(content: request)
        let input = try request.content.decode(CreateBoxCustomItemInput.self)

        let item = try BoxCustomItem(boxID: box.requireID(), reference: input.reference, details: input.details)
        try await item.save(on: request.db)

        try request.appendUserAction(.addCustomItemToBox(
            boxID: box.requireID(),
            customItemID: item.requireID(),
            customItemDetails: item.details,
            reference: item.reference
        ))

        return item.output()
    }

    private func deleteCustomItemFromBoxHandler(request: Request) async throws -> HTTPResponseStatus {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }

        let box = try request.requireBox()

        guard
            let customItemID = request.parameters.get(BoxCustomItem.parameter, as: BoxCustomItem.IDValue.self),
            let customItem = try await BoxCustomItem.find(customItemID, on: request.db)
        else {
            throw AppError.boxCustomItemNotFound
        }

        try await customItem.delete(on: request.db)
        try request.appendUserAction(.removeCustomItemFromBox(boxID: box.requireID(), customItemDetails: customItem.details, reference: customItem.reference))
        return .ok
    }
    
    private func addTrackingItemToNewBoxHandler(req: Request) async throws -> MoveTrackingToNewBoxOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let input = try req.content.decode(AddTrackingItemsToNewBoxInput.self)
        let box = try req.requireBox()
        let boxID = try box.requireID()
        guard let newBox = try await Box.find(input.boxID, on: req.db)
        else {
            throw AppError.boxNotFound
        }
        let updatedItems = try await req.db.transaction { db in
            var targetItems: [TrackingItemPiece] = []
            let trackingItems = try await TrackingItem.query(on: db)
                .join(TrackingItemPiece.self, on: \TrackingItemPiece.$trackingItem.$id == \TrackingItem.$id)
                .filter(TrackingItemPiece.self, \.$id ~~ input.trackingPieceIDs)
                .unique()
                .fields(for: TrackingItem.self)
                .all()
            try await trackingItems.asyncForEach {
                if let agentCode = $0.agentCode {
                    guard ((newBox.agentCodes?.contains( agentCode )) == true) else {
                        throw AppError.agentCodeDoesntMatch
                    }
                }
            }
            let chains =  trackingItems.map{ $0.chain }
            let chainItems = try await TrackingItem.query(on: db)
                .filter(\.$chain ~~ chains)
                .with(\.$pieces)
                .all()
            try await chainItems.asyncForEach { item in
                if item.pieces.count <= 1 {
                    guard let trackingItemPiece = try await item.$pieces.query(on: db)
                        .filter(\.$boxedAt != nil)
                        .first()
                    else {
                        throw AppError.trackingItemPieceNotFound
                    }
                    trackingItemPiece.$box.id = try newBox.requireID()
                    try await trackingItemPiece.save(on: db)
                    try req.appendUserAction(.addTrackingItemPieceToBox(pieceID: trackingItemPiece.requireID(), boxID: boxID))
                    targetItems.append(trackingItemPiece)
                } else {
                    let trackingItemPieces = try await item.$pieces.query(on: db)
                        .filter(\.$id ~~ input.trackingPieceIDs)
                        .filter(\.$boxedAt != nil)
                        .all()
                    try await trackingItemPieces.asyncForEach {
                        $0.$box.id = try newBox.requireID()
                        try await $0.save(on: db)
                        try req.appendUserAction(.addTrackingItemPieceToBox(pieceID: $0.requireID(), boxID: boxID))
                    }
                    targetItems.append(contentsOf: trackingItemPieces)
                }
            }
            return targetItems
        }
        let newBoxPieces = try await TrackingItemPiece.query(on: req.db)
            .filter(\.$box.$id == newBox.requireID())
            .with(\.$trackingItem)
            .all()
        let newBoxCount = try newBoxPieces.compactMap{ $0.trackingItem }.removingDuplicates{ $0.id }.count
        let pieces = try await TrackingItemPiece.query(on: req.db)
            .filter(\.$box.$id == box.requireID())
            .with(\.$trackingItem)
            .all()
        let boxCount = try pieces.compactMap{ $0.trackingItem }.removingDuplicates{ $0.id }.count
        return try await .init(oldBoxCount: boxCount, newBoxCount: newBoxCount, items: updatedItems, on: req.db)
    }
}
