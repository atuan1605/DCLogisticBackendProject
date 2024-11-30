import Foundation
import Vapor
import Fluent
import SQLKit

struct CustomerRequestController: RouteCollection {
    
    func boot(routes: any RoutesBuilder) throws {
        let grouped = routes.grouped("customerRequest")
        try grouped.register(collection: ProcessingCustomerRequestController())
        
        let protected = grouped.grouped(
            BuyerJWTAuthenticator(),
            Buyer.guardMiddleware()
        )
        
        let groupedMultiple = protected.grouped("multiple")
        groupedMultiple.post(use: createCustomerRequestsHandler)
        groupedMultiple.put(use: updateCustomerRequestsHandler)
        groupedMultiple.delete(use: deleteCustomerRequestsHandler)
        
        protected.get(use: getCustomerRequestsHandler)
        protected.get("processed", use: getProcessedCustomerRequestsHandler)
        
        let trackingItemsAuthenticatedRoutes = protected
            .grouped("trackingItems")
        trackingItemsAuthenticatedRoutes.post("extractPackingVideo", use: extractMutiplePackingVideosHandler)
        trackingItemsAuthenticatedRoutes.get(":fileID", use: getVideoHandler)
        trackingItemsAuthenticatedRoutes.get("brokenProducts", use: getBrokenProductsHandler)
        trackingItemsAuthenticatedRoutes.put("brokenProducts", use: updateMultipleBrokenProductsCheckedDateHandler)
        trackingItemsAuthenticatedRoutes.get("brokenProductsCount", use: getBrokenProductCountHandler)
        trackingItemsAuthenticatedRoutes.put("togglePublicImages", use: updateAllAccessCheckTrackingItemsWithImagesHandler)
        trackingItemsAuthenticatedRoutes.get("extractCameras", use: getTrackingVideosHandler)
       
        let trackingItemAuthenticatedRoutes = trackingItemsAuthenticatedRoutes
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())
        
