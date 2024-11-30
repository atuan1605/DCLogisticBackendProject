import Foundation
import Vapor
import Fluent
import FluentPostgresDriver

struct TrackingRepackedAtVNController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.group(ScopeCheckMiddleware(requiredScope: [.vnInventory, .updateTrackingItems])) {
            let groupedRoutes = $0.grouped("repackedAtVN")
//            groupedRoutes.get(use: getRepackedAtVNByCustomer)
//            groupedRoutes.get("customers", use: getPackBoxesByCustomersHandler)
            let customerRoutes = groupedRoutes.grouped(":customerID", "packBoxes")
            
            customerRoutes.get(use: getPackBoxesHandler)
            customerRoutes.post(use: createPackboxHandler)
            customerRoutes.post("toCommited", use: updatePackBoxToCommitedHandler)
            
            let packBoxRoutes = customerRoutes
                .grouped(PackBox.parameterPath)
                .grouped(PackBoxIdentifyingMiddleware())
            
            packBoxRoutes.get(use: getPackBoxHandler)
            packBoxRoutes.put(use: updatePackBoxHandler)
            
            let trackingItemsRoutes = packBoxRoutes.grouped("trackingItems")
//            trackingItemsRoutes.post(use: addTrackingItemToPackBoxHandler)
            let protected = trackingItemsRoutes
                .grouped(TrackingItem.parameterPath)
                .grouped(TrackingItemIdentifyingMiddleware())
            protected.delete(use: deleteTrackingItemHandler)
        }
    }
    
//    private func getRepackedAtVNByCustomer(request: Request) async throws -> [RepackedAtVNByCustomerOutput] {
//        try GetCustomerIDBySearchInput.validate(query: request)
//        let input = try request.query.decode(GetCustomerIDBySearchInput.self)
//
//
//        let query = Customer.query(on: request.db)
//            .join(children: \.$trackingItemCustomers)
////            .join(TrackingItem.self, on: \TrackingItem.$customer.$id == \Customer.$id)
//            .filter(TrackingItem.self, \.$deliveredAt == nil)
//            .filter(TrackingItem.self, \.$packBoxCommitedAt == nil)
//            .group(.or) { builder in
//                builder.filter(TrackingItem.self, \.$packedAtVNAt != nil)
//                builder.group(.and) { andBuilder in
//                    andBuilder.filter(TrackingItem.self, \.$packedAtVNAt == nil)
//                    andBuilder.filter(TrackingItem.self, \.$receivedAtVNAt != nil)
//                }
//            }
//            .with(\.$packBoxes) {
//                $0.with(\.$trackingItems)
//            }
//            .unique()
//            .fields(for: Customer.self)
//        if let customerID = input.customerID {
//            query.filter(Customer.self, \.$id == customerID)
//        }
//
//        let customers = try await query
//            .sort(\.$customerCode, .ascending)
//            .all()
//        return customers.map { $0.toListOutput() }
//    }
    
    private func getPackBoxesHandler(req: Request) async throws -> GetPackBoxesListOutput {
        guard let customerID = req.parameters.get("customerID", as: Customer.IDValue.self) 
        else {
            throw AppError.invalidInput
        }
        let packBoxes: [PackBox] = try await PackBox.query(on: req.db)
            .filter(\.$customer.$id == customerID)
            .filter(\.$commitedAt == nil)
            .all()
        
        return try await GetPackBoxesListOutput(items: packBoxes, on: req.db)
    }
    
    private func createPackboxHandler(req: Request) async throws -> PackBoxOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .deliveries) else {
            throw AppError.invalidScope
        }
        guard let customerID: Customer.IDValue = req.parameters.get("customerID", as: Customer.IDValue.self),
            let customer = try await Customer.find(customerID, on: req.db)
        else {
            throw AppError.invalidInput
        }
        let packBoxesCount = try await PackBox.query(on: req.db)
            .filter(\.$customer.$id == customerID)
            .filter(\.$commitedAt == nil)
            .count()
        let newPackBox = PackBox(
            name:"\(packBoxesCount + 1)",
            weight: 0,
            customerCode: customer.customerCode,
            customerID: customerID
        )
    
        try await newPackBox.save(on: req.db)
        try req.appendUserAction(.createPackBox(packBoxID: newPackBox.requireID()))
        return try await newPackBox.toOutput(on: req.db)
    }
    
    private func getPackBoxHandler(req: Request) async throws -> PackBoxOutput {
        let packBox = try req.requireUncommitedPackBox()
        try await packBox.$trackingItems.load(on: req.db)
        return try await packBox.toOutput(on: req.db)
    }
    
    private func updatePackBoxHandler(req: Request) async throws -> PackBoxOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .deliveries) else {
            throw AppError.invalidScope
        }
        let input = try req.content.decode(UpdatePackBoxInput.self)
        
        let packBox = try req.requireUncommitedPackBox()
        let packBoxID = try packBox.requireID()
        
        if let weight = input.weight, weight != packBox.weight {
            packBox.weight = weight
            req.appendUserAction(.assignPackBoxWeight(packBoxID: packBoxID, weight: weight))
        }
        if let name = input.name, name != packBox.name {
            packBox.name = name
            req.appendUserAction(.assignPackBoxName(packBoxID: packBoxID, name: name))
        }
        if packBox.hasChanges {
            try await packBox.save(on: req.db)
        }
        return try await packBox.toOutput(on: req.db)
    }
    
