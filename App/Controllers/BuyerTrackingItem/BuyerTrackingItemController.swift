import Foundation
import Vapor
import Fluent
import SQLKit

struct BuyerTrackedItemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("buyerTrackingItems")
        groupedRoutes.get("packingRequest", use: getPackingRequestHandler)
        groupedRoutes.post("search", use: searchForTrackingItemsHandler)
        
        let protected = groupedRoutes.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )
        try protected.register(collection: PackingRequestController())
        protected.put(BuyerTrackingItem.parameterPath, use: updateBuyerTrackingItemPackingStateHandler)
        let buyerProtectedRoutes = groupedRoutes
            .grouped(BuyerJWTAuthenticator())
            .grouped(Buyer.guardMiddleware())
        
        buyerProtectedRoutes.get("", use: getBuyerTrackingItemsHandler)
        buyerProtectedRoutes.get("count", use: getBuyerTrackedItemCountHandler)
        buyerProtectedRoutes.delete(use: deleteMultipleItemsHandler)
        buyerProtectedRoutes.patch(use: updateMultipleItemsHandler)
        buyerProtectedRoutes.patch(BuyerTrackingItem.parameterPath, use: updateBuyerTrackingItemHandler)
    }
    
    private func updateBuyerTrackingItemPackingStateHandler(req: Request) async throws -> HTTPResponseStatus {
        let input = try req.content.decode(UpdateBuyerTrackingItemInput.self)
        guard let buyerTrackingItemID: BuyerTrackingItem.IDValue = req.parameters.get(BuyerTrackingItem.parameter) else {
            throw AppError.invalidInput
        }
        if let state = input.packingRequestState {
            let _  = try await req.buyerTrackingItems.updatePackingState(buyerTrackingItemID: buyerTrackingItemID, state: state)
        }
        return .ok
    }
    
    private func createBuyerTrackingItemHandler(req: Request) async throws -> BuyerTrackingItem {
        let buyer = try req.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        
        let input = try req.content.decode(CreateBuyerTrackingItemInput.self)
        if input.quantity == 1 || input.quantity > 10 {
            guard let packingRequest = input.packingRequest, !packingRequest.isEmpty else {
                throw AppError.invalidInput
            }
        }
        let query = BuyerTrackingItem.query(on: req.db)
            .filter(\.$buyer.$id == buyerID)
            .group(.or) { builder in
                builder.filter(\.$trackingNumber == input.trackingNumber)
                builder.filter(.sql(raw: "'\(input.trackingNumber)'::text ILIKE CONCAT('%',\(BuyerTrackingItem.schema).tracking_number)"))
                let fullRegex = "^.*(\(input.trackingNumber))$"
                builder.filter(.sql(raw: "\(BuyerTrackingItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex))
            }
        let buyerTrackingItems = try await query.all()
        return try await req.db.transaction { transactionDB in
            try await buyerTrackingItems.delete(on: transactionDB)
            let newItem = BuyerTrackingItem(
                note: input.note ?? "",
                packingRequest: input.packingRequest ?? "",
                buyerID: buyerID,
                trackingNumber: input.trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: input.quantity,
                deposit: input.deposit
            )
            try await newItem.create(on: transactionDB)
            let payload = PeriodicallyUpdateJob.Payload(refreshBuyerTrackedItemLinkView: true)
            try await req.queue.dispatch(PeriodicallyUpdateJob.self, payload)
            return newItem
        }
    }
    
    private func updateMultipleItemsHandler(request: Request) async throws -> [BuyerTrackingItemOutput] {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        
        let input = try request.content.decode(UpdateMultipleTrackingItemsInput.self)
        try await BuyerTrackingItem.query(on: request.db)
            .filter(\.$id ~~ input.trackedItemIDs)
            .filter(\.$buyer.$id == buyerID)
            .set(\.$note, to: input.sharedNote)
            .set(\.$packingRequest, to: input.sharedPackingRequest)
            .update()
        
        let allItems = try await BuyerTrackingItem.query(on: request.db)
            .filter(\.$id ~~ input.trackedItemIDs)
            .filter(\.$buyer.$id == buyerID)
            .all()
        let targetTrackingNumbers = allItems.map(\.trackingNumber)
        let allTrackingItems = try await TrackingItem.query(on: request.db)
            .filter(trackingNumbers: targetTrackingNumbers)
            .all()
        return allItems.map {
            $0.output(with: allTrackingItems)
        }
    }
    
    private func getPackingRequestHandler(request: Request) async throws -> GetPackingRequestOutput {
        let input = try request.query.decode(GetPackingRequestInput.self)
        
        guard let item = try await BuyerTrackingItemLinkView.query(on: request.db)
            .filter(\.$trackingItemTrackingNumber == input.trackingNumber)
            .with(\.$buyerTrackingItem)
            .first() else {
            return .init()
        }
        let buyerTrackingItem = item.buyerTrackingItem
        return .init(
            id: try buyerTrackingItem.requireID(),
            packingRequest: buyerTrackingItem.packingRequest,
            packingRequestState: buyerTrackingItem.packingRequestState)
    }
    
    private func searchForTrackingItemsHandler(request: Request) async throws -> [TrackingItemOutput] {
        try SearchTrackingItemsInput.validate(content: request)
        let input = try request.content.decode(SearchTrackingItemsInput.self)
        
        guard !input.validTrackingNumbers().isEmpty else {
            return []
        }
        let trackingToQuery = input.validTrackingNumbers().filter { $0.count >= 6 }
        let trackingReferences = try await TrackingItemReference.query(on: request.db)
            .filter(trackingNumbers: trackingToQuery)
            .all()
        let trackingItemIDs = try trackingReferences.removingDuplicates(by: {$0.$trackingItem.id}).compactMap{ $0.$trackingItem.id }
        let regexSuffixGroup = trackingToQuery.joined(separator: "|")
        let fullRegex = "^.*(\(regexSuffixGroup))$"
        let query =  TrackingItem.query(on: request.db)
            .group(.or) { builder in
                builder.filter(.sql(unsafeRaw: "\(TrackingItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex))
            builder.group(.and) { andBuilder in
                let fullRegex2 = "^.*(\(regexSuffixGroup))\\d{4}$"
                andBuilder.filter(.sql(unsafeRaw: "char_length(\(TrackingItem.schema).tracking_number)"), .equal, .bind(32))
                andBuilder.filter(.sql(unsafeRaw: "\(TrackingItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex2))
            }
            builder.filter(\.$id ~~ trackingItemIDs)
        }
        var foundTrackingItems = try await query
            .with(\.$trackingItemReferences)
            .with(\.$products)
            .with(\.$customers)
            .with(\.$buyerTrackingItems) {
                $0.with(\.$buyer)
            }
            .all()
        foundTrackingItems = foundTrackingItems.sorted { lhs, rhs in
            let lhsPower = lhs.status.power
            let rhsPower = rhs.status.power
            return lhsPower <= rhsPower
        }
        
        foundTrackingItems.forEach { item in
            if item.trackingNumber.count == 32 {
                item.trackingNumber.removeLast(4)
            }
            
            if let buyerProvidedTrackingNumber = trackingToQuery.first(where: {
                item.trackingNumber.hasSuffix($0)
            }) {
                item.trackingNumber = buyerProvidedTrackingNumber
            }
        }
        
        foundTrackingItems = try foundTrackingItems.grouped(by: { $0.trackingNumber.uppercased() }).compactMap {
            let values = $0.value.sorted(by: { lhs, rhs in
                let lhsPower = lhs.status.power
                let rhsPower = rhs.status.power
                return lhsPower >= rhsPower
            })

            guard let value = values.first else { return nil }
            return value
        }
        
        let foundTrackingNumbers = Set(foundTrackingItems.map(\.trackingNumber).map({ $0.uppercased() }))
        let inputSet = Set(trackingToQuery.map({ $0.uppercased() }))
        let notFoundSet = inputSet.subtracting(foundTrackingNumbers)
        let notFoundItems = notFoundSet.map { trackingNumber in
            return TrackingItemOutput(trackingNumber: trackingNumber)
        }
        var items = notFoundItems
        items.append(contentsOf: foundTrackingItems.map{ $0.output()})
        return items.sorted(by: { lhs, rhs in
            let lhsPower = lhs.status?.power
            let rhsPower = rhs.status?.power
            if lhsPower == rhsPower {
                return lhs.receivedAtUSAt ?? .distantPast < rhs.receivedAtUSAt ?? .distantFuture
            }
            return lhsPower ?? 0 < rhsPower ?? 0
        })
    }
    
    private func getBuyerTrackingItemsHandler(request: Request) async throws -> GetBuyerTrackingItemPageOutput {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.query.decode(GetBuyerTrackingItemInput.self)
        let query = BuyerTrackingItem.query(on: request.db)
            .filter(\.$buyer.$id == buyerID)

        if let searchString = input.searchString {
            
            query
                .group(.or) { builder in
                builder.filter(.sql(raw: "\(BuyerTrackingItem.schema).tracking_number"), .custom("~*"), .bind("^.*(\(searchString))$"))
                builder.filter(.sql(raw: "\(BuyerTrackingItem.schema).note"), .custom("~*"), .bind(searchString))
            }
        }
        
        query
            .join(BuyerTrackingItemLinkView.self, on: \BuyerTrackingItemLinkView.$buyerTrackingItem.$id == \BuyerTrackingItem.$id, method: .left)
            .join(TrackingItem.self, on: \BuyerTrackingItemLinkView.$trackingItem.$id == \TrackingItem.$id, method: .left)

        if !input.filteredStates.isEmpty {
            query.group(.or) { customBuilder in
                if input.filteredStates.contains(.receivedAtUSWarehouse) {
                    customBuilder.group(.and) { andBuilder in
                        andBuilder.filter(TrackingItem.self, \.$receivedAtVNAt == nil)
                        andBuilder.filter(TrackingItem.self, \.$flyingBackAt == nil)
                        andBuilder.filter(TrackingItem.self, \.$receivedAtUSAt != nil)
                    }
                }
                if input.filteredStates.contains(.flyingBack) {
                    customBuilder.group(.and) { andBuilder in
                        andBuilder.filter(TrackingItem.self, \.$receivedAtVNAt == nil)
                        andBuilder.filter(TrackingItem.self, \.$flyingBackAt != nil)
                    }
                }
                if input.filteredStates.contains(.receivedAtVNWarehouse) {
                    customBuilder.group(.and) { andBuilder in
                        andBuilder.filter(TrackingItem.self, \.$receivedAtVNAt != nil)
                    }
                }
            }
            
            if let fromDate = input.fromDate {
                query.group(.or) { builder in
                    if input.filteredStates.contains(.receivedAtUSWarehouse) {
                        builder.filter(TrackingItem.self, \.$receivedAtUSAt >= fromDate)
                    }
                    if input.filteredStates.contains(.flyingBack) {
                        builder.filter(TrackingItem.self, \.$flyingBackAt >= fromDate)
                    }
                    if input.filteredStates.contains(.receivedAtVNWarehouse) {
                        builder.filter(TrackingItem.self, \.$receivedAtVNAt >= fromDate)
                    }
                }
            }

            if let toDate = input.toDate {
                query.group(.or) { builder in
                    if input.filteredStates.contains(.receivedAtUSWarehouse) {
                        builder.filter(TrackingItem.self, \.$receivedAtUSAt < toDate)
                    }
                    if input.filteredStates.contains(.flyingBack) {
                        builder.filter(TrackingItem.self, \.$flyingBackAt < toDate)
                    }
                    if input.filteredStates.contains(.receivedAtVNWarehouse) {
                        builder.filter(TrackingItem.self, \.$receivedAtVNAt < toDate)
                    }
                }
            }
            
            query.with(\.$parentRequest)
        } else {
            let hasParentRequests = try await BuyerTrackingItem.query(on: request.db)
                .filter(\.$buyer.$id == buyerID)
                .filter(\.$parentRequest.$id != nil)
                .all()
            let ids = hasParentRequests.compactMap { $0.$parentRequest.id }
            query
                .filter(TrackingItem.self, \.$receivedAtUSAt == nil)
                .filter(\.$id !~ ids)
        }
        
        let page = try await query.with(\.$trackingItems).paginate(for: request)
        let allOutput: [BuyerTrackingItemOutput]
           
        if input.filteredStates.isEmpty {
            allOutput = page.items.map {
                $0.output(with: nil)
            }
        } else {
            allOutput = try await page.items.asyncMap {
                return try await $0.output(in: request.db)
            }
        }
        return .init(
            items: allOutput,
            metadata: .init(
                page: page.metadata.page,
                per: page.metadata.per,
                total: page.metadata.total,
                pageCount: page.metadata.pageCount,
                searchString: input.searchString,
                filteredStates: input.filteredStates,
                fromDate: input.fromDate,
                toDate: input.toDate
            )
        )
    }
    
    private func getBuyerTrackedItemCountHandler(request: Request) async throws -> BuyerTrackingItemCountOutput {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.query.decode(GetBuyerTrackingItemInput.self)
        
        let states: [TrackingItem.Status] = [.receivedAtUSWarehouse, .flyingBack, .receivedAtVNWarehouse]
        
        let counts = try await states.asyncMap { state -> Int in
            let query = BuyerTrackingItem.query(on: request.db)
                .filter(\.$buyer.$id == buyerID)
                .join(BuyerTrackingItemLinkView.self, on: \BuyerTrackingItemLinkView.$buyerTrackingItem.$id == \BuyerTrackingItem.$id, method: .left)
                .join(TrackingItem.self, on: \BuyerTrackingItemLinkView.$trackingItem.$id == \TrackingItem.$id, method: .left)
            if !input.filteredStates.isEmpty {
                if state == .receivedAtUSWarehouse {
                    query.group(.and) { andBuilder in
                        andBuilder.filter(TrackingItem.self, \.$receivedAtVNAt == nil)
                        andBuilder.filter(TrackingItem.self, \.$flyingBackAt == nil)
                        andBuilder.filter(TrackingItem.self, \.$repackingAt != nil)
                        andBuilder.filter(TrackingItem.self, \.$receivedAtUSAt != nil)
                    }
                } else if state == .flyingBack {
                    query.group(.and) { andBuilder in
                        andBuilder.filter(TrackingItem.self, \.$receivedAtVNAt == nil)
                        andBuilder.filter(TrackingItem.self, \.$flyingBackAt != nil)
                    }
                } else if state == .receivedAtVNWarehouse {
                    query.group(.and) { andBuilder in
                        andBuilder.filter(TrackingItem.self, \.$receivedAtVNAt != nil)
                    }
                }
            }
            if let searchString = input.searchString {
                query.group(.or) { builder in
                    builder.filter(.sql(raw: "\(BuyerTrackingItem.schema).tracking_number"), .custom("~*"), .bind("^.*(\(searchString))$"))
                    builder.filter(.sql(raw: "\(BuyerTrackingItem.schema).note"), .custom("~*"), .bind(searchString))
                }
            }
            if let fromDate = input.fromDate {
                query.group(.or) { builder in
                    if input.filteredStates.contains(.receivedAtUSWarehouse) {
                        builder.filter(TrackingItem.self, \.$receivedAtUSAt >= fromDate)
                    }
                    if input.filteredStates.contains(.flyingBack) {
                        builder.filter(TrackingItem.self, \.$flyingBackAt >= fromDate)
                    }
                    if input.filteredStates.contains(.receivedAtVNWarehouse) {
                        builder.filter(TrackingItem.self, \.$receivedAtVNAt >= fromDate)
                    }
                }
            }

            if let toDate = input.toDate {
                query.group(.or) { builder in
                    if input.filteredStates.contains(.receivedAtUSWarehouse) {
                        builder.filter(TrackingItem.self, \.$receivedAtUSAt < toDate)
                    }
                    if input.filteredStates.contains(.flyingBack) {
                        builder.filter(TrackingItem.self, \.$flyingBackAt < toDate)
                    }
                    if input.filteredStates.contains(.receivedAtVNWarehouse) {
                        builder.filter(TrackingItem.self, \.$receivedAtVNAt < toDate)
                    }
                }
            }
            return try await query.count()
        }
        return .init(receivedAtUSWarehouseCount: counts[0],
                     flyingBackCount: counts[1],
                     receivedAtVNWarehouseCount: counts[2])
    }
    
    private func deleteMultipleItemsHandler(request: Request) async throws -> HTTPResponseStatus {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        let input = try request.content.decode(DeleteMultipleTrackingItemsInput.self)

        try await BuyerTrackingItem.query(on: request.db)
            .filter(\.$id ~~ input.trackedItemIDs)
            .filter(\.$buyer.$id == buyerID)
            .delete()

        return .ok
    }
    
    private func updateBuyerTrackingItemHandler(request: Request) async throws -> BuyerTrackingItemOutput {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()

        guard let buyerTrackingItemID: BuyerTrackingItem.IDValue = request.parameters.get(BuyerTrackingItem.parameter) else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        let input = try request.content.decode(UpdateBuyerTrackingItemInput.self)
        
        guard let buyerTrackingItem = try await BuyerTrackingItem.query(on: request.db)
            .filter(\.$buyer.$id == buyerID)
            .with(\.$trackingItems)
            .filter(\.$id == buyerTrackingItemID)
            .first()
        else {
            throw Abort(.badRequest, reason: "Yêu cầu không hợp lệ")
        }
        return try await request.db.transaction { db in
            if let note = input.note, note != buyerTrackingItem.note {
                buyerTrackingItem.note = note
            }
            if let packingRequest = input.packingRequest, packingRequest != buyerTrackingItem.packingRequest {
                guard let trackingItem = buyerTrackingItem.trackingItems.first else {
                    throw AppError.trackingItemNotFound
                }
                guard trackingItem.returnRequestAt == nil else {
                    throw AppError.trackingItemIsInReturnRequest
                }
                
                buyerTrackingItem.packingRequest = packingRequest
            }
            try await buyerTrackingItem.save(on: request.db)
            return buyerTrackingItem.outputWithoutTrackedItem()
        }
    }
    
    
}