        trackingItemAuthenticatedRoutes.put(use: updateAllAccessCheckTrackingWithImagesHandler)
    }
    
    private func updateMultipleBrokenProductsCheckedDateHandler(req: Request) async throws -> HTTPResponseStatus {
        let input = try req.content.decode(UpdateMultipleBrokenProductByCustomerInput.self)
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$id ~~ input.trackingItemIDs)
            .all()
        try await req.db.transaction{ transaction in
            try await trackingItems.asyncForEach { item in
                item.brokenProduct.checkedAt = Date()
                try await item.save(on: transaction)
            }
        }
        return .ok
    }
    
    private func getVideoHandler(request: Request) async throws -> ClientResponse {
        guard let fileID = request.parameters.get("fileID", as: String.self) else {
            throw AppError.invalidInput
        }
        return try await request.fileStorages.get(name: fileID, folder: "packingvideos")
    }
    
    private func getTrackingVideosHandler(req: Request) async throws -> Page<GetTrackingItemVideosByCustomerRequestOutput> {
        guard let buyer = req.auth.get(Buyer.self)
        else {
            throw AppError.buyerNotFound
        }
        let input = try req.query.decode(GetTrackingItemVideosByCustomerRequestInput.self)
        let buyerEmail = buyer.email.normalizeString()
        let query =  TrackingItem.query(on: req.db)
            .join(TrackingItemCustomer.self, on: \TrackingItemCustomer.$trackingItem.$id == \TrackingItem.$id)
            .join(Customer.self, on: \Customer.$id == \TrackingItemCustomer.$customer.$id)
            .join(Product.self, on: \Product.$trackingItem.$id == \TrackingItem.$id)
            .join(Warehouse.self, on: \Warehouse.$id == \TrackingItem.$warehouse.$id)
            .filter(Warehouse.self, \.$dvrDomain != nil)
            .filter(.sql(raw: "LOWER(TRIM(\(Customer.schema).email)) = '\(buyerEmail)'"))
            .filter(Product.self, \.$images != [])
            .with(\.$packingVideoQueues)
            .with(\.$products)
            .with(\.$customers)
            
        if let searchStrings = input.searchStrings {
            query.filter(searchStrings: searchStrings, includeAlternativeRef: true)
        }
        let page = try await query
            .sort(TrackingItem.self, \.$receivedAtUSAt, .descending)
            .paginate(for: req)

        return .init(
            items: page.items.map { $0.outputPackingVideoByCustomerRequest() },
            metadata: page.metadata
        )
    }
    
    private func getBrokenProductCountHandler(req: Request) async throws -> Int {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        guard let buyer = req.auth.get(Buyer.self)
        else {
            throw AppError.buyerNotFound
        }
        let buyerEmail = buyer.email.normalizeString()
        struct RowOutput: Content {
            var id: TrackingItem.IDValue?
        }
        let queryString: SQLQueryString = """
            select 
                ti.id as \(ident: "id")
            from \(ident: TrackingItem.schema) ti
            inner join tracking_item_customers tic on tic.tracking_item_id = ti.id
            inner join customers c on c.id = tic.customer_id
            where LOWER(TRIM(c.email)) = \(bind: buyerEmail)
            and (
            ti.broken_product_description is not null
            or 
            ti.broken_product_description <> ''
            or 
            ti.broken_product_flag_at is not null
            )        
            AND (ti.deleted_at IS NULL or ti.deleted_at > now())
            AND ti.broken_product_flag_at >= '2024-08-28'
            AND ti.broken_product_checked_at is null
        """
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(queryString).all(decoding: RowOutput.self)
            print(results)
        } catch {
            print(String(reflecting: error))
            throw error
        }
        return results.compactMap{ $0.id }.count
    }
    
    private func getBrokenProductsHandler(req: Request) async throws ->  Page<GetBrokenProductByCustomerRequestOutput> {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
        }
        guard let buyer = req.auth.get(Buyer.self)
        else {
            throw AppError.buyerNotFound
        }
        let input = try req.query.decode(GetBrokenProductByCustomerRequestInput.self)
        let buyerEmail = buyer.email.normalizeString()
        struct RowOutput: Content {
            var total: Int
            var id: TrackingItem.IDValue?
            var trackingNumber: String
            var description: String?
            var flagAt: Date?
            var feedback: TrackingItem.CustomerFeedback?
            var receivedAtUSAt: Date?
            var receivedAtVNAt: Date?
            var boxedAt: Date?
            var flyingBackAt: Date?
            var files: [String]?
            var trackingItemReferences: String?
            var customerNote: String?
            var packingRequestNote: String?
            var checkedAt: Date?
        }
        
        var queryString: SQLQueryString = """
                WITH file_data AS (
                    SELECT
                        ti.id AS ti_id,
                        UNNEST(p.images) AS image,
                        p.description AS description
                    FROM
                        tracking_items ti
                    LEFT JOIN products p ON p.tracking_item_id = ti.id
                ),
                first_buyer_note AS (
                    SELECT
                        bti.id AS bti_id,
                        bti.customer_note,
                        bti.packing_request_note
                    FROM
                        buyer_tracking_items bti
                    WHERE
                        bti.customer_note IS NOT NULL
                    or bti.packing_request_note IS NOT NULL
                    ORDER BY
                        bti.created_at ASC
                    LIMIT 1
                )
            select DISTINCT ON (ti.id)
                count(*) OVER () as \(ident: "total"),
                ti.id::uuid as \(ident: "id"),
                ti.tracking_number as \(ident: "trackingNumber"),
                ti.broken_product_description as \(ident: "description"),
                ti.broken_product_flag_at as \(ident: "flagAt"),
                ti.broken_product_checked_at as \(ident: "checkedAt"),
                ti.broken_product_customer_feedback as \(ident: "feedback"),
                ti.received_at_us_at as \(ident: "receivedAtUSAt"),
                ti.boxed_at as \(ident: "boxedAt"),
                ti.flying_back_at as \(ident: "flyingBackAt"),
                ti.received_at_vn_at as \(ident: "receivedAtVNAt"),
                fbn.customer_note as \(ident: "customerNote"),
                fbn.packing_request_note as \(ident: "packingRequestNote"),
                STRING_AGG(DISTINCT tir.tracking_number, ', ') as \(ident: "trackingItemReferences"),
                COALESCE(ARRAY_AGG(DISTINCT fd.image) FILTER (WHERE fd.image IS NOT NULL), '{}') as \(ident: "files")
                from \(ident: TrackingItem.schema) ti
                LEFT join tracking_item_customers tic on tic.tracking_item_id = ti.id
                LEFT join customers c on c.id = tic.customer_id
                LEFT join tracking_item_references tir on tir.tracking_item_id = ti.id
                LEFT JOIN file_data fd ON fd.ti_id = ti.id
                left join buyer_tracking_item_link_view btlv on btlv.tracking_item_id = ti.id
                LEFT JOIN first_buyer_note fbn ON fbn.bti_id = btlv.buyer_tracking_item_id
                where LOWER(TRIM(c.email)) = \(bind: buyerEmail)
                and (
                ti.broken_product_description is not null
                or 
                ti.broken_product_description <> ''
                or 
                ti.broken_product_flag_at is not null
                )
                AND (ti.deleted_at IS NULL or ti.deleted_at > now())
        """
        if input.isShowPendingOnly {
            let filteredCustomerFeedbackQueryString: SQLQueryString = """
            AND ti.broken_product_customer_feedback = 'none'
        """
            queryString = queryString + " " + filteredCustomerFeedbackQueryString
        }
        if let searchStrings = input.searchStrings {
            let regexSuffixGroup = searchStrings.joined(separator: "|")
            let searchTrackingNumberQueryString: SQLQueryString = """
            AND ti.tracking_number ~* '^.*(\(raw: regexSuffixGroup))$'
        """
            queryString = queryString + " " + searchTrackingNumberQueryString
        }
        let pagedQuery: SQLQueryString = """
            GROUP BY ti.id,
               fbn.customer_note,
               fbn.packing_request_note
        limit \(bind: input.per)
        offset \(bind: input.per * (input.page - 1))
        """
        queryString = queryString + " " + pagedQuery
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(queryString).all(decoding: RowOutput.self)
            print(results)
        } catch {
            print(String(reflecting: error))
            throw error
        }
        let total = results.first?.total ?? 0
        let items: [GetBrokenProductByCustomerRequestOutput] = results.map {
            return GetBrokenProductByCustomerRequestOutput(
                id: $0.id,
                trackingNumber: $0.trackingNumber,
                description: $0.description,
                flagAt: $0.flagAt,
                feedback: $0.feedback,
                receivedAtUSAt: $0.receivedAtUSAt,
                receivedAtVNAt: $0.receivedAtVNAt,
                boxedAt: $0.boxedAt,
                flyingBackAt: $0.flyingBackAt,
                files: $0.files,
                trackingItemReferences: $0.trackingItemReferences,
                customerNote: $0.customerNote,
                packingRequestNote: $0.packingRequestNote,
                checkedAt: $0.checkedAt
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
    
    private func updateAllAccessCheckTrackingItemsWithImagesHandler(req: Request) async throws -> Bool {
        guard let sqlDB = req.db as? SQLDatabase else {
            throw AppError.unknown
            
        }

        let buyer = try req.requireAuthBuyer()
        let buyerEmail = buyer.normalizeEmail()
        buyer.isPublicImages = !buyer.isPublicImages
        try await buyer.save(on: req.db)
            struct RowOutput: Content {
                var trackingID: TrackingItem.IDValue
            }
        let query: SQLQueryString = """
            select ti.id as \(ident: "trackingID") from \(ident: TrackingItem.schema) ti
            join tracking_item_customers tic on tic.tracking_item_id = ti.id
            join customers c on c.id = tic.customer_id
            where LOWER(TRIM(c.email)) = \(bind: buyerEmail)
        """
        let results: [RowOutput]
        do {
            results = try await sqlDB.raw(query).all(decoding: RowOutput.self)
            } catch {
            print(String(reflecting: error))
                    throw error
        }
        let trackingItemIDs = results.compactMap{ $0.trackingID }
        
        try await TrackingItem.query(on: req.db)
            .filter(\.$id ~~ trackingItemIDs)
            .set(\.$allAccessCheckTrackingWithImages, to: buyer.isPublicImages)
            .update()
        return buyer.isPublicImages
    }
    
    private func updateAllAccessCheckTrackingWithImagesHandler(req: Request) async throws -> Bool {
        let buyer = try req.requireAuthBuyer()
        let trackingItem = try req.requireTrackingItem()
        try await trackingItem.$customers.load(on: req.db)
        let trackingEmails = trackingItem.customers.compactMap{ $0.normalizeEmail() }
        guard trackingEmails.contains(buyer.normalizeEmail()) else {
            throw AppError.permissionDenied
        }
        trackingItem.allAccessCheckTrackingWithImages = !trackingItem.allAccessCheckTrackingWithImages
        try await trackingItem.save(on: req.db)
        return trackingItem.allAccessCheckTrackingWithImages
    }
    
    private func extractMutiplePackingVideosHandler(request: Request) async throws -> HTTPResponseStatus {
        let buyer = try request.requireAuthBuyer()
        let input = try request.content.decode(ExtractMultiplePackingVideosInput.self)
        let trackingItems = try await TrackingItem.query(on: request.db)
            .filter(\.$id ~~ input.trackingItemIDs)
            .with(\.$customers)
            .all()
        try trackingItems.forEach { item in
            let emails = item.customers.map { $0.normalizeEmail() }
            guard emails.contains(buyer.normalizeEmail()) else {
                throw AppError.permissionDenied
            }
        }
       
        var chainedTrackingItems: [TrackingItem] = []
        try await trackingItems.asyncForEach { item in
            if let chain = item.chain {
                let targetTrackingItems = try await TrackingItem.query(on: request.db)
                    .filter(\.$chain == chain)
                    .all()
                chainedTrackingItems.append(contentsOf: targetTrackingItems)
            }
        }
        
        let trackingItemWarehouses: [(trackingItemID: TrackingItem.IDValue, warehouse: Warehouse)] = try await trackingItems.asyncMap{ item in
            guard let warehouse = try await item.$warehouse.get(on: request.db), warehouse.dvrAccount != nil, warehouse.dvrDomain != nil, warehouse.dvrPassword != nil  else {
                throw AppError.cameraNotSupportInThisWarehouse
            }
            let trackingID = try item.requireID()
            return (trackingID, warehouse)
        }
        
        let videoDownloadingJobs: [VideoDownloadingJob] = try await trackingItems.asyncMap { item in
            try await VideoDownloadingJob.query(on: request.db)
                .filter(\.$trackingItem.$id == item.requireID())
                .delete()
            
            let trackingID = try item.requireID()
            let trackingItemIDs = try chainedTrackingItems
                .filter{ $0.chain == item.chain}
                .compactMap{ try $0.requireID() }
                .removingDuplicates()
            
            let cameraDetails = try await TrackingCameraDetail.query(on: request.db)
                .filter(\.$step == .pack)
                .filter(\.$trackingItem.$id ~~ trackingItemIDs)
                .sort(\.$recordFinishAt, .descending)
                .all()
            guard let lastestCameraDetail = cameraDetails.first, let currentCameraDetail = cameraDetails.filter({ $0.$trackingItem.id == trackingID }).first else {
                throw AppError.cannotExtractPackingVideo
            }
            let cameraID = currentCameraDetail.$camera.id
            let startDate = currentCameraDetail.createdAt?.addingTimeInterval(-2 * 60)
            let endDate = lastestCameraDetail.recordFinishAt
            if let startDate = startDate {
                var finalEndDate = endDate ?? startDate.addingTimeInterval(4 * 60)
                if finalEndDate <= startDate {
                    finalEndDate = startDate.addingTimeInterval(4 * 60)
                }
                let targetPayload: VideoDownloadingJob.Payload = .init(trackingID: trackingID, startDate: startDate, endDate: finalEndDate, channel: cameraID)
                let videoDownloadingJob = VideoDownloadingJob.init(trackingID: trackingID,payload: targetPayload)
                try await videoDownloadingJob.save(on: request.db)
                return videoDownloadingJob
            }
            return VideoDownloadingJob.init()
        }
        
        try await videoDownloadingJobs.asyncForEach { videoJob in
            let trackingWarehouse = trackingItemWarehouses.filter{ $0.trackingItemID == videoJob.$trackingItem.id }.first
            if let trackingWarehouse = trackingWarehouse {
                let warehouse = trackingWarehouse.warehouse
                try await request.queue.dispatch(DCWebPackingVideoJob.self, .init(
                    warehouse: warehouse,
                    videoDownloadingJobID: videoJob.requireID())
                )
            }
        }
        return .ok
    }
    
    private func createCustomerRequestsHandler(request: Request) async throws -> [BuyerTrackingItemOutput] {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        var input = try request.content.decode(CreateMultipleBuyerTrackingItemInput.self)
        
        //Tạm thời dùng trường này để giới hạn tài khoản được phép tạo yêu cầu đặc biệt
        if input.requestType == .specialRequest {
            if !buyer.isAdmin && buyer.packingRequestLeft < 1 {
                throw AppError.notEnoughPackingRequestLeft
            }
        }
        
        guard input.isValid() && !input.validTrackingNumbers().isEmpty else {
            throw AppError.invalidInput
        }
        
//        let availableDeposit = buyer.availableDeposit
//        if input.requestType == .specialRequest {
//            guard let deposit = input.deposit, availableDeposit > 0 && deposit <= availableDeposit else {
//                throw AppError.dontHaveEnoughDepositToProcess
//            }
//        }
        
        var inputTrackingNumbers = input.trackingNumbers
        // Kiểm tra nếu đã được tạo yêu cầu thì ko cho tạo thêm nữa
        let buyerTrackingItems = try await BuyerTrackingItem.query(on: request.db)
            .filter(trackingNumbers: inputTrackingNumbers)
            .filter(\.$buyer.$id == buyerID)
            .all()
        
        if !buyerTrackingItems.isEmpty {
            let existedBuyerTrackingItemIds = buyerTrackingItems.map { $0.trackingNumber.suffix(12) }
            inputTrackingNumbers = inputTrackingNumbers.filter { !existedBuyerTrackingItemIds.contains($0.suffix(12)) }
            input.trackingNumbers = inputTrackingNumbers
        }
        
        if input.trackingNumbers.count > 0 {
            var trackingItems: [TrackingItem] = []
            let existingTrackingItems = try await TrackingItem.query(on: request.db)
                .filter(trackingNumbers: input.trackingNumbers)
                .with(\.$products)
                .all()
            trackingItems = existingTrackingItems
            var grouped: [String: [TrackingItemReference]] = [:]
            if existingTrackingItems.count != input.trackingNumbers.count {
                let existingTrackingNumbers = trackingItems.map { $0.trackingNumber }
                let remainTrackingNumbers = input.trackingNumbers.filter { !existingTrackingNumbers.contains($0) }
                let trackingItemReferences = try await TrackingItemReference.query(on: request.db)
                    .filter(trackingNumbers: remainTrackingNumbers)
                    .with(\.$trackingItem) {
                        $0.with(\.$products)
                    }
                    .all()
                
                grouped = try trackingItemReferences.grouped(by: \.trackingItem.trackingNumber)
                
                let additionalTrackingItems = trackingItemReferences.map { $0.trackingItem }
                trackingItems.append(contentsOf: additionalTrackingItems)
            }
            let removedDuplicateTrackingItems = try trackingItems
                .removingDuplicates(by: \.id)
            
            //Kiểm tra tracking nào đang bị hold thì không cho tạo yêu cầu
            let holdingTrackingItems = removedDuplicateTrackingItems.filter { $0.holdState == .holding || $0.returnRequestAt != nil }
            let holdingTrackingNumbers = holdingTrackingItems
                    .map { $0.trackingNumber }
                    .map { trackingNumber in
                        if let trackingItemReference = grouped[trackingNumber]?.first {
                            return trackingItemReference.trackingNumber
                        }
                        return trackingNumber
                    }
            if !holdingTrackingNumbers.isEmpty {
                throw AppWithOutputError.trackingItemsAreBeingHold(holdingTrackingNumbers)
            }

            //Kiểm tra nếu đã có trackingItems được đóng hàng thì ko cho tạo yêu cầu
            if input.requestType == .quantityCheck
                || input.requestType == .specialRequest
                || input.requestType == .holdTracking
                || input.requestType == .returnTracking {
                let boxedTrackingItems = removedDuplicateTrackingItems
                    .filter { $0.status == .boxed }
                
                if !boxedTrackingItems.isEmpty {
                    let boxedTrackingNumbers = boxedTrackingItems
                        .map { $0.trackingNumber }
                        .map { trackingNumber in
                            if let trackingItemReference = grouped[trackingNumber]?.first {
                                return trackingItemReference.trackingNumber
                            }
                            return trackingNumber
                        }
                    throw AppWithOutputError.trackingItemsAreAlreadyBoxed(boxedTrackingNumbers)
                }
                
                //Kiểm tra nếu có trackingItem đã có ảnh và khách đang yêu cầu kiểm tra số lượng hoặc yêu cầu đặc biệt thì không cho tạo yêu cầu
                if input.requestType == .quantityCheck || input.requestType == .specialRequest {
                    let repackedTrackingItems = removedDuplicateTrackingItems.filter { trackingItem in
                        let products = trackingItem.products
                        let images = products.compactMap { $0.images }.flatMap { $0 }
                        return !images.isEmpty
                    }
                    if !repackedTrackingItems.isEmpty {
                        let repackedTrackingNumbers = repackedTrackingItems
                            .map { $0.trackingNumber }
                            .map { trackingNumber in
                                if let trackingItemReference = grouped[trackingNumber]?.first {
                                    return trackingItemReference.trackingNumber
                                }
                                return trackingNumber
                            }
                        throw AppWithOutputError.trackingItemsAreAlreadyRepacked(repackedTrackingNumbers)
                    }
                }
                
            }
            
            if input.requestType == .camera {
                let removedDuplicateTrackingItemIDs = removedDuplicateTrackingItems.compactMap { $0.id }
                let pivot = try await TrackingItemCustomer.query(on: request.db)
                    .filter(\.$trackingItem.$id ~~ removedDuplicateTrackingItemIDs)
                    .with(\.$trackingItem) {
                        $0.with(\.$packingVideoQueues)
                    }
                    .with(\.$customer)
                    .all()
                //Kiểm tra nếu input có tracking nào không có khách hàng thì throw lỗi
                let pivotTrackingItems = pivot.map(\.trackingItem)
                let pivotTrackingIDs = pivotTrackingItems.map(\.id)
                let intersectionTrackingIDs = removedDuplicateTrackingItemIDs.filter { !pivotTrackingIDs.contains($0) }
                guard intersectionTrackingIDs.count == 0 else {
                    let noCustomerTrackingItems = try removedDuplicateTrackingItems.filter { try intersectionTrackingIDs.contains($0.requireID()) }
                    let noCustomerTrackingNumbers = noCustomerTrackingItems
                        .map { $0.trackingNumber }
                        .map { trackingNumber in
                            if let trackingItemReference = grouped[trackingNumber]?.first {
                                return trackingItemReference.trackingNumber
                            }
                            return trackingNumber
                        }
                    throw AppWithOutputError.trackingItemsDontHaveCustomers(noCustomerTrackingNumbers)
                }
            }
            
            let newBuyerTrackingItems = input.toBuyerTrackingItems(buyerID: buyerID)
            let createdBuyerTrackingItems = try await request.db.transaction { transaction in
                if input.requestType == .specialRequest {
                    if !buyer.isAdmin {
                        var updatedPackingRequestLeft = buyer.packingRequestLeft - newBuyerTrackingItems.count
                        guard updatedPackingRequestLeft >= 0 else {
                            throw AppError.notEnoughPackingRequestLeft
                        }
                        buyer.packingRequestLeft = updatedPackingRequestLeft
                        try await buyer.save(on: transaction)
                    }
                }
                try await newBuyerTrackingItems.create(on: transaction)
                return newBuyerTrackingItems
            }
            let buyerTrackingItemIDs = try createdBuyerTrackingItems.map { try $0.requireID() }
            buyerTrackingItemIDs.forEach { id in
                request.appendBuyerAction(.createBuyerTrackingItem(
                    buyerTrackingItemID: id,
                    requestType: input.requestType,
                    note: input.note,
                    packingRequest: input.packingRequest,
                    quantity: input.quantity,
                    deposit: input.deposit))
            }
            return createdBuyerTrackingItems.map { $0.output() }
        }
        return []
    }
    
    private func updateCustomerRequestsHandler(request: Request) async throws -> [BuyerTrackingItemOutput] {
        let input = try request.content.decode(UpdateMultipleBuyerTrackingItemInput.self)
        let updatedBuyerTrackingItems = try await request.db.transaction { transaction in
            let buyerTrackingItems = try await BuyerTrackingItem.query(on: transaction)
                .filter(\.$id ~~ input.buyerTrackingItemIDs)
                .all()
            try await buyerTrackingItems.asyncForEach { buyerTrackingItem in
                if let sharedNote = input.sharedNote, buyerTrackingItem.customerNote != sharedNote {
                    buyerTrackingItem.customerNote = sharedNote
                }
                if let sharedPackingRequest = input.sharedPackingRequest, buyerTrackingItem.packingRequest != sharedPackingRequest {
                    buyerTrackingItem.packingRequest = sharedPackingRequest
                }
                if buyerTrackingItem.hasChanges {
                    try await buyerTrackingItem.save(on: transaction)

                }
            }
            return buyerTrackingItems
        }
        try updatedBuyerTrackingItems.forEach { buyerTrackingItem in
            try request.appendBuyerAction(.updateBuyerTrackingItem(buyerTrackingItemID: buyerTrackingItem.requireID(), note: buyerTrackingItem.note))
        }
        
        return updatedBuyerTrackingItems.map { $0.output() }
    }
    
    private func deleteCustomerRequestsHandler(request: Request) async throws -> HTTPResponseStatus {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.content.decode(DeleteMultipleBuyerTrackingItemInput.self)
        if input.buyerTrackingItemIDs.count > 0 {
            let buyerTrackingItems = try await BuyerTrackingItem.query(on: request.db)
                .filter(\.$id ~~ input.buyerTrackingItemIDs)
                .all()
            let buyerTrackingNumbers = buyerTrackingItems.map { $0.trackingNumber }
            let existedTrackingItemsReferences = try await TrackingItemReference.query(on: request.db)
                .filter(trackingNumbers: buyerTrackingNumbers)
                .join(TrackingItem.self, on: \TrackingItem.$id == \TrackingItemReference.$trackingItem.$id)
                .join(Product.self, on: \Product.$trackingItem.$id == \TrackingItem.$id)
                .filter(Product.self, \.$images != [])
                .all()
            let trackingItemIDsByReferences = existedTrackingItemsReferences.compactMap{ $0.$trackingItem.id }.removingDuplicates()
            let existedTrackingItems = try await TrackingItem.query(on: request.db)
                .filter(trackingNumbers: buyerTrackingNumbers)
                .join(Product.self, on: \Product.$trackingItem.$id == \TrackingItem.$id)
                .group(.or) { orBuilder in
                    orBuilder.filter(Product.self, \.$images != [])
                    orBuilder.filter(TrackingItem.self, \.$id ~~ trackingItemIDsByReferences)
                }
                .all()
           
            
            let buyerIDs = buyerTrackingItems.compactMap { $0.$buyer.id }.removingDuplicates()
            if buyerIDs.count > 1 || buyerIDs.first != buyerID {
                throw AppError.invalidInput
            }
            try await request.db.transaction { transaction in
                if !buyer.isAdmin {
                    var refundablePackingRequestLeft = 0
                    buyerTrackingItems.forEach { item in
                        let trackingItemsCount = existedTrackingItems.filter{ $0.trackingNumber.suffix(item.trackingNumber.count) == item.trackingNumber }.count
                        if trackingItemsCount == 0 {
                            refundablePackingRequestLeft += 1
                        }
                    }
                    buyer.packingRequestLeft = buyer.packingRequestLeft + refundablePackingRequestLeft
                    try await buyer.save(on: transaction)
                }
                try await buyerTrackingItems.delete(on: transaction)
            }
            input.buyerTrackingItemIDs.forEach { id in
                request.appendBuyerAction(.deleteBuyerTrackingItem(buyerTrackingItemID: id))
            }
        }
        return .ok
    }
    
    private func getCustomerRequestsHandler(request: Request) async throws -> Page<BuyerTrackingItemOutput> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let input = try request.query.decode(GetCustomerRequestInput.self)
        let requestType = input.requestType
        let query = BuyerTrackingItem.query(on: request.db)
            .join(BuyerTrackingItemLinkView.self, on: \BuyerTrackingItemLinkView.$buyerTrackingItem.$id == \BuyerTrackingItem.$id, method: .left)
            .join(TrackingItem.self, on: \BuyerTrackingItemLinkView.$trackingItem.$id == \TrackingItem.$id, method: .left)
            .filter(\.$buyer.$id == buyerID)
            .filter(\.$requestType == requestType)
        if requestType == .trackingStatusCheck {
            query.filter(BuyerTrackingItemLinkView.self, \.$id == .null)
        }
        else if requestType == .quantityCheck {
            query.filter(\.$actualQuantity == nil)
            
        } else if requestType == .specialRequest {
            query.group(.and) {
                $0.filter(\.$actualQuantity == nil)
                $0.filter(\.$packingRequestState == nil)
            }
        } else if requestType == .holdTracking || requestType == .returnTracking {
            query
                .with(\.$trackingItems)
        } else if requestType == .camera {
            query
                .with(\.$trackingItems) {
                    $0.with(\.$products)
                }
        }
        let page = try await query
            .sort(\.$createdAt, .descending)
            .paginate(for: request)
        return .init(
            items: page.items.map { $0.output() },
            metadata: page.metadata
        )
    }
    
    private func getProcessedCustomerRequestsHandler(request: Request) async throws -> Page<BuyerTrackingItemLinkViewOutput> {
        let buyer = try request.auth.require(Buyer.self)
        let buyerID = try buyer.requireID()
        let buyerEmail = buyer.email
        let input = try request.query.decode(GetProcessedCustomerRequestInput.self)
        let requestType = input.requestType
        let query = BuyerTrackingItemLinkView.query(on: request.db)
            .join(BuyerTrackingItem.self, on: \BuyerTrackingItem.$id == \BuyerTrackingItemLinkView.$buyerTrackingItem.$id)
            .join(TrackingItem.self, on: \TrackingItem.$id == \BuyerTrackingItemLinkView.$trackingItem.$id)
            .filter(BuyerTrackingItem.self, \.$buyer.$id == buyerID)
            .filter(BuyerTrackingItem.self, \.$requestType == requestType)
        
        if requestType == .quantityCheck {
            query.filter(BuyerTrackingItem.self, \.$actualQuantity != nil)
        } else if requestType == .specialRequest {
            query.group(.or) {
                $0.filter(BuyerTrackingItem.self, \.$actualQuantity != nil)
                $0.filter(BuyerTrackingItem.self, \.$packingRequestState != nil)
            }
        }
        
        if let trackingNumbers = input.trackingNumbers {
            var trackingItemIDs: [TrackingItem.IDValue] = []
            let trackingItems = try await TrackingItem.query(on: request.db)
                .filter(trackingNumbers: trackingNumbers)
                .field(\.$id)
                .all()
            trackingItemIDs = try trackingItems.map { try $0.requireID() }
            if trackingItems.count != trackingNumbers.count {
                let existingTrackingNumbers = trackingItems.map { $0.trackingNumber }
                let remainTrackingNumbers = trackingNumbers.filter { !existingTrackingNumbers.contains($0) }
                let trackingItemReferences = try await TrackingItemReference.query(on: request.db)
                    .filter(trackingNumbers: remainTrackingNumbers)
                    .with(\.$trackingItem)
                    .all()
                let additionalTrackingItemIDs = try trackingItemReferences.map { $0.trackingItem }.map { try $0.requireID() }
                trackingItemIDs.append(contentsOf: additionalTrackingItemIDs)
            }
            trackingItemIDs = trackingItemIDs.removingDuplicates()
            query
                .filter(TrackingItem.self, \.$id ~~ trackingItemIDs)
        }
        if let fromDate = input.fromDate, let toDate = input.toDate {
            query.filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
                .filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"), .lessThanOrEqual, .bind(toDate))
        }
        query
            .with(\.$buyerTrackingItem)
            .with(\.$trackingItem) {
                $0.with(\.$products)
                $0.with(\.$trackingItemReferences)
                $0.with(\.$customers)
        }
        
        let page = try await query
            .sort(TrackingItem.self, \.$createdAt, .descending)
            .paginate(for: request)
        return .init(
            items: page.items.map { $0.output(currentBuyerEmail: buyerEmail) },
            metadata: page.metadata)
    }
}