//    private func addTrackingItemToPackBoxHandler(req: Request) async throws -> [TrackingItemOutput] {
//        let user = try req.requireAuthUser()
//        guard user.hasRequiredScope(for: .deliveries) else {
//            throw AppError.invalidScope
//        }
//        let packBox = try req.requireUncommitedPackBox()
//
//        let input = try req.content.decode(AddTrackingItemToPackBoxInput.self)
//
//        let packBoxID = try packBox.requireID()
//        guard let customerID = req.parameters.get("customerID", as: Customer.IDValue.self)
//        else {
//            throw AppError.invalidInput
//        }
//
//        guard let trackingItem = try await TrackingItem.query(on: req.db)
//            .filter(\.$id == input.trackingItemID)
//            .first()
//        else {
//            throw AppError.trackingItemNotFound
//        }
//
//        if let oldCustomerID = trackingItem.customer?.id {
//            guard customerID == oldCustomerID && packBox.customer.id == oldCustomerID else {
//                throw AppError.customerCodeDoesntMatch
//            }
//        }
//
//        guard trackingItem.$packBox.id == nil else {
//            throw AppError.itemAlreadyExists
//        }
//
//        let updatedTrackingItems = try await req.db.transaction{ transaction in
//            var targetTrackingItems = [trackingItem]
//            if let chain = trackingItem.chain {
//                targetTrackingItems = try await TrackingItem.query(on: transaction)
//                    .filter(\.$chain == chain)
//                    .all()
//            }
//            try await targetTrackingItems.asyncForEach{ item in
//                item.$packBox.id = packBoxID
//                try req.appendUserAction(.assignPackBox(trackingItemID: item.requireID(), packBoxID: packBoxID))
//                try req.appendUserAction(.assignTrackingItemStatus(trackingItemID: item.requireID(), status: .packedAtVN))
//                do {
//                    if let payload = try item.moveToStatus(to: .packedAtVN) {
//                        try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
//                    }
//                } catch AppError.statusUpdateInvalid{
//                    throw AppError.thereIsItemInChainThatHasNotBeenUpdated
//                } catch {
//                    throw error
//                }
//
//                try await item.save(on: transaction)
//            }
//
//            return targetTrackingItems
//        }
//        return updatedTrackingItems.map {
//            $0.output()
//        }
//    }
    
    private func deleteTrackingItemHandler(req: Request) async throws -> Int {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .deliveries) else {
            throw AppError.invalidScope
        }
        let packBox = try req.requireUncommitedPackBox()
        
        guard
            let trackingItemID = req.parameters.get(TrackingItem.parameter, as: TrackingItem.IDValue.self),
            let trackingItem = try await TrackingItem.find(trackingItemID, on: req.db)
        else {
            throw AppError.trackingItemNotFound
        }
        
        try await req.db.transaction { db in
            let items = try await TrackingItem.query(on: db)
                .filter(\.$chain == trackingItem.chain)
                .all()
            
            try await items.asyncForEach {
                $0.$packBox.id = nil
                try req.appendUserAction(.assignPackBox(trackingItemID: $0.requireID(), packBoxID: nil))
                try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: $0.trackingNumber, trackingItemID: $0.requireID(), status: .receivedAtVNWarehouse))
                _ = try await $0.moveToStatus(to: .receivedAtVNWarehouse, database: db)
            }
            
            try await items.asyncForEach {
                try await $0.save(on: db)
            }
        }
        
        let itemCount = try await packBox.$trackingItems.query(on: req.db).count()
        return itemCount
    }
    
    private func updatePackBoxToCommitedHandler(req: Request) async throws -> GetPackBoxesListOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .deliveries) else {
            throw AppError.invalidScope
        }
        guard let customerID = req.parameters.get("customerID", as: Customer.IDValue.self)
        else {
            throw AppError.invalidInput
        }
        
        let input = try req.content.decode(PutPackBoxToCommitedInput.self)
        
        let targetPackBoxes = try await PackBox.query(on: req.db)
            .filter(\.$id ~~ input.packBoxIDs)
            .filter(\.$commitedAt == nil)
            .all()
        let targetPackBoxesID = try targetPackBoxes.map{ try $0.requireID() }
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$packBox.$id ~~ targetPackBoxesID)
            .all()
        
        guard try await targetPackBoxes.asyncMap ({
            try await $0.$trackingItems.query(on: req.db).count() }).allSatisfy({ $0 > 0 }) else {
            throw AppError.packBoxIsEmpty
        }
        try await req.db.transaction { db in
            let deliveryItem = try await Delivery.query(on: db)
                .filter(\.$customer.$id == customerID)
                .filter(\.$commitedAt == nil)
                .first() ?? Delivery(name: "Default", customerID: customerID)

            try await deliveryItem.save(on: db)
            let today = Date()
            try await targetPackBoxes.asyncForEach {
                $0.commitedAt = today
                $0.$delivery.id = try deliveryItem.requireID()
                try req.appendUserAction(.assignDelivery(packBoxID: $0.requireID(), deliveryID: deliveryItem.requireID()))
                try req.appendUserAction(.commitPackBox(packBoxID: $0.requireID()))
                try await $0.save(on: db)
            }
            
            
            try await trackingItems.asyncForEach {
                if let payload = try await $0.moveToStatus(to: .packBoxCommitted, database: db) {
                    try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                }
                try await $0.save(on: db)
                try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: $0.trackingNumber, trackingItemID: $0.requireID(), status: .packBoxCommitted))
            }
        }
        let packBoxes = try await PackBox.query(on: req.db)
            .filter(\.$customer.$id == customerID)
            .filter(\.$commitedAt == nil)
            .all()
        
        return try await GetPackBoxesListOutput(items: packBoxes, on: req.db)
    }
    
