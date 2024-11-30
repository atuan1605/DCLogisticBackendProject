//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import Vapor
import Fluent

final class TrackingItem: Model, @unchecked Sendable {
    static let schema: String = "tracking_items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "tracking_number")
    var trackingNumber: String

    @OptionalField(key: "alternative_ref")
    var alternativeRef: String?

//    @ComputedField(key: "is_walmart")
//    var isWalmartTracking: Bool
    
    @OptionalField(key: "agent_code")
    var agentCode: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @OptionalField(key: "received_at_us_at")
    private(set) var receivedAtUSAt: Date?

    @OptionalField(key: "repacking_at")
    private(set) var repackingAt: Date?

    @OptionalField(key: "repacked_at")
    private(set) var repackedAt: Date?

    @OptionalField(key: "boxed_at")
    private(set) var boxedAt: Date?

    @OptionalField(key: "flying_back_at")
    private(set) var flyingBackAt: Date?

    @OptionalField(key: "received_at_vn_at")
    private(set) var receivedAtVNAt: Date?
    
    @OptionalField(key: "delivered_at")
    private(set) var deliveredAt: Date?
    
    @OptionalField(key: "imported_at")
    private(set) var importedAt: Date?

    @OptionalField(key: "chain")
    var chain: String?

    @OptionalParent(key: "warehouse_id")
    var warehouse: Warehouse?
    
    @OptionalField(key: "registered_at")
    var registeredAt: Date?
    
    @OptionalField(key: "return_request_at")
    var returnRequestAt: Date?

    init() { }

    init(
        trackingNumber: String,
        agentCode: String? = nil,
        receivedAtUSAt: Date? = nil,
        repackingAt: Date? = nil,
        repackedAt: Date? = nil,
        boxedAt: Date? = nil,
        flyingBackAt: Date? = nil,
        archivedAt: Date? = nil,
        receivedAtVNAt: Date? = nil,
        packedAtVNAt: Date? = nil,
        packBoxCommitedAt: Date? = nil,
        deliveredAt: Date? = nil,
        importedAt: Date? = nil,
        files: [String] = [],
        itemDescription: String? = nil,
        chain: String? = nil,
        warehouseID: Warehouse.IDValue? = nil,
        returnRequestAt: Date? = nil
    ) {
        self.trackingNumber = trackingNumber
        self.agentCode = agentCode
        self.receivedAtUSAt = receivedAtUSAt
        self.repackingAt = repackingAt
        self.repackedAt = repackedAt
        self.boxedAt = boxedAt
        self.flyingBackAt = flyingBackAt
        self.receivedAtVNAt = receivedAtVNAt
        self.deliveredAt = deliveredAt
        self.importedAt = importedAt
        self.chain = chain
        self.deletedAt = Date().addingTimeInterval(6*30*24*60*60) // tracking item is invalid after 180 days
        self.$warehouse.id = warehouseID
        self.returnRequestAt = returnRequestAt
    }
}

extension TrackingItem: Parameter { }

extension TrackingItem: HasCreatedAt { }
extension TrackingItem {
    
    enum HoldState: String, Content {
        case holding
        case returnProduct
        case continueDelivering
    }
    
    func moveStatusByDCClientResponse(to newStatus: Status, updatedAt: Date) {
        guard self.status != newStatus else {
            return
        }
        switch newStatus {
        case .registered:
            self.registeredAt = updatedAt
            break
        case .receivedAtUSWarehouse:
            self.receivedAtUSAt = updatedAt
            break
        case .receivedAtVNWarehouse:
            self.receivedAtVNAt = updatedAt
            break
//        case .deliveredAtVN:
//            self.deliveredAt = updatedAt
//            break
        default:
            break
        }
        
    }

