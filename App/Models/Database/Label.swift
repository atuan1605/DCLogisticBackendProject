import Vapor
import Foundation
import Fluent

final class Label: Model, @unchecked Sendable {
    static let schema = "labels"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "tracking_number")
    var trackingNumber: String
    
    @Field(key: "quantity")
    var quantity: Int
    
    @OptionalField(key: "reference")
    var reference: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Parent(key: "warehouse_id")
    var warehouse: Warehouse
    
    @Parent(key: "agent_id")
    var agent: Agent
    
    @Parent(key: "customer_id")
    var customer: Customer    
    
    @Parent(key: "label_product_id")
    var labelProduct: LabelProduct
    
    @OptionalParent(key: "super_label_id")
    var superLabel: Label?
    
    @OptionalParent(key: "tracking_item_id")
    var trackingItem: TrackingItem?
    
    @Children(for: \.$superLabel)
    var subLabels: [Label]
    
    @Field(key:"simplified_tracking_number")
    var simplifiedTrackingNumber: String
    
    @OptionalField(key: "printed_at")
    var printedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil,
         trackingNumber: String,
         quantity: Int,
         reference: String? = nil,
         warehouseID: Warehouse.IDValue,
         agentID: Agent.IDValue,
         customerID: Customer.IDValue,
         labelProductID: LabelProduct.IDValue,
         superLabelID: Label.IDValue? = nil
    ) {
        self.id = id
        self.trackingNumber = trackingNumber
        self.quantity = quantity
        self.reference = reference
        self.$warehouse.id = warehouseID
        self.$agent.id = agentID
        self.$customer.id = customerID
        self.$labelProduct.id = labelProductID
        self.$superLabel.id = superLabelID
        self.simplifiedTrackingNumber = trackingNumber.barCodeSimplify()
    }
}

extension Label: Parameter{}