//    private func getPackBoxesByCustomersHandler(req: Request) async throws -> [GetCustomersPackboxOutput] {
//        let customers = try await Customer.query(on: req.db)
//            .join(TrackingItem.self, on: \TrackingItem.$customer.$id == \Customer.$id)
//            .filter(TrackingItem.self, \.$receivedAtVNAt != nil)
//            .filter(TrackingItem.self, \.$packedAtVNAt != nil)
//            .filter(TrackingItem.self, \.$deliveredAt == nil)
//            .filter(TrackingItem.self, \.$packBoxCommitedAt == nil)
//            .unique()
//            .fields(for: Customer.self)
//            .all()
//        return try await customers.asyncMap({ try await $0.toPackBoxesOutput(on: req)
//        })
//    }
}

extension QueryBuilder where Model: TrackingItem {
    @discardableResult func filterReceivedAtVN() -> Self {
        return self
            .group(.and) { andBuilder in
                andBuilder.filter(\.$deliveredAt == nil)
                andBuilder.filter(\.$packBoxCommitedAt == nil)
                andBuilder.filter(\.$packedAtVNAt == nil)
                andBuilder.filter(\.$receivedAtVNAt != nil)
            }
    }

    @discardableResult func filterPackedAtVN() -> Self {
        return self
            .group(.and) { andBuilder in
                andBuilder.filter(\.$deliveredAt == nil)
                andBuilder.filter(\.$packBoxCommitedAt == nil)
                andBuilder.filter(\.$packedAtVNAt != nil)
            }
    }
}
