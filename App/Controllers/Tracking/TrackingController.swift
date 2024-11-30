import Foundation
import Vapor
import Fluent
import SQLKit
import SendGrid

struct TrackingController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("trackingItems")
        groupedRoutes.get("power", use: getTrackingPowerHandler)
        groupedRoutes.get("images", use: getImagesHandler)
        groupedRoutes.get("dcStatus", use: getDCStatusHandler)
        groupedRoutes.post("sheetCustomerUpdate", use: updateCustomerBySheetHandler)
        groupedRoutes.post("sheetUSDeliStatus", use: getSheetUSDeliStatusHandler)
		groupedRoutes.post("sheetStatusUpdate", use: updateTrackingStatusBySheetHandler)

        try groupedRoutes.register(collection: TrackingMarketPlaceController())
        let protected = groupedRoutes.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )

        try protected.register(collection: TrackingExportController())
        try protected.register(collection: TrackingReceivedAtUSController())
        try protected.register(collection: TrackingRepackingController())
        try protected.register(collection: TrackingRepackedController())
        try protected.register(collection: TrackingReceivedAtVNController())
        try protected.register(collection: TrackingRepackedAtVNController())
        try protected.register(collection: TrackingArchiveAtVnController())
        try protected.register(collection: TrackingItemReportController())
        try protected.register(collection: ReturnedItemController())
       
