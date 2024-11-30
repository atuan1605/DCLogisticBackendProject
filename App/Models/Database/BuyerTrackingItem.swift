import Vapor
import Foundation
import Fluent

final class BuyerTrackingItem: Model, @unchecked Sendable  {
    static let schema: String = "buyer_tracking_items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "note")
    var note: String

    @Field(key: "packing_request")
    var packingRequest: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Parent(key: "buyer_id")
    var buyer: Buyer

    @Field(key: "tracking_number")
    var trackingNumber: String

    @Siblings(through: BuyerTrackingItemLinkView.self, from: \.$buyerTrackingItem, to: \.$trackingItem)
    var trackingItems: [TrackingItem]
    
    @OptionalField(key: "packing_request_state")
    var packingRequestState: PackingRequestState?

    @OptionalField(key: "quantity")
    var quantity: Int?
    
    @OptionalParent(key: "parent_id")
    var parentRequest: BuyerTrackingItem?
    
    @Children(for: \.$parentRequest)
    var associatedRequests: [BuyerTrackingItem]

    @OptionalField(key: "actual_quantity")
    var actualQuantity: Int? // Chỉ có nhân viên khi scan mới được update trường này
    
    @OptionalField(key: "packing_request_note")
    var packingRequestNote: String?
    
    @OptionalField(key: "deposit")
    var deposit: Int?
    
    @OptionalField(key: "paid_at")
    var paidAt: Date?
    
    @Field(key: "request_type")
    var requestType: RequestType
    
    @OptionalField(key: "customer_note")
    var customerNote: String?
    
    init() { }

    init(
        note: String,
        packingRequest: String,
        buyerID: Buyer.IDValue,
        trackingNumber: String,
        quantity: Int? = nil,
        parentRequestID: BuyerTrackingItem.IDValue? = nil,
        deposit: Int? = nil,
        requestType: RequestType = .trackingStatusCheck
    ) {
        self.note = note
        self.$buyer.id = buyerID
        self.trackingNumber = trackingNumber
        self.packingRequest = packingRequest
        self.deposit = deposit
        self.quantity = quantity
        self.$parentRequest.id = parentRequestID
        self.requestType = requestType
    }
}

extension BuyerTrackingItem: Parameter {}

extension BuyerTrackingItem {
    enum PackingRequestState: String, Content {
        case hold
        case processed
    }
    
    enum RequestType: String, Content {
        case specialRequest //Yêu cầu đặc biệt
        case quantityCheck //Kiểm tra số lượng
        case trackingStatusCheck //Theo dõi tracking
        case holdTracking //Yêu cầu hold
        case returnTracking //Yêu cầu return
        case camera //Yêu cầu xuất camera
    }
    
    static var nonActionRequestType: [RequestType] {
        return [.trackingStatusCheck, .camera]
    }
}

extension QueryBuilder where Model: BuyerTrackingItem {
    @discardableResult func filter(trackingNumbers: [String]) -> Self {
        guard !trackingNumbers.isEmpty else {
            return self
        }
        let regexSuffixGroup = trackingNumbers.map {
            $0.suffix(12)
        }.joined(separator: "|")
        let fullRegex = "^.*(\(regexSuffixGroup))$"
        
        return self.group(.or) { builder in
            builder.filter(.sql(raw: "\(BuyerTrackingItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex))
            builder.group(.and) { andBuilder in
                let fullRegex2 = "^.*(\(regexSuffixGroup))\\d{4}$"
                andBuilder.filter(.sql(raw: "char_length(\(BuyerTrackingItem.schema).tracking_number)"), .equal, .bind(32))
                andBuilder.filter(.sql(raw: "\(BuyerTrackingItem.schema).tracking_number"), .custom("~*"), .bind(fullRegex2))
            }
        }
    }
}

struct BuyerTrackingItemModelMiddleware: AsyncModelMiddleware {
    
    func update(model: BuyerTrackingItem, on db: any Database, next: any AnyAsyncModelResponder) async throws {
        let associatedRequests = try await model.$associatedRequests.get(on: db)
        try await db.transaction { transaction in
            try await associatedRequests.asyncForEach { item in
                item.note = model.note
                item.packingRequest = model.packingRequest
                try await item.save(on: transaction)
            }
            try await next.update(model, on: transaction)
        }
    }
}
