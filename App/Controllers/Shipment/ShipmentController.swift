import Vapor
import Foundation
import Fluent
import CSV

struct BoxExport: Content {
    var trackingNumber: String
    var product: String
    var customerCode: String
}

struct ShipmentController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("shipments")
        
        let protected = groupedRoutes
            .grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())
        
        let scopeRoute = protected .grouped(ScopeCheckMiddleware(requiredScope: [.shipmentList]))
        
        try registerCommitedRoutes(routes: scopeRoute)
        
        scopeRoute.get("list", use: getShipmentListHandler)
        scopeRoute.grouped("paginated").get("list", use: getShipmentListPaginatedHandler)
        scopeRoute.grouped("paginated").get(use: getPaginateShipmentsHandler)
        scopeRoute.get(use: getShipmentsHandler)
        scopeRoute.post(use: createShipmentHandler)

        let shipmentRoutes = scopeRoute
            .grouped(Shipment.parameterPath)
            .grouped(ShipmentIdentifyingMiddleware())
        
        shipmentRoutes.get(use: getShipmentHandler)
        shipmentRoutes.get("details", use: getShipmentDetailsHandler)
        shipmentRoutes.delete(use: deleteShipmentHandler)
        shipmentRoutes.patch(use: updateShipmentHandler)
        shipmentRoutes.put("commit", use: commitShipmentHandler)
        shipmentRoutes.get("boxes", use: getBoxesHandler)
        shipmentRoutes.get("boxes", "unboxedTotals", use: getUnboxedTotalsHandler)
        shipmentRoutes.post("boxes", use: addBoxToShipmentHandler)
        shipmentRoutes.get("totals", use: getBoxesTotalsHandler)
        
        let boxesRoutes = shipmentRoutes
            .grouped("boxes")
            .grouped(Box.parameterPath)
            .grouped(BoxIdentifyingMiddleware())

        boxesRoutes.get("csv", use: getBoxCSVExportHandler)
        boxesRoutes.get(use: getBoxDetailHandler)
        boxesRoutes.delete(use: removeBoxesHandler)
    }

    private func getUnboxedTotalsHandler(request: Request) async throws -> [String: Int] {
        let shipment = try request.requireShipment()

        let boxes = try await shipment.$boxes.get(on: request.db)
        return try await boxes.asyncReduce([:]) { carry, next in
            let boxID = try next.requireID()
            let pieces = try await next.$pieces.query(on: request.db)
                .filter(\.$receivedAtVNAt != nil)
                .with(\.$trackingItem)
                .all()
            let trackingItems = try pieces.map{ $0.trackingItem }.removingDuplicates{ $0.id }

            var newCarry = carry
            newCarry[boxID.uuidString] = trackingItems.count
            return newCarry
        }
    }

    private func getShipmentListHandler(request: Request) async throws -> [ShipmentOutput] {
        
        let query = Shipment.query(on: request.db)
            .sort(\.$commitedAt, .descending)
            .sort(\.$createdAt, .descending)
        
        if let searchString = try? request.query.get(String.self, at: "q") {
            query.filter(.sql(raw: "\(Shipment.schema).shipment_code"), .custom("ILIKE"), .bind("%\(searchString)%"))
        }
        
        let shipments = try await query
            .all()

        return shipments.map {
            .init(
                id: $0.id,
                shipmentCode: $0.shipmentCode,
                commitedAt: $0.commitedAt,
                boxesCount: nil,
                trackingitemsCount: nil,
                boxes: nil,
                totalWeight: nil
            )
        }
    }

    private func getBoxCSVExportHandler(request: Request) async throws -> ClientResponse {
        let shipment = try request.requireShipment()
        let box = try request.requireBox()
        let pieces = try await box.$pieces.query(on: request.db)
            .with(\.$trackingItem)
            .all()
        let trackingItems = try pieces.map {
            $0.trackingItem
        }.removingDuplicates { item in
            item.id
        }

        let rows = try await trackingItems.asyncMap { item in
            let products = try await item.$products.get(on: request.db)
            let customerCodes = try await item.$customers.query(on: request.db).all(\.$customerCode)
            return BoxExport(
                trackingNumber: item.trackingNumber,
                product: products.map({
                    return "\($0.quantity) \($0.description)"
                }).joined(separator: ", "),
                customerCode: customerCodes.joined(separator: ", "))
        }
        let document = try CSVEncoder().sync.encode(rows)
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "text/csv")
        let now = Date()
        headers.add(name: .contentDisposition, value: "attachment; filename=\(shipment.shipmentCode)-\(box.name)-\(now.toISODate()).csv")
        let response = ClientResponse(status: .ok,
                                      headers: headers,
                                      body: ByteBuffer(data: document))
        return response
    }

    private func getShipmentHandler(request: Request) async throws -> ShipmentOutput {
        let shipment = try request.requireShipment()
        try await shipment.$boxes.load(on: request.db)
        
        let boxes = shipment.boxes
        try await boxes.asyncForEach {
            $0.$pieces.value = try await $0.$pieces.query(on: request.db).with(\.$trackingItem).all()
        }

        return try await shipment.processingOutput()
    }
    
    //api/v1/shipments
    private func getShipmentsHandler(request: Request) async throws -> [ShipmentUncommitedOutput] {
        let shipments = try await Shipment.query(on: request.db)
            .filter(\.$commitedAt == nil)
            .with(\.$boxes)
            .sort(\.$createdAt, .descending)
            .all()

        return shipments.map{
            $0.toUncommitedOutput()
        }
    }
    
    //api/v1/shipments/shipment_id/totals
    private func getBoxesTotalsHandler(request: Request) async throws -> GetBoxedTotalsOutput {
        let shipment = try request.requireShipment()
        let shipmentID = try shipment.requireID()
        let boxesID = try await Box.query(on: request.db)
            .filter(\.$shipment.$id == shipmentID)
            .all(\.$id)
        let trackingItems = try await TrackingItem.query(on: request.db)
            .filter(\.$box.$id ~~ boxesID)
            .all()
        return try GetBoxedTotalsOutput(items: trackingItems)
    }
    
    //api/v1/shipments (delete)
    private func deleteShipmentHandler(request: Request) async throws -> HTTPResponseStatus {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .shipments) else {
            throw AppError.invalidScope
        }
        let shipment = try request.requireUncommitedShipment()
        
        let shipmentID = try shipment.requireID()
        try await request.db.transaction { transaction in
            let boxIDs = try await Box.query(on: transaction)
                .filter(\.$shipment.$id == shipmentID)
                .all(\.$id)
            let trackingItemIDs = try await TrackingItem.query(on: transaction)
                .join(TrackingItemPiece.self, on: \TrackingItemPiece.$trackingItem.$id == \TrackingItem.$id)
                .filter(TrackingItemPiece.self, \.$box.$id ~~ boxIDs)
                .all(\.$id)
            
            try await TrackingItem.query(on: transaction)
                .filter(\.$id ~~ trackingItemIDs)
                .set(\.$flyingBackAt, to: nil)
                .update()
            
            try await TrackingItemPiece.query(on: transaction)
                .filter(\.$box.$id ~~ boxIDs)
                .set(\.$flyingBackAt, to: nil)
                .update()
            try await Box.query(on: transaction)
                .filter(\.$id ~~ boxIDs)
                .set(\.$shipment.$id, to: nil)
                .update()
        }
        return .ok
    }
    
    //api/v1/shipments (post)
    private func createShipmentHandler(request: Request) async throws -> ShipmentUncommitedOutput {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .shipments) else {
            throw AppError.invalidScope
        }
        try CreateShipmentInput.validate(content: request)
        let input = try request.content.decode(CreateShipmentInput.self)
        let newShipment = input.toShipment()
        
        try await newShipment.save(on: request.db)
        try request.appendUserAction(.createShipment(shipmentID: newShipment.requireID()))
        return newShipment.toUncommitedOutput()
    }
    
    //api/v1/shipments (patch)
    private func updateShipmentHandler(request: Request) async throws -> ShipmentUncommitedOutput {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .shipments) else {
            throw AppError.invalidScope
        }
        let shipment = try request.requireUncommitedShipment()
        try UpdateShipmentInput.validate(content: request)
        let input = try request.content.decode(UpdateShipmentInput.self)
        
        shipment.shipmentCode = input.shipmentCode
        if shipment.hasChanges {
            try await shipment.save(on: request.db)
        }
        try await shipment.$boxes.load(on: request.db)
        return shipment.toUncommitedOutput()
    }
    
    //api/v1/shipments/shipment_id/boxes (get)
    private func getBoxesHandler(request: Request) async throws -> GetBoxesOutput {
        let shipment = try request.requireShipment()
        
        let boxes = try await shipment.$boxes.get(on: request.db)
        return try await GetBoxesOutput.init(name: shipment.shipmentCode, items: boxes, on: request.db)
    }

    //api/v1/shipments/shipment_id/commit
    private func commitShipmentHandler(request: Request) async throws -> ShipmentUncommitedOutput {
        let user = try request.requireAuthUser()
        
        guard user.hasRequiredScope(for: .shipments) else {
            throw AppError.invalidScope
        }
        let shipment = try request.requireUncommitedShipment()
        let shipmentID = try shipment.requireID()
        let boxIDs = try await Box.query(on: request.db)
            .filter(\.$shipment.$id == shipmentID)
            .all(\.$id)
        let trackingItemPieces = try await TrackingItemPiece.query(on: request.db)
            .filter(\.$box.$id ~~ boxIDs)
            .with(\.$trackingItem)
            .all()
		
		let dict = try trackingItemPieces.grouped(by: \.$trackingItem.id.uuidString)
		        
        guard !trackingItemPieces.isEmpty else {
            throw AppError.shipmentIsEmpty
        }
        
        try await request.db.transaction { db in
			let trackingItems = try trackingItemPieces.map {
                $0.trackingItem
			}.removingDuplicates { $0.id }
			
			
            let today = Date()
            shipment.commitedAt = today
            try request.appendUserAction(.commitShipment(shipmentID: shipment.requireID()))
            
            try await shipment.save(on: db)

			try await trackingItems.asyncForEach { trackingItem in
				let trackingItemID = try trackingItem.requireID()
				guard let pieces = dict[trackingItemID.uuidString] else {
					throw AppError.trackingItemPieceNotFound
				}
				try await pieces.asyncForEach {
					$0.flyingBackAt = today
					try await $0.save(on: db)
				}

                let piecesCount = try await trackingItem.$pieces.query(on: db)
                    .group(.or) { orBuilder in
                        orBuilder.filter(\.$flyingBackAt == nil)
                        orBuilder.filter(\.$boxedAt == nil)
                    }
                .count()

                if piecesCount == 0 {
                    if let payload = try await trackingItem.moveToStatus(to: .flyingBack, database: db) {
                        try await request.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                    }
                    try await trackingItem.save(on: db)
                    request.appendUserAction(.assignTrackingItemStatus(trackingNumber: trackingItem.trackingNumber, trackingItemID: trackingItemID, status: .flyingBack))
                }
            }
        }
        return shipment.toUncommitedOutput()
    }
    
    //api/v1/shipments/shipment_id/boxes (delete)
    private func removeBoxesHandler(request: Request) async throws -> HTTPResponseStatus {
        let user = try request.requireAuthUser()
        guard user.hasRequiredScope(for: .shipments) else {
            throw AppError.invalidScope
        }
        let shipment = try request.requireUncommitedShipment()
        
        let box = try request.requireBox()
        try await request.db.transaction { transaction in
            box.$shipment.id = nil
            let pieces = try await box.$pieces.get(on: transaction)
            try await pieces.asyncForEach {
                $0.flyingBackAt = nil
                try await $0.save(on: transaction)
            }
            try request.appendUserAction(.unassignBoxShipment(boxID: box.requireID(), shipmentID: shipment.requireID()))
            try await box.save(on: transaction)
        }

        return .ok
    }
    
    //api/v1/shipments/shipment_id/boxes/box_id
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
    
    private func getPaginateShipmentsHandler(req: Request) async throws -> Page<PaginateShipmentOutput> {
        let input = try req.query.decode(GetShipmentQueryInput.self)
        var query = TrackingItem.query(on: req.db)
            .with(\.$products)
            .with(\.$box) {
                $0.with(\.$shipment)
            }
            .sort(\.$boxedAt, .descending)
        
        if let shipmentIDs = input.shipmentIDs {
            query = query
                .join(Box.self, on: \Box.$id == \TrackingItem.$box.$id)
                .join(Shipment.self, on: \Box.$shipment.$id == \Shipment.$id)
                .filter(Shipment.self, \.$id ~~ shipmentIDs.compactMap { UUID(uuidString: $0) })
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
            return try await $0.toPaginateShipmentOutput(db: req.db)
        })
        return .init(items: items, metadata: page.metadata)
    }
    
    private func getShipmentListPaginatedHandler(req: Request) async throws -> Page<GetShipmentPaginatedOnWebOutput> {
        let query = Shipment.query(on: req.db)
            .filter(\.$commitedAt == nil)
            .with(\.$boxes)
            
        
        if let searchString = try? req.query.get(String.self, at: "shipmentCode") {
            query.filter(.sql(raw: "\(Shipment.schema).shipment_code"),
                         .custom("ILIKE"),
                         .bind("%\(searchString)%"))
        }
            
        let page = try await query.sort(\.$createdAt, .descending).paginate(for: req)
        return .init(
            items: page.items.map({ $0.output() }),
            metadata: page.metadata
        )
    }
    
    private func getShipmentDetailsHandler(req: Request) async throws -> GetShipmentPaginatedOnWebOutput {
        let shipment = try req.requireShipment()
        let boxes = try await shipment.$boxes.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .with(\.$lot)
            .with(\.$customItems)
            .all()
        let boxIDs = boxes.compactMap { $0.id }
        let pieces = try await TrackingItemPiece.query(on: req.db)
            .filter(\.$box.$id ~~ boxIDs)
            .with(\.$trackingItem) {
                $0.with(\.$products)
            }
            .all()
        let grouped = try pieces.grouped { $0.$box.id }
        let chains = pieces.map { $0.trackingItem }.compactMap { $0.chain }
        let chainTrackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$chain ~~ chains)
            .all()
        let groupedChain = try chainTrackingItems.grouped { $0.chain }
        shipment.$boxes.value = boxes.map { box in
            box.$pieces.value = grouped[box.id] ?? []
            return box
        }
        return try await shipment.toListOutput(groupedChain: groupedChain, on: req.db)
    }
    
    private func addBoxToShipmentHandler(req: Request) async throws -> GetBoxesOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .packDelivery) else {
            throw AppError.invalidScope
        }
        let input = try req.content.decode(AddBoxToShipmentInput.self)
        
        let shipment = try req.requireUncommitedShipment()
        let shipmentID = try shipment.requireID()
        let boxes = try await Box.query(on: req.db)
            .filter(\.$id ~~ input.boxIDs)
            .with(\.$pieces) {
                $0.with(\.$trackingItem)
            }
            .with(\.$customItems)
            .all()
        
        try await req.db.transaction { db in
            try await boxes.asyncForEach { box in
                guard box.pieces.allSatisfy({ piece in
                    piece.trackingItem.returnRequestAt == nil
                }) else {
                    throw AppError.boxIsContainingReturnedItem
                }
                guard !box.pieces.isEmpty || !box.customItems.isEmpty else {
                    throw AppError.boxIsEmpty
                }
                guard box.$shipment.id == nil else{
                    throw AppError.boxWasInShipment
                }
                box.$shipment.id = shipmentID
                try req.appendUserAction(.addBoxToShipment(boxID: box.requireID(), shipmentID: shipmentID))
                try await box.save(on: db)
            }
        }
        let targetBoxes = try await shipment.$boxes.get(on: req.db)
        return try await GetBoxesOutput(name: shipment.shipmentCode, items: targetBoxes, on: req.db)
    }
}
