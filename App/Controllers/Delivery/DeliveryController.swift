import Vapor
import Foundation
import Fluent
import FluentPostgresDriver

struct DeliveryController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("deliveries")
        
        let protected = groupedRoutes.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )
        let scopeRoute = protected .grouped(ScopeCheckMiddleware(requiredScope: [.deliveryList]))
        scopeRoute.get(use: getDeliveryAtVNByCustomer)
        
        let deliveryRoutes = scopeRoute
            .grouped(Delivery.parameterPath)
            .grouped(DeliveryIdentifyingMiddleware())
        
        deliveryRoutes.delete(use: deleteDeliveryHandler)
        deliveryRoutes.post("commit", use: commitDeliveryHandler)
        
        let packBoxesRoutes = deliveryRoutes.grouped("packBoxes")
        packBoxesRoutes.get(use: getPackBoxesHandler)
        packBoxesRoutes.patch(use: updateDeliveryHandler)
        
        let packBoxRoutes = packBoxesRoutes
            .grouped(PackBox.parameterPath)
            .grouped(PackBoxIdentifyingMiddleware())
        
        packBoxRoutes.get(use: getPackBoxHandler)
        packBoxRoutes.post("uncommit", use: updatePackBoxToUncommitedHandler)
        
    }
    
    private func getDeliveryAtVNByCustomer(req: Request) async throws -> [GetDeliveryListOutput] {
        try GetCustomerIDBySearchInput.validate(query: req)
        let input = try req.query.decode(GetCustomerIDBySearchInput.self)
        let query = Delivery.query(on: req.db)
            .filter(\.$commitedAt == nil)
        
        if let customerID = input.customerID {
            query.filter(.sql(raw: "\(Delivery.schema).customer_id"), .equal, .bind("%\(customerID)%"))
        }

        let deliverItems = try await query
            .all()

        return try await deliverItems.asyncMap {
            try await $0.toListOutput(on: req.db)
        }
    }
    
    private func getPackBoxesHandler(req: Request) async throws -> DeliveryOutput {
        let deliveryItem = try req.requireDelivery()
        return try await deliveryItem.toOutput(on: req.db)
    }
    
    private func getPackBoxHandler(req: Request) async throws -> PackBoxOutput {
        let packBox = try req.requireCommitedPackBox()
        try await packBox.$trackingItems.load(on: req.db)
        return try await packBox.toOutput(on: req.db)
    }
    
    private func deleteDeliveryHandler(req: Request) async throws -> HTTPResponseStatus {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .deliveries) else {
            throw AppError.invalidScope
        }
        let delivery = try req.requireDelivery()
        let deliveryID = try delivery.requireID()
        
        let packBoxes = try await PackBox.query(on: req.db)
            .filter(\.$delivery.$id == deliveryID)
            .filter(\.$commitedAt != nil)
            .all()
        let packBoxesIDs = try packBoxes.map { try $0.requireID()}
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$packBox.$id ~~ packBoxesIDs)
            .all()
        
        try await req.db.transaction { db in
            try await packBoxes.asyncForEach {
                $0.$delivery.id = nil
                $0.commitedAt = nil
                try req.appendUserAction(.assignDelivery(packBoxID: $0.requireID(), deliveryID: nil))
                try req.appendUserAction(.uncommitPackBox(packBoxID: $0.requireID()))
                try await $0.save(on: db)
            }
            
            try await trackingItems.asyncForEach {
                if let payload = try await $0.moveToStatus(to: .packedAtVN, database: db) {
                    try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                }
                try await $0.save(on: db)
                try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: $0.trackingNumber, trackingItemID: $0.requireID(), status: .packedAtVN))
            }
            try await delivery.delete(on: db)
            try req.appendUserAction(.deleteDelivery(deliveryID: delivery.requireID()))
        }
        return .ok
    }
    
    private func updatePackBoxToUncommitedHandler(req: Request) async throws -> DeliveryOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .deliveries) else {
            throw AppError.invalidScope
        }
        let deliveryItem = try req.requireDelivery()
        let deliveryID = try deliveryItem.requireID()
        let packBox = try req.requireCommitedPackBox()
        let packBoxID = try packBox.requireID()
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$packBox.$id == packBoxID)
            .all()
        
        
        
        try await req.db.transaction { db in
            packBox.commitedAt = nil
            packBox.$delivery.id = nil
            try req.appendUserAction(.assignDelivery(packBoxID: packBox.requireID(), deliveryID: nil))
            try await packBox.save(on: db)

            try await trackingItems.asyncForEach {
                if let payload = try await $0.moveToStatus(to: .packedAtVN, database: db) {
                    try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                }
                try await $0.save(on: db)
                try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: $0.trackingNumber, trackingItemID: $0.requireID(), status: .packedAtVN))
            }
            
            let packBoxesCount = try await PackBox.query(on: db)
                .filter(\.$delivery.$id == deliveryID)
                .count()
            
            if packBoxesCount == 0 {
                try await deliveryItem.delete(on: db)
            }
        }
        
        return try await deliveryItem.toOutput(on: req.db)
    }
    
    private func updateDeliveryHandler(req: Request) async throws -> DeliveryOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .deliveries) else {
            throw AppError.invalidScope
        }
        let delivery = try req.requireDelivery()
        let input = try req.content.decode(UpdateDeliveryInput.self)
        
        if let images = input.images, images != delivery.images {
            delivery.images = images
            try req.appendUserAction(.assignDeliveryImages(deliveryID: delivery.requireID(), images: images))
        }
        
        if delivery.hasChanges {
            try await delivery.save(on: req.db)
        }
        
        return try await delivery.toOutput(on: req.db)
    }
    
    private func commitDeliveryHandler(req: Request) async throws -> HTTPResponseStatus {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .deliveries) else {
            throw AppError.invalidScope
        }
        let deliveryItem = try req.requireUncommitedDelivery()
        let deliveryItemID = try deliveryItem.requireID()
        
        let packBoxIDs = try await PackBox.query(on: req.db)
            .filter(\.$delivery.$id == deliveryItemID)
            .all(\.$id)
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$packBox.$id ~~ packBoxIDs)
            .all()
        
        guard !trackingItems.isEmpty else {
            throw AppError.deliveryIsEmpty
        }
        
        try await req.db.transaction { db in
            let today = Date()
            deliveryItem.commitedAt = today
            try req.appendUserAction(.commitDelivery(deliveryID: deliveryItem.requireID()))
            
            try await deliveryItem.save(on: db)
            
            try await trackingItems.asyncForEach {
                if let payload = try await $0.moveToStatus(to: .deliveredAtVN, database: db) {
                    try await req.queue.dispatch(DeprecatedTrackingItemStatusUpdateJob.self, payload)
                }
                try await $0.save(on: db)
                try req.appendUserAction(.assignTrackingItemStatus(trackingNumber: $0.trackingNumber, trackingItemID: $0.requireID(), status: .deliveredAtVN))
            }
        }
        return .ok
    }
}