    func moveToStatus(to newStatus: Status, database: Database) async throws -> DeprecatedTrackingItemStatusUpdateJob.Payload? {
        guard self.status != newStatus else {
            return nil
        }
        guard self.returnRequestAt == nil else {
            throw AppError.trackingItemIsInReturnRequest
        }
        let now = Date()
        
        switch (status, newStatus) {
        case (.new, .registered):
            self.registeredAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .registered,
                timestampt: now)
        case (.new, .receivedAtUSWarehouse):
            self.registeredAt = now
            self.receivedAtUSAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .receivedAtUSWarehouse,
                timestampt: now
            )
        case (.new, .repacking):
            self.registeredAt = now
            self.receivedAtUSAt = now
            self.repackingAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .repacking,
                timestampt: now
            )
        case (.registered, .receivedAtUSWarehouse):
            self.receivedAtUSAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .receivedAtUSWarehouse,
                timestampt: now)
        case (.registered, .repacking):
            self.receivedAtUSAt = now
            self.repackingAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .repacking,
                timestampt: now)
        case (.repacking, .receivedAtUSWarehouse):
            self.repackingAt = nil
            return nil
        case (.receivedAtUSWarehouse, .repacking):
            self.repackingAt = Date()
            return nil
        case (.repacked, .repacking):
            self.repackedAt = nil
            return nil
        case (.repacking, .repacked):
            self.repackedAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .repacked,
                timestampt: now
            )
        case (.repacking, .boxed):
            self.repackedAt = now
            self.boxedAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .boxed,
                timestampt: now
            )
        case (.repacked, .boxed):
            self.boxedAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .boxed,
                timestampt: now
            )
        case (.boxed, .repacked):
//            self.$box.id = nil
            self.boxedAt = nil
            return nil
        case (.boxed, .flyingBack):
            self.flyingBackAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .flyingBack,
                timestampt: now
            )
        case(.flyingBack, .receivedAtVNWarehouse):
            self.receivedAtVNAt = now
            return .init(
                trackingNumber: self.trackingNumber,
                status: .receivedAtVNWarehouse,
                timestampt: now
            )
//        case(.receivedAtVNWarehouse, .packedAtVN):
//         self.packedAtVNAt = now
//            return .init(
//                trackingNumber: self.trackingNumber,
//                status: .packedAtVN,
//                timestampt: now
//            )
//        case(.packedAtVN, .receivedAtVNWarehouse):
//            self.$packBox.id = nil
//            self.packedAtVNAt = nil
//            return nil
//        case(.packedAtVN, .packBoxCommitted):
//            self.packBoxCommitedAt = now
//            return .init(
//                trackingNumber: self.trackingNumber,
//                status: .packBoxCommitted,
//                timestampt: now
//            )
//        case(.packBoxCommitted, .packedAtVN):
//           self.packBoxCommitedAt = nil
//            return nil
//        case(.packBoxCommitted, .deliveredAtVN):
//            self.deliveredAt = now
//            return .init(
//                trackingNumber: self.trackingNumber,
//                status: .deliveredAtVN,
//                timestampt: now)
//        case (.new, .archiveAtVN):
//           self.archivedAt = now
//            return .init(
//                trackingNumber: self.trackingNumber,
//                status: .archiveAtVN,
//                timestampt: now
//            )
//        case(.archiveAtVN, .receivedAtVNWarehouse):
//            self.receivedAtVNAt = now
//            return .init(
//                trackingNumber: self.trackingNumber,
//                status: .receivedAtVNWarehouse,
//                timestampt: now
//            )
//            
        default:
            throw AppError.statusUpdateInvalid
        }
    }
    
    func update<Value>(using keyPath: KeyPath<TrackingItem, OptionalFieldProperty<TrackingItem, Value>>, to value: Value?) {
        self[keyPath: keyPath].wrappedValue = value
    }
}

extension TrackingItem {
    var status: Status {
//        if self.deliveredAt != nil {
//            return .deliveredAtVN
//        }
//        if self.packBoxCommitedAt != nil {
//            return .packBoxCommitted
//        }
//        if self.packedAtVNAt != nil {
//            return .packedAtVN
//        }
        if self.receivedAtVNAt != nil {
            return .receivedAtVNWarehouse
        }
//        if self.archivedAt != nil {
//            return .archiveAtVN
//        }
        if self.flyingBackAt != nil {
            return .flyingBack
        }
        if self.boxedAt != nil {
            return .boxed
        }
        if self.repackedAt != nil {
            return .repacked
        }
        if self.repackingAt != nil {
            return .repacking
        }
        if self.receivedAtUSAt != nil {
            return .receivedAtUSWarehouse
        }
        if self.registeredAt != nil {
            return .registered
        }
        return .new
    }

