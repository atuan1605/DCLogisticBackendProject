import Foundation
import Vapor
import Fluent
import SQLKit

protocol TrackingItemRepository {
    func get(by customerID: Customer.IDValue, queryModifier: ((QueryBuilder<TrackingItem>) -> Void)?) async throws -> [TrackingItem]
    func get(by customerIDs: [Customer.IDValue], queryModifier: ((QueryBuilder<TrackingItem>) -> Void)?) async throws -> [TrackingItem]
    func extractPackingVideo(request: Request) async throws -> HTTPResponseStatus
    func extractPackingVideoWithBuyerEmail(request: Request) async throws -> HTTPResponseStatus
    func updateHoldState(trackingItemID: TrackingItem.IDValue, holdState: TrackingItem.HoldState) async throws -> TrackingItem
}

struct DatabaseTrackingItemRespository: TrackingItemRepository & DatabaseRepository {
    let db: Database
    let request: Request
    
    func updateHoldState(trackingItemID: TrackingItem.IDValue, holdState: TrackingItem.HoldState) async throws -> TrackingItem {
        guard let trackingItem = try await TrackingItem.find(trackingItemID, on: db) else {
            throw AppError.trackingItemNotFound
        }
        let now = Date()
        switch holdState {
        case .holding:
            trackingItem.returnRequestAt = now
            trackingItem.holdState = holdState
            trackingItem.holdStateAt = now
            request.appendUserAction(.assignReturnRequest(trackingItemID: trackingItemID, isReturn: true))
        case .returnProduct:
            trackingItem.holdState = holdState
            trackingItem.holdStateAt = now
        case .continueDelivering:
            trackingItem.returnRequestAt = nil
            trackingItem.holdState = holdState
            trackingItem.holdStateAt = now
            request.appendUserAction(.assignReturnRequest(trackingItemID: trackingItemID, isReturn: false))
        }
        request.appendUserAction(.updateTrackingItemHoldState(trackingItemID: trackingItemID, holdState: holdState))
        try await trackingItem.save(on: request.db)
        return trackingItem
    }
    
    func extractPackingVideoWithBuyerEmail(request: Request) async throws -> HTTPResponseStatus {
        let trackingItem = try request.requireTrackingItem()
        let buyer = try request.requireAuthBuyer()
        try await trackingItem.$customers.load(on: request.db)
        
        try trackingItem.customers.forEach{ customer in
            guard customer.email == buyer.email else {
                throw AppError.invalidInput
            }
        }
        guard let warehouse = try await trackingItem.$warehouse.get(on: request.db), warehouse.name != nil, warehouse.dvrAccount != nil, warehouse.dvrDomain != nil, warehouse.dvrPassword != nil  else {
            throw AppError.cameraNotSupportInThisWarehouse
        }
        
        let trackingID = try trackingItem.requireID()
        
        var trackingItemIDs: [TrackingItem.IDValue] = []
        if let chain = trackingItem.chain {
            trackingItemIDs = try await TrackingItem.query(on: request.db)
                .filter(\.$chain == chain)
                .all(\.$id)
        } else {
            trackingItemIDs = [trackingID]
        }
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
            try await request.queue.dispatch(ExtractPackingVideoJob.self, .init(
                warehouse: warehouse,
                startDate: startDate,
                endDate: finalEndDate,
                trackingID: trackingID,
                channel: cameraID))
        }
        return .ok
    }
    
    func extractPackingVideo(request: Request) async throws -> HTTPResponseStatus {
        let trackingItem = try request.requireTrackingItem()
        
        guard let warehouse = try await trackingItem.$warehouse.get(on: request.db), warehouse.name != nil, warehouse.dvrAccount != nil, warehouse.dvrDomain != nil, warehouse.dvrPassword != nil  else {
            throw AppError.cameraNotSupportInThisWarehouse
        }
        
        let trackingID = try trackingItem.requireID()
        
        var trackingItemIDs: [TrackingItem.IDValue] = []
        if let chain = trackingItem.chain {
            trackingItemIDs = try await TrackingItem.query(on: request.db)
                .filter(\.$chain == chain)
                .all(\.$id)
        } else {
            trackingItemIDs = [trackingID]
        }
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
            try await request.queue.dispatch(ExtractPackingVideoJob.self, .init(
                warehouse: warehouse,
                startDate: startDate,
                endDate: finalEndDate,
                trackingID: trackingID,
                channel: cameraID))
        }
        return .ok
    }
    
    func get(by customerID: Customer.IDValue, queryModifier: ((QueryBuilder<TrackingItem>) -> Void)?) async throws -> [TrackingItem] {
        let query = TrackingItem.query(on: self.db)
            .join(children: \.$trackingItemCustomers)
            .filter(TrackingItemCustomer.self, \.$customer.$id == customerID)
        queryModifier?(query)
        return try await query
            .fields(for: TrackingItem.self)
            .unique()
            .all()
    }
    
    func get(by customerIDs: [Customer.IDValue], queryModifier: ((QueryBuilder<TrackingItem>) -> Void)?) async throws -> [TrackingItem] {
        let query = TrackingItem.query(on: self.db)
            .join(children: \.$trackingItemCustomers)
            .filter(TrackingItemCustomer.self, \.$customer.$id ~~ customerIDs)
        queryModifier?(query)
        return try await query
            .fields(for: TrackingItem.self)
            .unique()
            .all()
    }
}

struct TrackingItemRepositoryFactory: Sendable {
    var make: (@Sendable (Request) -> TrackingItemRepository & DatabaseRepository)?
    
    mutating func use(_ make: @escaping (@Sendable (Request) -> TrackingItemRepository & DatabaseRepository)) {
        self.make = make
    }
}

extension Application {
    private struct TrackingItemRepositoryKey: StorageKey, Sendable {
        typealias Value = TrackingItemRepositoryFactory
    }
    
    var trackingItems: TrackingItemRepositoryFactory {
        get {
            self.storage[TrackingItemRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[TrackingItemRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var trackingItems: TrackingItemRepository & DatabaseRepository {
        self.application.trackingItems.make!(self)
    }
}