//        try protected.register(collection: TrackingCSVImporter())
        try protected.register(collection: BrokenProductController())

        protected.group(ScopeCheckMiddleware(requiredScope: .usInventory)) {
            $0.get("boxed", use: getBoxedItemsHandler)
            $0.get("flyingBack", use: getFlyingBackItemsHandler)
        }

        protected.group(ScopeCheckMiddleware(requiredScope: .trackingItems)) {
            $0.get("customerCodeInputRequired", use: getCustomerCodeInputRequiredHandler)
            $0.get("infoForBoxedStep", use: getInfoForBoxedStepHandler)
            $0.get("status", use: getStatusHandler)
            $0.get("status", "partial", use: getStatusPartialHandler)
            $0.get("looseChains", use: getLooseChainsHandler)
        }
        
        protected.group(ScopeCheckMiddleware(requiredScope: [.trackingItems, .updateTrackingItems])) {
            $0.put(use: updateTrackingItemsHandler)
        }
        
        let trackingItemRoutes = protected
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())

        trackingItemRoutes.group(ScopeCheckMiddleware(requiredScope: .trackingItems)) {
            $0.get(use: getTrackingItemHandler)
            $0.get("timeline", use: getTrackingItemTimeLineHandler)
            $0.get("chain", use: getTrackingItemsInChainHandler)
            $0.get("walmart", use: getTrackingItemsByAlternativeRefHandler)
        }
        
        trackingItemRoutes.group(ScopeCheckMiddleware(requiredScope: [.trackingItems, .updateTrackingItems])) {
            $0.delete(use: deleteTrackingItemHandler)
            $0.put("chain", use: removeTrackingItemFromChainHanlder)
            $0.put(use: updateTrackingItemHandler)
            $0.post("pieces", use: createTrackingItemPieceHandler)
            $0.get("pieces", use: getTrackingItemPiecesHandler)
            $0.post("references", use: addTrackingReferencesHandler)
            $0.delete("references", TrackingItemReference.parameterPath, use: deleteTrackingItemReference)
            
            let pieceRoutes = $0.grouped("pieces")
                .grouped(TrackingItemPiece.parameterPath)
                .grouped(TrackingItemPieceIdentifyingMiddleware())
            pieceRoutes.put(use: updateTrackingItemPieceHandler)
            pieceRoutes.delete(use: deleteTrackingItemPiecesHandler)
        }
    }
    private func deleteTrackingItemReference(req: Request) async throws -> HTTPResponseStatus {
        guard let trackingReferenceID = req.parameters.get(TrackingItemReference.parameter, as: TrackingItemReference.IDValue.self) else {
            throw AppError.invalidInput
        }
        guard let trackingReference = try await TrackingItemReference.query(on: req.db)
            .filter(\.$id == trackingReferenceID)
            .first() else {
            throw AppError.trackingItemNotFound
        }
        try await trackingReference.delete(on: req.db)
        return .ok
    }
    
    private func addTrackingReferencesHandler(req: Request) async throws -> HTTPResponseStatus {
        let trackingItem = try req.requireTrackingItem()
        guard trackingItem.status.power >= 3 else {
            throw AppError.statusUpdateInvalid
        }
        let input = try req.content.decode(UpdateTrackingReferencesInput.self)
        let existedTrackingReferences = try await TrackingItemReference.query(on: req.db)
            .filter(trackingNumbers: input.trackingReferences)
            .all()
        let existedTrackingReferenceNumbers = existedTrackingReferences.map { $0.trackingNumber }
        var insertedTrackingReferenceNumber = input.trackingReferences
        existedTrackingReferenceNumbers.forEach { existedBarCode in
            insertedTrackingReferenceNumber = insertedTrackingReferenceNumber.filter { $0.suffix(12) != existedBarCode.suffix(12) }
        }
        let trackingReferences = try insertedTrackingReferenceNumber.map{
            TrackingItemReference.init(trackingNumber: $0, trackingItemID: try trackingItem.requireID(), deletedAt: trackingItem.deletedAt)
        }
        try await trackingReferences.create(on: req.db)
        return .ok
    }
    
    private func removeTrackingItemFromChainHanlder(req: Request) async throws -> TrackingItemOutput {
        let tracking = try req.requireTrackingItem()
        guard tracking.status == .boxed else {
            throw AppError.invalidStatusToRemoveTrackingFromChain
        }
        try await tracking.$pieces.load(on: req.db)
        guard tracking.pieces.count == 1 else {
            throw AppError.trackingHasManyPieces
        }
        guard let piece = tracking.pieces.first else {
            throw AppError.trackingItemPieceNotFound
        }
        try await req.db.transaction { db in
            tracking.chain = UUID().uuidString
            piece.$box.id = nil
            try req.appendUserAction(.assignChain(trackingItemID: tracking.requireID(), chain: tracking.chain))
            if let payload = try await tracking.moveToStatus(to: .repacked, database: db) {
                try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
            }
            try await tracking.save(on: db)
            try await piece.save(on: db)
        }
        
        try await tracking.$customers.load(on: req.db)
        try await tracking.$products.load(on: req.db)
        try await tracking.$warehouse.load(on: req.db)
        tracking.$pieces.value = try await tracking.$pieces.query(on: req.db)
            .with(\.$box) {
                $0.with(\.$lot)
                $0.with(\.$shipment)
            }
            .all()
        return tracking.output()
    }
    private func getTrackingItemsByAlternativeRefHandler(req: Request) async throws -> [TrackingItemByAlternativeRefOutput] {
        guard let trackingItemID = req.parameters.get(TrackingItem.parameter, as: TrackingItem.IDValue.self) else {
            throw AppError.invalidInput
        }
        guard let trackingItem = try await TrackingItem.query(on: req.db)
            .filter(\.$id == trackingItemID)
            .first() else {
            throw AppError.trackingItemNotFound
        }
        if trackingItem.isWalmartTracking {
            if let alternativeRef = trackingItem.alternativeRef {
                let alternativeRefs = [alternativeRef.uppercased(), alternativeRef.lowercased()]
                let items = try await TrackingItem.query(on: req.db)
                    .with(\.$pieces) {
                        $0.with(\.$box) {
                            $0.with(\.$shipment)
                            $0.with(\.$lot)
                        }
                    }
                    .filter(alternativeRefs: alternativeRefs)
                    .filter(\.$id != trackingItem.requireID())
                    .all()
                return items.map {
                    $0.outputByAlternativeRef()
                }
            }
        }
        return []
    }
    
    private func getTrackingPowerHandler(req: Request) async throws -> Int {
        let input = try req.query.decode(GetTrackingStatusInput.self)
        guard let trackingItem = try await TrackingItem.query(on: req.db)
            .filter(\.$trackingNumber == input.trackingNumber)
            .first()
        else {
            return 0
        }
        return trackingItem.status.power
    }

	private func updateTrackingStatusBySheetHandler(request: Request) async throws -> HTTPResponseStatus {
		let input = try request.content.decode(UpdateTrackingStatusBySheetInput.self)
		
		let isoDateFormatter = ISO8601DateFormatter.psaThreadSpecific
		isoDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		
		guard let date = isoDateFormatter.date(from: input.date) else {
			throw Abort(.badRequest, reason: "Date not in ISO8601 format")
		}
		
		let trackingNumbers: [String]
		if (input.trackingNumber.contains("\n")) {
			trackingNumbers = input.trackingNumber.components(separatedBy: "\n").removingDuplicates().compactMap {
				$0.requireValidTrackingNumber()
			}
		} else {
			trackingNumbers = [input.trackingNumber].compactMap {
				$0.requireValidTrackingNumber()
			}
		}

        try await trackingNumbers.asyncForEach { trackingNumber in
//			if input.state.power >= TrackingItem.Status.boxed.power {
//				if let targetTracking = try await TrackingItem.query(on: request.db)
//					.filter(trackingNumbers: [trackingNumber])
//					.first()
//				{
//					let pieceCount = try await targetTracking.$pieces.query(on: request.db).count()
//					if pieceCount > 1, input.pieces == nil {
//						let pieceInfos = try await TrackingItemPiece.query(on: request.db)
//							.filter(\.$trackingItem.$id == targetTracking.requireID())
//							.all(\.$information)
//							.compactMap { $0 }
//
//						throw AppWithOutputError.piecesNotFound((pieceInfos.joined(separator: ", ")))
//					}
//				}
//			}

            let payload = TrackingItemStatusUpdateJob.Payload.init(
                timestampt: date,
                trackingNumber: trackingNumber,
                sheetName: input.sheetName,
                status: input.state,
                pieces: input.pieces
            )
            
            try await request.queue.dispatch(TrackingItemStatusUpdateJob.self, payload, maxRetryCount: 3)
        }
        
        return .ok
    }
    
    private func getSheetUSDeliStatusHandler(request: Request) async throws -> String {
        let input = try request.content.decode(GetTrackingStatusInput.self)
        
        guard input.trackingNumber.isValidTrackingNumber() else {
            return ""
        }
		let now = Date()
        
        var targetTracking = try await TrackingItem.query(on: request.db)
            .with(\.$customers)
            .filter(\.$trackingNumber == input.trackingNumber)
            .first()
        
		let end1 = Date().timeIntervalSince(now)
		print("end1", end1)
        if targetTracking == nil {
            let query = TrackingItem.query(on: request.db)
			query.group(.or) { builder in
				builder.filter(trackingNumbers: [input.trackingNumber])
				if input.includeAlternativeRef == true {
					builder.filter(alternativeRefs: [input.trackingNumber])
				}
			}
            
            targetTracking = try await query.first()
			let end2 = Date().timeIntervalSince(now)
			print("end2", end2)
        }

        guard
            let tracking = targetTracking
        else {
            return ""
        }

        return tracking.receivedAtUSAt?.toISOString() ?? ""
    }
    
    private func updateCustomerBySheetHandler(request: Request) async throws -> HTTPResponseStatus {
        let input = try request.content.decode(UpdateCustomerBySheetInput.self)
        
        guard let trackingItem = try await TrackingItem.query(on: request.db)
            .filter(trackingNumbers: [input.trackingNumber])
            .first()
        else {
            throw AppError.trackingItemNotFound
        }
        
        guard let customer = try await Customer.query(on: request.db)
            .filter(\.$customerCode == input.customerCode)
            .first()
        else {
            throw AppError.customerNotFound
        }
        
        if (trackingItem.itemDescription?.hasPrefix("**Mã khách hàng đổi qua sheet**") != true) {
            trackingItem.itemDescription = "**Mã khách hàng đổi qua sheet** \(trackingItem.itemDescription ?? "")"
        }

		try await request.db.transaction { db in
			try await trackingItem.save(on: db)
			try await trackingItem.$customers.detachAll(on: db)
			let attachCustomers: [Customer] = [customer]
			try await trackingItem.$customers.attach(attachCustomers, on: db)
		}

        try request.appendAgentAction(identifier: "updateCustomerSheet", .assignTrackingItemCustomerCode(trackingItemID: trackingItem.requireID(), customerID: customer.requireID(), customerCode: customer.customerCode))
        
        return .ok
    }
    
    private func getDCStatusHandler(request: Request) async throws -> TrackingItemOutput {
        let input = try request.query.decode(GetDCTrackingItemInput.self)
        let query = TrackingItem.query(on: request.db)
			.group(.or) { builder in
				builder.filter(trackingNumbers: [input.trackingNumber])
				builder.filter(alternativeRefs: [input.trackingNumber])
			}
        
        if let receivedAtUSAt = input.receivedAtUSAt {
            query
                .filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"),
                        .lessThanOrEqual, .bind(receivedAtUSAt))
        }
        
        guard let trackingItem = try await query
            .sort(\.$receivedAtUSAt, .descending)
            .with(\.$products)
            .first() else {
            throw AppError.trackingItemNotFound
        }
        
        let files = trackingItem.files
        let productFiles = trackingItem.products.flatMap {
            return $0.images
        }
        
        var output = trackingItem.output()
        output.files = [files, productFiles].flatMap { $0 }
        return output
    }
    
    private func getImagesHandler(request: Request) async throws -> GetTrackingImagesOutput {
        let input = try request.query.decode(GetTrackingItemImagesInput.self)
        
        guard let trackingItem = try await TrackingItem.query(on: request.db)
            .filter(trackingNumbers: [input.trackingNumber])
            .filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"),
                    .lessThanOrEqual, .bind(input.receivedAtUSAt))
                .sort(\.$receivedAtUSAt, .descending)
                .with(\.$products)
                .first() else {
            return []
        }
        
        let agent = "DC"
        let files = trackingItem.files
        let productFiles = trackingItem.products.flatMap {
            return $0.images
        }
        
        return [files, productFiles].flatMap({ $0 }).map {
            .init(agent: agent, fileID: $0)
        }
    }
    
    private func getCustomerCodeInputRequiredHandler(request: Request) async throws -> GetTrackingItemInfoRequiredOutput {
        let input = try request.query.decode(GetCustomerCodeInputRequiredInput.self)
        let user = try request.requireAuthUser()
        var availableAgentIDs = try await user.$agents
            .query(on: request.db)
            .all(\.$id)
        
        let allTrackingWithProductIDs = try await Product.query(on: request.db)
            .join(parent: \.$trackingItem)
            .filter(TrackingItem.self, \.$receivedAtVNAt == nil)
            .filter(.sql(raw: "\(Product.schema).description"), .custom("~*"), .bind("\\S"))
            .filter(\.$quantity > 0)
            .field(\.$trackingItem.$id)
            .unique()
            .all(\.$trackingItem.$id)
        
        let allTrackingWithProductThatHasImages = try await Product.query(on: request.db)
            .join(parent: \.$trackingItem)
            .filter(TrackingItem.self, \.$receivedAtVNAt == nil)
            .filter(\.$images != [])
            .field(\.$trackingItem.$id)
            .unique()
            .all(\.$trackingItem.$id)
        
        // DC -> Lay tu 2023-04-05
        // MD -> Lay tu 2023-04-21
        let fromDate = Date(isoDate: "2023-04-05")!
        let MDFromDate = Date(isoDate: "2023-04-21")!
        
        if let agentIDs = input.agentIDs, !agentIDs.isEmpty {
            availableAgentIDs = Array(Set(availableAgentIDs).intersection(Set(agentIDs)))
        }
        let subQuery = try await TrackingItemCustomer.query(on: request.db)
            .join(parent: \.$trackingItem)
            .filter(TrackingItem.self, \.$receivedAtVNAt == nil)
            .field(\.$trackingItem.$id)
            .unique()
            .all(\.$trackingItem.$id)
        let query = TrackingItem.query(on: request.db)
            .with(\.$customers)
            .group(.or, { builder in
                builder.filter(\.$id !~ subQuery)
                if !allTrackingWithProductIDs.isEmpty {
                    builder.filter(\.$id !~ allTrackingWithProductIDs)
                }
                builder.group(.and) { andBuilder in
                    andBuilder.filter(\.$isWalmartTracking == true)
                    andBuilder.filter(\.$alternativeRef == nil)
                }
            })
            .filter(\.$agentCode ~~ availableAgentIDs)
            .group(.or) { orBuilder in
                orBuilder.group(.and) { andBuilder in
                    andBuilder.filter(\.$agentCode != "MD")
                    andBuilder.filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"),
                                      .greaterThanOrEqual, .bind(fromDate))
                }
                orBuilder.group(.and) { andBuilder in
                    andBuilder.filter(\.$agentCode == "MD")
                    andBuilder.filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"),
                                      .greaterThanOrEqual, .bind(MDFromDate))
                }
            }
            .filter(\.$repackingAt != nil)
            .group(.or) { orBuilder in
                orBuilder.filter(\.$id ~~ allTrackingWithProductThatHasImages)
                orBuilder.filter(\.$files != [])
            }
            .filter(\.$receivedAtVNAt == nil)
        guard
            let trackingItem = try await query
                .with(\.$products)
                .sort(.sql(raw: "RANDOM()"))
                .first()
        else {
            throw AppError.trackingItemNotFound
        }
        
        let total = try await query.count()
        return .init(
            trackingItem: trackingItem.output(),
            total: total
        )
    }
    
    private func getTrackingItemTimeLineHandler(request: Request) async throws -> [GetTrackingItemTimeLineOutput] {
        guard let trackingItemID = request.parameters.get(TrackingItem.parameter, as: TrackingItem.IDValue.self) else {
            throw AppError.invalidInput
        }
        
        let actions = try await ActionLogger.query(on: request.db)
            .group(.or) { builder in
                let targetActionTypes: [ActionLogger.ActionType.CodingKeys] = [
                    .assignTrackingItemStatus,
                    .assignTrackingItemCustomerCode,
                    .assignTrackingItemAgentCode,
                    .assignTrackingItemDescription,
                    .assignTrackingItemFiles,
                    .assignBox,
                    .assignChain,
                    .assignProducts,
                    .assignProductQuantity,
                    .assignProductDescription,
                    .assignTrackingNumberBrokenProductDescription,
                    .assignTrackingNumberBrokenProductCustomerFeedback,
                    .createPiece,
                    .deletePiece,
                    .addTrackingItemPieceToBox,
                    .updatePiece,
                    .removeTrackingItemPieceFromBox,
                    .assignCustomers,
                    .assignReturnRequest,
                    .switchTrackingToAnotherWarehouse
                ]
                targetActionTypes.forEach { actionType in
                    builder.filter(.sql(raw: "(type->>'\(actionType.rawValue)')::jsonb->>'trackingItemID'"), .equal, .bind(trackingItemID.uuidString))
                }
            }
            .sort(\.$createdAt, .descending)
            .with(\.$user, withDeleted: true)
            .all()
        return actions.map {
            .init(
                id: trackingItemID,
                action: $0.type,
                username: $0.user?.username ?? "N/A",
                createdAt: $0.createdAt
            )
        }
    }
    
    private func getStatusPartialHandler(request: Request) async throws -> GetTrackingStatusOutput {
        let input = try request.query.decode(
            GetTrackingStatusInput.self)
        
        let query = TrackingItem.query(on: request.db)
            .with(\.$customers)
        query.filter(searchStrings: [input.trackingNumber], includeAlternativeRef: input.includeAlternativeRef ?? false)
        
        guard
            input.trackingNumber.isValidTrackingNumber(),
            let tracking = try await query.first()
        else {
            return .init(trackingID: nil, status: .new, chain: nil)
        }
        let customerCodes = try await tracking.$customers.query(on: request.db)
            .all(\.$customerCode)
        return try .init(
            trackingID: tracking.requireID(),
            status: tracking.status,
            chain: tracking.chain,
            trackingNumber: tracking.trackingNumber,
            agentCode: tracking.agentCode,
            customerCode: customerCodes.joined(separator: ", "),
            files: tracking.files
        )
    }
    
    private func getStatusHandler(request: Request) async throws -> GetTrackingStatusOutput {
        let input = try request.query.decode(GetTrackingStatusInput.self)
        
        var targetTracking = try await TrackingItem.query(on: request.db)
            .with(\.$customers)
            .filter(\.$trackingNumber == input.trackingNumber)
            .with(\.$trackingItemReferences)
            .first()
        
        var isDuplicatedReferenceTracking: Bool = false
       
        if targetTracking == nil {
            let query = TrackingItem.query(on: request.db)
            query.filter(searchStrings: [input.trackingNumber], includeAlternativeRef: input.includeAlternativeRef ?? false)
            guard input.trackingNumber.isValidTrackingNumber() else {
                return .init(trackingID: nil, status: .new, chain: nil, isDuplicatedReferenceTracking: isDuplicatedReferenceTracking)
            }
            targetTracking = try await query.with(\.$trackingItemReferences).first()
            if targetTracking == nil {
                let trackingReference = try await TrackingItemReference.query(on: request.db)
                    .filter(trackingNumbers: [input.trackingNumber])
                    .first()
                
                if let trackingItemReference = trackingReference {
                    targetTracking = try await TrackingItem.query(on: request.db)
                        .with(\.$trackingItemReferences)
                        .filter(\.$id == trackingItemReference.$trackingItem.id)
                        .first()
                    isDuplicatedReferenceTracking = true
                }
            }
        }
        
        guard
            let tracking = targetTracking
        else {
            return .init(trackingID: nil, status: .new, chain: nil, isDuplicatedReferenceTracking: isDuplicatedReferenceTracking)
        }
        let products = try await tracking.$products.query(on: request.db)
            .sort(\.$quantity, .descending)
            .all()
        let productCount = products.count
        let firstProductQuantity = products.first?.quantity
        let customerCodes = try await tracking.$customers.query(on: request.db)
            .all(\.$customerCode)
        var files: [String] = tracking.files
        if files.isEmpty {
            files = products.first?.images ?? []
        }
        
        return try .init(
            trackingID: tracking.requireID(),
            status: tracking.status,
            chain: tracking.chain,
            trackingNumber: tracking.trackingNumber,
            agentCode: tracking.agentCode,
            customerCode: customerCodes.joined(separator: ", "),
            files: files,
            productCount: productCount,
            firstProductQuantity: firstProductQuantity,
            trackingItemReferences: tracking.$trackingItemReferences.value?.map{ $0.trackingNumber },
            isDuplicatedReferenceTracking: isDuplicatedReferenceTracking
        )
    }
    
    private func getInfoForBoxedStepHandler(req: Request) async throws -> GetTrackingInfoForBoxedStepOutput {
        let input = try req.query.decode(GetTrackingStatusInput.self)
        
        var targetTracking = try await TrackingItem.query(on: req.db)
            .with(\.$customers)
            .filter(\.$trackingNumber == input.trackingNumber)
            .with(\.$trackingItemReferences)
            .first()
        
        if targetTracking == nil {
            let query = TrackingItem.query(on: req.db)
            query.filter(searchStrings: [input.trackingNumber], includeAlternativeRef: input.includeAlternativeRef ?? false)
            targetTracking = try await query.with(\.$trackingItemReferences).first()
            if targetTracking == nil {
                let trackingReference = try await TrackingItemReference.query(on: req.db)
                    .filter(trackingNumbers: [input.trackingNumber])
                    .first()
                
                targetTracking = try await trackingReference?.$trackingItem.get(on: req.db)
            }
        }
        
        guard
            let tracking = targetTracking
        else {
            throw AppError.trackingItemNotFound
        }
        
        guard tracking.status.power < 5 else {
            throw AppError.invalidStatus
        }
        
        let products = try await tracking.$products.query(on: req.db)
            .sort(\.$quantity, .descending)
            .all()
        
        var files: [String] = tracking.files
        
        var targetWaringState: [WarningState] = []
        if tracking.returnRequestAt != nil {
            targetWaringState.append(.returnTracking)
        }
        let pieceCount = try await tracking.$pieces.query(on: req.db).filter(\.$box.$id == nil).count()
        if pieceCount > 1 {
            targetWaringState.append(.pieces)
        }
        if files.isEmpty {
            files = products.first?.images ?? []
            if files.isEmpty {
                targetWaringState.append(.noImage)
            }
        }
        var targetPackingRequest: String = ""
        if let includePackingRequest = input.includePackingRequest, includePackingRequest {
            if let buyerTrackingItemLinkView = try await BuyerTrackingItemLinkView.query(on: req.db)
                .filter(\.$trackingItem.$id == tracking.requireID())
                .with(\.$buyerTrackingItem)
                .first() {
                
                targetPackingRequest = buyerTrackingItemLinkView.buyerTrackingItem.packingRequest
                if let repackedAt = tracking.repackedAt, let createdAt = buyerTrackingItemLinkView.buyerTrackingItem.createdAt, createdAt > repackedAt, tracking.boxedAt == nil {
                    targetWaringState.append(.packingRequest)
                }
            }
        }
        return try .init(
            trackingID: tracking.requireID(),
            piecesWithoutBoxCount: pieceCount,
            warningState: targetWaringState,
            packingRequestDetail: targetPackingRequest
            )
    }
    
    private func getBoxedItemsHandler(req: Request) async throws -> GetBoxedItemsOutput {
        let boxedItems = try await TrackingItem.query(on: req.db)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$flyingBackAt == nil)
            .filter(\.$boxedAt != nil)
            .all()
        
        return GetBoxedItemsOutput(items: boxedItems)
    }
    
    private func getFlyingBackItemsHandler(req: Request) async throws -> GetFlyingBackItemsOutput {
        let flyingBackItems = try await TrackingItem.query(on: req.db)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$flyingBackAt != nil)
            .all()
        
        return GetFlyingBackItemsOutput(items: flyingBackItems)
    }
    
    private func getReceivedAtVNItemsHandler(req: Request) async throws -> GetReceivedAtVNItemsOutput {
        let receivedAtVNItems = try await TrackingItem.query(on: req.db)
            .filter(\.$receivedAtVNAt != nil)
            .with(\.$customers)
            .all()
        return GetReceivedAtVNItemsOutput(items: receivedAtVNItems)
    }
    
    private func deleteTrackingItemHandler(req: Request) async throws -> HTTPResponseStatus {
        let trackingItem = try req.requireTrackingItem()
        try await req.db.transaction { db in
			let pieces = try await TrackingItemPiece.query(on: db)
				.filter(\.$trackingItem.$id == trackingItem.requireID())
				.with(\.$box)
				.all()
			guard pieces.allSatisfy({ $0.box?.id == nil }) else {
				throw AppError.notAllowedToDeleteThisPiece
			}
			try await pieces.asyncForEach {
				try await $0.delete(on: db)
			}
            try await TrackingItemReference.query(on: db)
                .filter(\.$trackingItem.$id == trackingItem.requireID())
                .delete()
            try await trackingItem.delete(on: db)
			try? await req.dcClient.deleteTrackingNumber(trackingNumber: trackingItem.trackingNumber)
        }
        
        req.appendUserAction(.deleteTrackingNumber(trackingNumber: trackingItem.trackingNumber))
        return .ok // 200
    }
    
    private func getTrackingItemHandler(req: Request) async throws -> TrackingItemOutput {
        guard let trackingItemID = req.parameters.get(TrackingItem.parameter, as: TrackingItem.IDValue.self) else {
            throw AppError.invalidInput
        }
        guard let item = try await TrackingItem.query(on: req.db)
            .filter(\.$id == trackingItemID)
            .first() else {
            throw AppError.trackingItemNotFound
        }
        try await item.$trackingItemReferences.load(on: req.db)
        try await item.$products.load(on: req.db)
        try await item.$warehouse.load(on: req.db)
        try await item.$box.load(on: req.db)
        try await item.box?.$shipment.load(on: req.db)
        try await item.$customers.load(on: req.db)
        try await item.$cameraDetails.load(on: req.db)
        let pieces = try await item.$pieces.query(on: req.db)
            .with(\.$box) {
                $0.with(\.$lot)
                $0.with(\.$shipment)
            }
            .all()
        item.$pieces.value = pieces
        let trackingItems = try await TrackingItem.query(on: req.db)
            .with(\.$customers)
            .with(\.$pieces) {
                $0.with(\.$box)
                $0.with(\.$trackingItem)
            }
            .with(\.$cameraDetails)
            .filter(\.$chain == item.chain)
            .filter(\.$chain != nil)
            .all()
        return item.outputWithChainItems(trackingItems.map { $0.output() })
    }
    
    private func updateTrackingItemHandler(req: Request) async throws -> TrackingItemOutput {
        let item = try req.requireTrackingItem()
        let trackingItemID = try item.requireID()
        let input = try req.content.decode(UpdateTrackingItemInput.self)
        let itemHasAllRequiredInfoPriorToUpdate = try await item.hasAllRequiredInformation(on: req.db)
        
        if let agentCode = input.agentCode, agentCode.value != item.agentCode {
            if item.status == .archiveAtVN {
                item.agentCode = agentCode.value
                try req.appendUserAction(.assignTrackingItemAgentCode(trackingItemID: item.requireID(), agentCode: agentCode.value))
            } else {
                guard item.status <= TrackingItem.Status.repacking || agentCode.value != nil else {
                    throw AppError.cantUpdateAgentCodeToNilIfPassedRepacking
                }
                item.agentCode = agentCode.value
                try req.appendUserAction(.assignTrackingItemAgentCode(trackingItemID: item.requireID(), agentCode: agentCode.value))
                if item.agentCode == nil && item.repackingAt != nil {
                    _ = try await item.moveToStatus(to: .receivedAtUSWarehouse, database: req.db)
                    try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: item.trackingNumber, trackingItemID: item.requireID(), status: .receivedAtUSWarehouse))
                } else if item.agentCode != nil && item.repackingAt == nil {
                    _ = try await item.moveToStatus(to: .repacking, database: req.db)
                    try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: item.trackingNumber, trackingItemID: item.requireID(), status: .repacking))
                }
            }
        }
        if let trackingNumber = input.trackingNumber, trackingNumber != item.trackingNumber {
            item.trackingNumber = trackingNumber
        }
        
        if let alternativeRef = input.alternativeRef, alternativeRef.value != item.alternativeRef {
            guard item.isWalmartTracking else {
                throw AppError.settingAlternativeRefIsOnlySuportedForWalmartTrackings
            }
            item.alternativeRef = alternativeRef.value
            try req.appendUserAction(.assignTrackingItemAlternativeRef(trackingItemID: item.requireID(), alternativeRef: alternativeRef.value))
        }
        if let files = input.files, files != item.files {
            item.files = files
            try req.appendUserAction(.assignTrackingItemFiles(trackingItemID: item.requireID(), files: files))
        }
        if let itemDescription = input.itemDescription, itemDescription.value != item.itemDescription {
            item.itemDescription = itemDescription.value
            try req.appendUserAction(.assignTrackingItemDescription(trackingItemID: item.requireID(), itemDescription: itemDescription.value))
        }
        if let brokenProductDescription = input.brokenProductDescription, brokenProductDescription.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" != item.brokenProduct.description {
            let trimmedValue = brokenProductDescription.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedValue.isEmpty {
                item.brokenProduct.description = nil
                item.brokenProduct.flagAt = nil
                item.brokenProduct.customerFeedback = nil
                try req.appendUserAction(.assignTrackingNumberBrokenProductDescription(trackingItemID: item.requireID(), brokenProductDescription: nil))
                try req.appendUserAction(.assignTrackingNumberBrokenProductCustomerFeedback(trackingItemID: item.requireID(), brokenProductCustomerFeedback: nil))
               
            } else {
                item.brokenProduct.description = trimmedValue
                item.brokenProduct.flagAt = Date()
                item.brokenProduct.customerFeedback = TrackingItem.CustomerFeedback.none
                try req.appendUserAction(.assignTrackingNumberBrokenProductDescription(trackingItemID: item.requireID(), brokenProductDescription: trimmedValue))
                try req.appendUserAction(.assignTrackingNumberBrokenProductCustomerFeedback(trackingItemID: item.requireID(), brokenProductCustomerFeedback: TrackingItem.CustomerFeedback.none))
                if let receivedAtUSAt = item.receivedAtUSAt {
                    let payload = FaultyTrackingItemNotificationJob.Payload(
                        trackingNumber: item.trackingNumber,
                        faultDescription: trimmedValue,
                        receivedAtUSAt: receivedAtUSAt
                    )
                    try await req.queue.dispatch(FaultyTrackingItemNotificationJob.self, payload)
                }
            }
        }
        if let brokenProductFeedback = input.brokenProductCustomerFeedback, brokenProductFeedback.value != item.brokenProduct.customerFeedback {
            guard let brokenProductDescription = item.brokenProduct.description, !brokenProductDescription.isEmpty else {
                throw AppError.brokenProductDescriptionMustNotBeEmpty
            }
            item.brokenProduct.customerFeedback = input.brokenProductCustomerFeedback?.value ?? TrackingItem.CustomerFeedback.none
            try req.appendUserAction(.assignTrackingNumberBrokenProductCustomerFeedback(trackingItemID: item.requireID(), brokenProductCustomerFeedback: input.brokenProductCustomerFeedback?.value ?? TrackingItem.CustomerFeedback.none))
        }
        if let warehouseID = input.warehouseID, warehouseID != item.$warehouse.id {
            item.$warehouse.id = warehouseID
        }
        let itemIsReturnRequest = item.returnRequestAt != nil
        
        if let isReturnRequest = input.isReturnRequest, isReturnRequest != itemIsReturnRequest {
            if isReturnRequest {
                item.returnRequestAt = Date()
                try req.appendUserAction(.assignReturnRequest(trackingItemID: item.requireID(), isReturn: isReturnRequest))
                item.holdState = .holding
                item.holdStateAt = Date()
                try req.appendUserAction(.updateTrackingItemHoldState(trackingItemID: item.requireID(), holdState: .continueDelivering))
            }
            else {
                item.returnRequestAt = nil
                try req.appendUserAction(.assignReturnRequest(trackingItemID: item.requireID(), isReturn: isReturnRequest))
                item.holdState = .continueDelivering
                try req.appendUserAction(.updateTrackingItemHoldState(trackingItemID: item.requireID(), holdState: .continueDelivering))
            }
        }

        let inputProducts = input.products
        let inputCustomerIDs = input.customerIDs
        let isReturnRequest = input.isReturnRequest
        try await req.db.transaction { db in
            if let inputProducts = inputProducts {
                let updatingProducts = inputProducts.filter{ $0.id != nil }
                let creatingProducts = inputProducts.filter{ $0.id == nil }
                let existingProducts = try await Product.query(on: db)
                    .filter(\.$trackingItem.$id == trackingItemID)
                    .all()
                
                guard existingProducts.count == updatingProducts.count else {
                    throw AppError.productNotFound
                }
                let grouped = try existingProducts.grouped(by: \.id?.uuidString)
                let needUpdatedProducts = try updatingProducts.compactMap ({ product in
                    guard let targetProduct = grouped[product.id?.uuidString]?.first else {
                        throw AppError.productNotFound
                    }
                    if let images = product.images, images != targetProduct.images {
                        targetProduct.images = images
                        try req.appendUserAction(.assignProductImages(trackingItemID: trackingItemID, productID: targetProduct.requireID(), images: images))
                    }
                    if let description = product.description, description != targetProduct.description {
                        targetProduct.description = description
                        try req.appendUserAction(.assignProductDescription(trackingItemID: trackingItemID, productID: targetProduct.requireID(), description: description))
                    }
                    if let quantity = product.quantity, quantity != targetProduct.quantity {
                        targetProduct.quantity = quantity
                        try req.appendUserAction(.assignProductQuantity(trackingItemID: trackingItemID, productID: targetProduct.requireID(), quantity: quantity))
                    }
                    if targetProduct.hasChanges {
                        return targetProduct
                    }
                    return nil
                })
                try await needUpdatedProducts.asyncForEach { product in
                    try await product.save(on: db)
                }
                try await Product.query(on: db)
                    .filter(\.$trackingItem.$id == trackingItemID)
                    .filter(\.$id !~ updatingProducts.compactMap(\.id))
                    .delete()
                let currentCount = try await item.$products.query(on: db).count()
                let newProducts = creatingProducts.enumerated().map ({ index, product in
                    let newProduct = Product(
                        trackingItemID: trackingItemID,
                        images: product.images ?? [],
                        index: currentCount + index,
                        description: product.description ?? "",
                        quantity: product.quantity ?? 0
                    )
                    return newProduct
                })
                try await newProducts.create(on: db)
                let newProductIDs = newProducts.compactMap(\.id)
                req.appendUserAction(.assignProducts(trackingItemID: trackingItemID, productIDs: newProductIDs))
            }
            let customers = try await item.$customers.get(on: db)
            let customerIDs = customers.compactMap(\.id)
            if let inputCustomerIDs = inputCustomerIDs, inputCustomerIDs != customerIDs {
                let inputCustomers = try await Customer.query(on: db)
                    .filter(\.$id ~~ inputCustomerIDs)
                    .all()
                if inputCustomers.count > 0 {
                    guard let sqlDB = db as? SQLDatabase else {
                        throw AppError.unknown
                    }
                    try await item.$customers.detach(customers, on: db)
                    try await item.$customers.attach(inputCustomers, on: db)
                    let customers = try await item.$customers.query(on: db).all()
                    let customerIDs = try customers.map { try $0.requireID() }
                    let customerCodes = customers.map { $0.customerCode }
                    req.appendUserAction(.assignCustomers(trackingID: trackingItemID, customerIDs: customerIDs, customerCodes: customerCodes))
                    if let existedCustomer = customers.first(where: { $0.email != nil }), let email = existedCustomer.normalizeEmail() {
                        struct RowOutput: Content {
                            var isPublicImages: Bool?
                        }
                        let query: SQLQueryString = """
                            select b.is_public_images as \(ident: "isPublicImages") from \(ident: Buyer.schema) b
                            where LOWER(TRIM(b.email)) = \(bind: email)
                        """
                        let results: [RowOutput]
                        do {
                            results = try await sqlDB.raw(query).all(decoding: RowOutput.self)
                        } catch {
                            print(String(reflecting: error))
                            throw error
                        }
                        if let isPublicImages = results.first?.isPublicImages {
                            item.allAccessCheckTrackingWithImages = isPublicImages
                        }
                    }
                   
                }
                else {
                    try await item.$customers.detach(customers, on: db)
                    req.appendUserAction(.assignCustomers(trackingID: trackingItemID, customerIDs: [], customerCodes: []))
                }
            }
            if item.hasChanges {
                if isReturnRequest != nil {
                    let buyerTrackingItems = try await item.$buyerTrackingItems.get(on: db)
                    if buyerTrackingItems.count > 0 {
                        try await buyerTrackingItems.asyncForEach { buyerTrackingItem in
                            if buyerTrackingItem.packingRequestState != .hold {
                                buyerTrackingItem.packingRequestState = .hold
                                try await buyerTrackingItem.save(on: db)
                            }
                        }
                    }
                }
                try await item.save(on: db)
            }
        }
        try await item.$customers.load(on: req.db)
        try await item.$products.load(on: req.db)
        try await item.$warehouse.load(on: req.db)
        let pieces = try await item.$pieces.query(on: req.db)
            .with(\.$box) {
                $0.with(\.$lot)
                $0.with(\.$shipment)
            }
            .all()
        item.$pieces.value = pieces
        let itemHasAllRequiredInfoAfterUpdate = try await item.hasAllRequiredInformation(on: req.db)
        if !itemHasAllRequiredInfoPriorToUpdate && itemHasAllRequiredInfoAfterUpdate {
            req.appendUserAction(.trackingInfoFinalised(trackingItemID: trackingItemID))
        }
        return item.output()
    }
    
    private func getTrackingItemsInChainHandler(req: Request) async throws -> [TrackingItemOutput] {
        let item = try req.requireTrackingItem()
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$chain == item.chain)
            .filter(\.$chain != nil)
            .all()
        return trackingItems.map {
            $0.output()
        }
    }
    
    private func createTrackingItemPieceHandler(req: Request) async throws -> GetTrackingItemPieceOutput {
        let item = try req.requireTrackingItem()
        let input = try req.content.decode(CreateTrackingItemPieceInput.self)
        guard item.boxedAt == nil else {
            throw AppError.trackingAlreadyInBox
        }
        let chainItemsCount = try await TrackingItem.query(on: req.db)
            .filter(\.$chain == item.chain)
            .filter(\.$chain != nil)
            .count()
        guard chainItemsCount <= 1 else {
            throw AppError.cantAddProductToTrackingItem
        }
        let newPieces = TrackingItemPiece(
            information: input.information,
            trackingItemID: try item.requireID()
        )
        try await newPieces.save(on: req.db)
        try req.appendUserAction(.createPiece(pieceID: newPieces.requireID()))
        try await newPieces.$trackingItem.load(on: req.db)
        return newPieces.output(trackingNumber: item.trackingNumber)
    }
    
    private func deleteTrackingItemPiecesHandler(req: Request) async throws -> HTTPResponseStatus {
        let targetPiece = try req.requiredTrackingItemPiece()
        let trackingItem = try req.requireTrackingItem()
        
        let trackingItemPiecesCount = try await trackingItem.$pieces.get(on: req.db).count
        guard targetPiece.$box.id == nil && trackingItemPiecesCount > 1 else {
            throw AppError.notAllowedToDeleteThisPiece
        }
        try req.appendUserAction(.deletePiece(pieceID: targetPiece.requireID()))
        try await targetPiece.delete(on: req.db)
        return .ok
    }
    
    private func updateTrackingItemPieceHandler(req: Request) async throws -> GetTrackingItemPieceOutput {
        let input = try req.content.decode(UpdateTrackingItemPieceInput.self)
        
        let piece = try req.requiredTrackingItemPiece()
        if let information = input.information, information != piece.information {
            piece.information = information
            try req.appendUserAction(.updatePiece(pieceID: piece.requireID(), infomation: information))
        }
        try await piece.save(on: req.db)
        
        let trackingItem = try await piece.$trackingItem.get(on: req.db)
        piece.$box.value = try await piece.$box.query(on: req.db)
            .with(\.$lot)
            .with(\.$shipment)
            .first()
        return piece.output(trackingNumber: trackingItem.trackingNumber)
    }
    
    private func getTrackingItemPiecesHandler(req: Request) async throws -> [GetTrackingItemPieceOutput] {
        let item = try req.requireTrackingItem()
        let trackingItemPieces = try await item.$pieces.query(on: req.db)
            .filter(\.$boxedAt == nil)
            .with(\.$trackingItem)
            .all()
        
        return trackingItemPieces.map {
            $0.output(trackingNumber: item.trackingNumber)
        }
    }
    
    private func updateTrackingItemsHandler(req: Request) async throws -> HTTPResponseStatus {
        let input = try req.content.decode(UpdateTrackingItemsInput.self)
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$id ~~ input.trackingItemIDs)
            .all()
        try await req.db.transaction { db in
            try await trackingItems.asyncForEach { item in
                guard item.status <= TrackingItem.Status.repacking else {
                    throw AppError.cantUpdateAgentCodeToNilIfPassedRepacking
                }
                item.agentCode = input.agentID
                try req.appendUserAction(.assignTrackingItemAgentCode(trackingItemID: item.requireID(), agentCode: input.agentID))
                try await item.save(on: db)
            }
        }
        return .ok
    }
    
    private func getLooseChainsHandler(request: Request) async throws -> Page<GetLooseChainOutput> {
		guard let sqlDB = request.db as? SQLDatabase else {
			throw AppError.unknown
		}
		let pageRequest = try request.query.decode(PageRequest.self)
		struct RowOutput: Content {
			var chain: String
			var total: Int
			var customers: String
		}
		let pagedQuery: SQLQueryString = """
			select
				ti.chain,
				max(ti.updated_at) as \(ident: "max_updated_at"),
				COUNT(*) OVER () as \(ident: "total"),
				STRING_AGG(c.customer_code, ', ') as "customers"
			from \(ident: TrackingItem.schema) ti
			left join \(ident: TrackingItemCustomer.schema) tic on tic.tracking_item_id = ti.id
		    left join \(ident: Customer.schema) c on c.id = tic.customer_id
			where
			ti.received_at_vn_at IS NULL and ti.chain IS NOT NULL
			and (ti.deleted_at IS NULL or ti.deleted_at > now())
			group by ti.chain
			having count(distinct tic.customer_id) > 1
			order by \(ident: "max_updated_at") desc
			limit \(bind: pageRequest.per)
			offset \(bind: pageRequest.per * (pageRequest.page - 1));
		"""
		let results: [RowOutput]
		do {
			results = try await sqlDB.raw(pagedQuery).all(decoding: RowOutput.self)
		} catch {
			print(String(reflecting: error))
			throw error
		}
		let total = results.first?.total ?? 0
		let customerNames = try results.indexed(by: \.chain).mapValues(\.customers)
		let chains: [String] = results.map(\.chain)

		let items: [GetLooseChainOutput] = try await TrackingItem.query(on: request.db)
			.filter(\.$chain ~~ chains)
			.with(\.$customers)
			.all()
			.grouped(by: \.chain)
			.compactMap { k, v -> GetLooseChainOutput? in
				guard let chain = k else { return nil }
				return GetLooseChainOutput(
					chain: chain,
					customerNames: customerNames[chain] ?? "",
					items: v.sortCreatedAtDescending().map { $0.output() }
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
    
}