    var statusUpdatedAt: Date? {
        switch self.status {
        case .receivedAtUSWarehouse:
            return self.receivedAtUSAt
        case .repacking:
            return self.repackingAt
        case .repacked:
            return self.repackedAt
        case .boxed:
            return self.boxedAt
        case .flyingBack:
            return self.flyingBackAt
//        case .archiveAtVN:
//            return self.archivedAt
        case .receivedAtVNWarehouse:
            return self.receivedAtVNAt
//        case .packedAtVN:
//            return self.packedAtVNAt
//        case .packBoxCommitted:
//            return self.packBoxCommitedAt
//        case .deliveredAtVN:
//            return self.deliveredAt
        default:
            return nil
        }
    }

    enum Status: String, Content, Equatable, Comparable {
        case new
        case registered // Đăng ký
        case receivedAtUSWarehouse // <- Nhận tại kho
        case repacking // <- da co tracking number + agent code
        case repacked // <- sau khi repack
        case boxed // <- sau khi đóng thùng
        case flyingBack // <- Sau khi đưa lên máy bay
//        case archiveAtVN // <- Sau khi nhận tại VN nhưng tracking có status là new
        case receivedAtVNWarehouse // <- Sau khi nhận tại VN
//        case packedAtVN // <- Sau khi cho vào pack box
//        case packBoxCommitted // <- Sau khi commit pack box
//        case deliveredAtVN // <- Sau khi commit delivery
        
        var power: Int {
            switch self {
            case .new: return 0
            case .registered: return 1
            case .receivedAtUSWarehouse: return 2
            case .repacking: return 3
            case .repacked: return 4
            case .boxed: return 5
            case .flyingBack: return 6
//            case .archiveAtVN: return 7
            case .receivedAtVNWarehouse: return 8
//            case .packedAtVN: return 9
//            case .packBoxCommitted: return 10
//            case .deliveredAtVN: return 11
            }
        }

        static public func ==(lhs: Self, rhs: Self) -> Bool {
            return lhs.power == rhs.power
        }
        
        static public func <(lhs: Self, rhs: Self) -> Bool {
            return lhs.power < rhs.power
        }

        func keyPath() throws -> KeyPath<TrackingItem, OptionalFieldProperty<TrackingItem, Date>> {
            switch self {
            case .new:
                throw AppError.unknown
            case .registered:
                return \TrackingItem.$registeredAt
            case .receivedAtUSWarehouse:
                return \TrackingItem.$receivedAtUSAt
            case .repacking:
                return \TrackingItem.$repackingAt
            case .repacked:
                return \TrackingItem.$repackedAt
            case .boxed:
                return \TrackingItem.$boxedAt
            case .flyingBack:
                return \TrackingItem.$flyingBackAt
//            case .archiveAtVN:
//                return \TrackingItem.$archivedAt
            case .receivedAtVNWarehouse:
                return \TrackingItem.$receivedAtVNAt
//            case .packedAtVN:
//                return \TrackingItem.$packedAtVNAt
//            case .packBoxCommitted:
//                return \TrackingItem.$packBoxCommitedAt
//            case .deliveredAtVN:
//                return \TrackingItem.$deliveredAt
            }
        }
    }
    
    enum CustomerFeedback: String, Codable {
        case none, returnProduct, continueDelivering
    }
}

//final class BrokenProduct: Fields, @unchecked Sendable {
//    @Field(key: "description")
//    var description: String?
//    
//    @OptionalEnum(key: "customer_feedback")
//    var customerFeedback: TrackingItem.CustomerFeedback?
//    
//    @OptionalField(key: "flag_at")
//    var flagAt: Date?
//    
//    init() { }
//
//    init(description: String?, customerFeedback: TrackingItem.CustomerFeedback?, flagAt: Date?) {
//        self.description = description
//        self.customerFeedback = customerFeedback
//        self.flagAt = flagAt
//    }
//}

struct TrackingItemModelMiddleware: AsyncModelMiddleware {
    func update(model: TrackingItem, on db: Database, next: AnyAsyncModelResponder) async throws {
        if let trackingItem = try await TrackingItem.find(model.requireID(), on: db) {
            if trackingItem.status.power >= 5 && model.returnRequestAt != trackingItem.returnRequestAt && model.returnRequestAt != nil {
                throw AppError.cannotHoldTrackingAfterBeingBoxed
            }
        }
        try await next.update(model, on: db)
    }
}

extension TrackingItem {
    
    var isValidToAddTrackingReferences: Bool {
        let isValid = !self.trackingNumber.hasPrefix("TBA")
        return isValid
    }
}

