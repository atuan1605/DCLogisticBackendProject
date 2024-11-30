import Foundation
import Vapor
import Fluent

final class ActionLogger: Model, @unchecked Sendable {
    static let schema: String = "action_loggers"
    
    @ID(key: .id)
    var id: UUID?
    
    enum ActionType: Codable {
        case trackingInfoFinalised(trackingItemID: TrackingItem.IDValue)
        case assignTrackingItemStatus(
            trackingNumber: String?,
            trackingItemID: TrackingItem.IDValue,
            status: TrackingItem.Status
        )
        case assignTrackingItemAlternativeRef(
            trackingItemID: TrackingItem.IDValue,
            alternativeRef: String?
        )
        case assignTrackingItemCustomerCode(
            trackingItemID: TrackingItem.IDValue,
            customerID: Customer.IDValue?,
            customerCode: String?
        )
        case assignTrackingItemAgentCode(
            trackingItemID: TrackingItem.IDValue,
            agentCode: String?
        )
        case assignTrackingItemDescription(
            trackingItemID: TrackingItem.IDValue,
            itemDescription: String?
        )
        case assignTrackingItemFiles(
            trackingItemID: TrackingItem.IDValue,
            files: [String]?
        )
        case assignBox(trackingItemID: TrackingItem.IDValue, pieceID: TrackingItemPiece.IDValue?, boxID: String?)
        case assignShipment(trackingItemID: TrackingItem.IDValue, shipmentID: String?)
        case assignChain(trackingItemID: TrackingItem.IDValue, chain: String?)
        case assignProducts(trackingItemID: TrackingItem.IDValue, productIDs: [Product.IDValue])
        case deleteTrackingNumber(trackingNumber: String)
        case assignProductImages(trackingItemID: TrackingItem.IDValue, productID: Product.IDValue, images: [String]?)
        case assignProductQuantity(trackingItemID: TrackingItem.IDValue, productID: Product.IDValue, quantity: Int)
        case assignProductDescription(trackingItemID: TrackingItem.IDValue, productID: Product.IDValue, description: String?)
        case deleteShipment(shipmentID: Shipment.IDValue)
        case commitShipment(shipmentID: Shipment.IDValue)
        case deleteBox(boxID: Box.IDValue)
        case assignBoxAgentCodes(boxID: Box.IDValue, agentCodes: [String]?)
        case assignBoxName(boxID: Box.IDValue, name: String?)
        case assignBoxWeight(boxID: Box.IDValue, weight: Double?)
        case assignPackBoxWeight(packBoxID: PackBox.IDValue, weight: Double?)
        case assignPackBoxName(packBoxID: PackBox.IDValue, name: String?)
        case assignPackBox(trackingItemID: TrackingItem.IDValue, packBoxID: PackBox.IDValue?)
        case addCustomItemToBox(boxID: Box.IDValue, customItemID: BoxCustomItem.IDValue, customItemDetails: String, reference: String)
        case removeCustomItemFromBox(boxID: Box.IDValue, customItemDetails: String, reference: String)
        case commitPackBox(packBoxID: PackBox.IDValue)
        case createShipment(shipmentID: Shipment.IDValue)
        case createBox(boxID: Box.IDValue)
        case createPackBox(packBoxID: PackBox.IDValue)
        case uncommitPackBox(packBoxID: PackBox.IDValue)
        case createDelivery(deliveryID: Delivery.IDValue)
        case assignDelivery(packBoxID: PackBox.IDValue, deliveryID: Delivery.IDValue?)
        case deleteDelivery(deliveryID: Delivery.IDValue)
        case assignDeliveryImages(
            deliveryID: Delivery.IDValue,
            images: [String]? )
        case commitDelivery(deliveryID: Delivery.IDValue)
        case createTrackingItem(trackingItemId: TrackingItem.IDValue)
        case assignCustomerName(customerId: Customer.IDValue, customerName: String)
        case assignCustomerCode(customerId: Customer.IDValue, customerCode: String)
        case assignCustomerAgentId(customerId: Customer.IDValue, agentID: String)
        case assignCustomerPhoneNumber(customerId: Customer.IDValue, phoneNumber: String)
        case assignCustomerEmail(customerId: Customer.IDValue, email: String)
        case assignCustomerAddress(customerId: Customer.IDValue, address: String)
        case assignCustomerNote(customerId: Customer.IDValue, note: String)
        case assignCustomerFacebook(customerId: Customer.IDValue, facebook: String)
        case assignCustomerZalo(customerId: Customer.IDValue, zalo: String)
        case assignCustomerTelegram(customerId: Customer.IDValue, telegram: String)
        case assignCustomerPriceNote(customerId: Customer.IDValue, priceNote: String)
        case assignCustomerIsProvince(customerId: Customer.IDValue, isProvince: Bool)
        case assignCustomerGoogleLink(customerId: Customer.IDValue, googleLink: String)
        case assignCreateCustomer(customerID: Customer.IDValue)
        case assignTrackingNumberBrokenProductDescription(trackingItemID: TrackingItem.IDValue, brokenProductDescription: String?)
        case assignTrackingNumberBrokenProductCustomerFeedback(trackingItemID: TrackingItem.IDValue, brokenProductCustomerFeedback: TrackingItem.CustomerFeedback?)
        case assignCustomerPrices(customerID: Customer.IDValue, customerPriceIDs: [CustomerPrice.IDValue])
        case assignProductName(customerID: Customer.IDValue, customerPriceID: CustomerPrice.IDValue, productName: String)
        case assignUnitPrice(customerID: Customer.IDValue, customerPriceID: CustomerPrice.IDValue, unitPrice: Int)
        case assignUser(userID: User.IDValue)
        case assignAgents(agentIDs: [Agent.IDValue], userID: User.IDValue)
        case assignWarehouses(warehouseIDs: [Warehouse.IDValue], userID: User.IDValue)
        case updateUserScope(userID: User.IDValue, scopes: [String])
        case unassignBoxShipment(boxID: Box.IDValue, shipmentID: Shipment.IDValue)
        case createLot(lotID: Lot.IDValue)
        case deleteLot(lotID: Lot.IDValue)
        case addBoxToShipment(boxID: Box.IDValue, shipmentID: Shipment.IDValue)
        case createPiece(pieceID: TrackingItemPiece.IDValue)
        case deletePiece(pieceID: TrackingItemPiece.IDValue)
        case addTrackingItemPieceToBox(pieceID: TrackingItemPiece.IDValue, boxID: Box.IDValue)
        case removeTrackingItemPieceFromBox(pieceID: TrackingItemPiece.IDValue, boxID: Box.IDValue)
        case updatePiece(pieceID: TrackingItemPiece.IDValue, infomation: String)
        case assignCustomers(trackingID: TrackingItem.IDValue, customerIDs: [Customer.IDValue], customerCodes: [String])
        case assignReturnRequest(trackingItemID: TrackingItem.IDValue, isReturn: Bool)
        case createWarehouse(warehouseID: Warehouse.IDValue)
        case updateWarehouse(warehouseID: Warehouse.IDValue, inactiveAt: Date?)
        case assignReturnItem(trackingItemID: TrackingItem.IDValue, trackingNumber: String, pieceID: TrackingItemPiece.IDValue, trackingItemPieceInfo: String?, boxID: Box.IDValue?, boxName: String?, status: ReturnStatus)
        case scanCameraQrCode(deviceID: String, cameraID: String)
        case updatePackingRequestState(buyerTrackingItemID: BuyerTrackingItem.IDValue, state: BuyerTrackingItem.PackingRequestState)
        case updateTrackingItemHoldState(trackingItemID: TrackingItem.IDValue, holdState: TrackingItem.HoldState?)
        case createAgent(agentID: Agent.IDValue)
        case assignInactiveUser(userID: User.IDValue)
        case switchTrackingToAnotherWarehouse(trackingItemID: TrackingItem.IDValue, trackingNumber: String, sourceWarehouseID: Warehouse.IDValue, destinationWarehouseID: Warehouse.IDValue, sourceWarehouseName: String?, destinationWarehouseName: String?)
        case createLabel(labelID: Label.IDValue, superLabelID: Label.IDValue?, trackingNumber: String)
        case deleteLabels(labelIDs: [Label.IDValue])
        case createLabelProduct(labelProductID: LabelProduct.IDValue)
        case updateLabelProduct(labelProductID: LabelProduct.IDValue, name: String)
        case assignDeposit(buyerTrackingItemIDs: [BuyerTrackingItem.IDValue])
        case createBuyerTrackingItem(buyerTrackingItemID: BuyerTrackingItem.IDValue, requestType: BuyerTrackingItem.RequestType, note: String?, packingRequest: String?, quantity: Int?, deposit: Int?)
        case updateBuyerTrackingItem(buyerTrackingItemID: BuyerTrackingItem.IDValue, note: String?)
        case deleteBuyerTrackingItem(buyerTrackingItemID: BuyerTrackingItem.IDValue)
    }
    
    @OptionalParent(key: "user_id")
    var user: User?
    
    @OptionalField(key: "agent_identifier")
    var agentIdentifier: String?
    
    @Field(key: "type")
    var type: ActionType
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @OptionalParent(key: "buyer_id")
    var buyer: Buyer?
    
    init() { }
    
    init(
        userID: User.IDValue? = nil,
        buyerID: Buyer.IDValue? = nil,
        agentIdentifier: String?,
        type: ActionType
    ) {
        self.$user.id = userID
        self.$buyer.id = buyerID
        self.agentIdentifier = agentIdentifier
        self.type = type
    }
}

extension ActionLogger.ActionType {
    enum CodingKeys: String, CodingKey {
        case assignTrackingItemStatus
        case assignBox
        case assignShipment
        case assignChain
        case assignProducts
        case deleteTrackingNumber
        case assignTrackingItemCustomerCode
        case assignTrackingItemAgentCode
        case assignTrackingItemDescription
        case assignTrackingItemFiles
        case assignProductImages
        case assignProductQuantity
        case assignProductDescription
        case deleteShipment
        case commitShipment
        case deleteBox
        case assignBoxAgentCodes
        case assignBoxName
        case assignBoxWeight
        case assignPackBoxWeight
        case assignPackBoxName
        case assignPackBox
        case commitPackBox
        case createShipment
        case createBox
        case createPackBox
        case uncommitPackBox
        case createDelivery
        case assignDelivery
        case deleteDelivery
        case assignDeliveryImages
        case commitDelivery
        case createTrackingItem
        case assignCustomerName
        case assignCustomerCode
        case assignCustomerAgentId
        case assignCustomerPhoneNumber
        case assignCustomerEmail
        case assignCustomerAddress
        case assignCustomerNote
        case assignCustomerFacebook
        case assignCustomerZalo
        case assignCustomerTelegram
        case assignCustomerPriceNote
        case assignCustomerIsProvince
        case assignCustomerGoogleLink
        case assignCreateCustomer
        case assignTrackingNumberBrokenProductDescription
        case assignTrackingNumberBrokenProductCustomerFeedback
        case assignCustomerPrices
        case assignProductName
        case assignUnitPrice
        case addCustomItemToBox
        case removeCustomItemFromBox
        case assignTrackingItemAlternativeRef
        case assignUser
        case assignAgents
        case assignWarehouses
        case updateUserScope
        case createLot
        case deleteLot
        case unassignBoxShipment
        case addBoxToShipment
        case createPiece
        case deletePiece
        case addTrackingItemPieceToBox
        case removeTrackingItemPieceFromBox
        case updatePiece
        case trackingInfoFinalised
        case assignCustomers
        case assignReturnRequest
        case createWarehouse
        case updateWarehouse
        case assignReturnItem
        case scanCameraQrCode
        case updatePackingRequestState
        case updateTrackingItemHoldState
        case createAgent
        case assignInactiveUser
        case switchTrackingToAnotherWarehouse
        case createLabel
        case deleteLabels
        case createLabelProduct
        case updateLabelProduct
        case assignDeposit
        case createBuyerTrackingItem
        case updateBuyerTrackingItem
        case deleteBuyerTrackingItem
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let key = container.allKeys.first else {
            throw AppError.unknown
        }
        switch key {
        case .deleteBuyerTrackingItem:
            struct Metadata: Codable {
                var buyerTrackingItemID: BuyerTrackingItem.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .deleteBuyerTrackingItem(buyerTrackingItemID: metadata.buyerTrackingItemID)
        case .updateBuyerTrackingItem:
            struct Metadata: Codable {
                var buyerTrackingItemID: BuyerTrackingItem.IDValue
                var note: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .updateBuyerTrackingItem(buyerTrackingItemID: metadata.buyerTrackingItemID, note: metadata.note)
        case .createBuyerTrackingItem:
            struct Metadata: Codable {
                var buyerTrackingItemID: BuyerTrackingItem.IDValue
                var requestType: BuyerTrackingItem.RequestType
                var note: String?
                var packingRequest: String?
                var quantity: Int?
                var deposit: Int?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createBuyerTrackingItem(
                buyerTrackingItemID: metadata.buyerTrackingItemID,
                requestType: metadata.requestType,
                note: metadata.note,
                packingRequest: metadata.packingRequest,
                quantity: metadata.quantity,
                deposit: metadata.deposit)
        case .assignCustomers:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var customerIDs: [Customer.IDValue]
                var customerCodes: [String]
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignCustomers(trackingID: metadata.trackingItemID, customerIDs: metadata.customerIDs, customerCodes: metadata.customerCodes)
        case .trackingInfoFinalised:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .trackingInfoFinalised(trackingItemID: metadata.trackingItemID)
        case .assignTrackingItemAlternativeRef:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var alternativeRef: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignTrackingItemAlternativeRef(
                trackingItemID: metadata.trackingItemID,
                alternativeRef: metadata.alternativeRef
            )
        case .assignTrackingItemStatus:
            struct Metadata: Codable {
                var trackingNumber: String?
                var trackingItemID: TrackingItem.IDValue
                var status: TrackingItem.Status
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignTrackingItemStatus(
                trackingNumber: metadata.trackingNumber,
                trackingItemID: metadata.trackingItemID,
                status: metadata.status
            )
        case .assignBox:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var pieceID: TrackingItemPiece.IDValue?
                var boxID: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignBox(
                trackingItemID: metadata.trackingItemID,
                pieceID: metadata.pieceID,
                boxID: metadata.boxID)
        case .assignShipment:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var shipmentID: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignShipment(trackingItemID: metadata.trackingItemID, shipmentID: metadata.shipmentID)
        case .assignChain:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var chain: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignChain(
                trackingItemID: metadata.trackingItemID,
                chain: metadata.chain)
        case .assignProducts:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var productIDs: [Product.IDValue]
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignProducts(
                trackingItemID: metadata.trackingItemID,
                productIDs: metadata.productIDs
            )
        case .assignTrackingItemCustomerCode:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var customerID: Customer.IDValue?
                var customerCode: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignTrackingItemCustomerCode(
                trackingItemID: metadata.trackingItemID,
                customerID: metadata.customerID,
                customerCode: metadata.customerCode
            )
        case .assignTrackingItemAgentCode:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var agentCode: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignTrackingItemAgentCode(
                trackingItemID: metadata.trackingItemID,
                agentCode: metadata.agentCode
            )
        case .assignTrackingItemDescription:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var itemDescription: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignTrackingItemDescription(
                trackingItemID: metadata.trackingItemID,
                itemDescription: metadata.itemDescription
            )
        case .assignTrackingItemFiles:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var files: [String]?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignTrackingItemFiles(
                trackingItemID: metadata.trackingItemID,
                files: metadata.files
            )
        case .deleteTrackingNumber:
            struct Metadata: Codable {
                var trackingNumber: String
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .deleteTrackingNumber(trackingNumber: metadata.trackingNumber)
        case .assignProductImages:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var productID: Product.IDValue
                var images: [String]?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignProductImages(
                trackingItemID: metadata.trackingItemID,
                productID: metadata.productID,
                images: metadata.images
            )
        case .assignProductQuantity:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var productID: Product.IDValue
                var quantity: Int
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignProductQuantity(
                trackingItemID: metadata.trackingItemID,
                productID: metadata.productID,
                quantity: metadata.quantity
            )
        case .assignProductDescription:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var productID: Product.IDValue
                var productDescription: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignProductDescription(
                trackingItemID: metadata.trackingItemID,
                productID: metadata.productID,
                description: metadata.productDescription
            )
        case .deleteShipment:
            struct Metadata: Codable {
                var shipmentID: Shipment.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .deleteShipment(shipmentID: metadata.shipmentID)
        case .commitShipment:
            struct Metadata: Codable {
                var shipmentID: Shipment.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .commitShipment(shipmentID: metadata.shipmentID)
        case .deleteBox:
            struct Metadata: Codable {
                var boxID: Box.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .deleteBox(boxID: metadata.boxID)
        case .assignBoxAgentCodes:
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var agentCodes: [String]?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignBoxAgentCodes(boxID: metadata.boxID, agentCodes: metadata.agentCodes)
        case .assignBoxName:
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var name: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignBoxName(boxID: metadata.boxID, name: metadata.name)
        case .assignBoxWeight:
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var weight: Double?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignBoxWeight(boxID: metadata.boxID, weight: metadata.weight)
        case .assignPackBoxName:
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
                var name: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignPackBoxName(packBoxID: metadata.packBoxID, name: metadata.name)
        case .assignPackBoxWeight:
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
                var weight: Double?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignPackBoxWeight(packBoxID: metadata.packBoxID, weight: metadata.weight)
        case .assignPackBox:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var packBoxID: PackBox.IDValue?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignPackBox(
                trackingItemID: metadata.trackingItemID,
                packBoxID: metadata.packBoxID)
        case .commitPackBox:
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .commitPackBox(packBoxID: metadata.packBoxID)
        case .createShipment:
            struct Metadata: Codable {
                var shipmentID: Shipment.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createShipment(shipmentID: metadata.shipmentID)
        case .createBox:
            struct Metadata: Codable {
                var boxID: Box.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createBox(boxID: metadata.boxID)
        case .createPackBox:
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createPackBox(packBoxID: metadata.packBoxID)
        case .uncommitPackBox:
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .uncommitPackBox(packBoxID: metadata.packBoxID)
        case .createDelivery:
            struct Metadata: Codable {
                var deliveryID: Delivery.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createDelivery(deliveryID: metadata.deliveryID)
        case .assignDelivery:
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
                var deliveryID: Delivery.IDValue?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignDelivery(
                packBoxID: metadata.packBoxID,
                deliveryID: metadata.deliveryID)
        case .deleteDelivery:
            struct Metadata: Codable {
                var deliveryID: Delivery.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .deleteDelivery(deliveryID: metadata.deliveryID)
        case .assignDeliveryImages:
            struct Metadata: Codable {
                var deliveryID: Delivery.IDValue
                var images: [String]?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignDeliveryImages(deliveryID: metadata.deliveryID, images: metadata.images)
        case .commitDelivery:
            struct Metadata: Codable {
                var deliveryID: Delivery.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .commitDelivery(deliveryID: metadata.deliveryID)
        case .assignCreateCustomer:
            struct Metadata: Codable {
                var customerID: Customer.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignCreateCustomer(customerID: metadata.customerID)
        case .assignTrackingNumberBrokenProductDescription:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var brokenProductDescription: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignTrackingNumberBrokenProductDescription(trackingItemID: metadata.trackingItemID, brokenProductDescription: metadata.brokenProductDescription)
        case .assignTrackingNumberBrokenProductCustomerFeedback:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var brokenProductCustomerFeedback: TrackingItem.CustomerFeedback?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignTrackingNumberBrokenProductCustomerFeedback(trackingItemID: metadata.trackingItemID, brokenProductCustomerFeedback: metadata.brokenProductCustomerFeedback)
        case .assignCustomerPrices:
            struct Metadata: Codable {
                var customerID: Customer.IDValue
                var customerPriceIDs: [CustomerPrice.IDValue]
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignCustomerPrices(
                customerID: metadata.customerID,
                customerPriceIDs: metadata.customerPriceIDs)
        case .assignProductName:
            struct Metadata: Codable {
                var customerID: Customer.IDValue
                var customerPriceID: CustomerPrice.IDValue
                var productName: String
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignProductName(
                customerID: metadata.customerID,
                customerPriceID: metadata.customerPriceID,
                productName: metadata.productName)
        case .assignUnitPrice:
            struct Metadata: Codable {
                var customerID: Customer.IDValue
                var customerPriceID: CustomerPrice.IDValue
                var unitPrice: Int
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignUnitPrice(
                customerID: metadata.customerID,
                customerPriceID: metadata.customerPriceID,
                unitPrice: metadata.unitPrice)
        case .addCustomItemToBox:
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var customItemID: BoxCustomItem.IDValue
                var customItemDetails: String
                var customItemReference: String
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .addCustomItemToBox(
                boxID: metadata.boxID,
                customItemID: metadata.customItemID,
                customItemDetails: metadata.customItemDetails,
                reference: metadata.customItemReference
            )
        case .removeCustomItemFromBox:
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var customItemDetails: String
                var customItemReference: String
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .removeCustomItemFromBox(boxID: metadata.boxID, customItemDetails: metadata.customItemDetails, reference: metadata.customItemReference)
        case .assignUser:
            struct Metadata: Codable {
                var userID: User.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignUser(userID: metadata.userID)
        case .assignAgents:
            struct Metadata: Codable {
                var agentIDs: [Agent.IDValue]
                var userID: User.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignAgents(agentIDs: metadata.agentIDs, userID: metadata.userID)
        case .assignWarehouses:
            struct Metadata: Codable {
                var userID: User.IDValue
                var warehouseIDs: [Warehouse.IDValue]
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignWarehouses(warehouseIDs: metadata.warehouseIDs, userID: metadata.userID)
        case .updateUserScope:
            struct Metadata: Codable {
                var userID: User.IDValue
                var scopes: [String]
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .updateUserScope(userID: metadata.userID, scopes: metadata.scopes)
        case .createLot:
            struct Metadata: Codable {
                var lotID: Lot.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createLot(lotID: metadata.lotID)
        case .deleteLot:
            struct Metadata: Codable {
                var lotID: Lot.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .deleteLot(lotID: metadata.lotID)
        case .unassignBoxShipment:
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var shipmentID: Shipment.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .unassignBoxShipment(boxID: metadata.boxID, shipmentID: metadata.shipmentID)
        case .addBoxToShipment:
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var shipmentID: Shipment.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .addBoxToShipment(boxID: metadata.boxID, shipmentID: metadata.shipmentID)
        case .addTrackingItemPieceToBox:
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
                var boxID: Box.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .addTrackingItemPieceToBox(pieceID: metadata.pieceID, boxID: metadata.boxID)
        case .deletePiece:
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .deletePiece(pieceID: metadata.pieceID)
        case .createPiece:
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createPiece(pieceID: metadata.pieceID)
        case .updatePiece:
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
                var information: String
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .updatePiece(pieceID: metadata.pieceID, infomation: metadata.information)
        case .removeTrackingItemPieceFromBox:
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
                var boxID: Box.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .removeTrackingItemPieceFromBox(pieceID: metadata.pieceID, boxID: metadata.boxID)
        case .assignReturnRequest:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var isReturn: Bool
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignReturnRequest(trackingItemID: metadata.trackingItemID, isReturn: metadata.isReturn)
        case .createWarehouse:
            struct Metadata: Codable {
                var warehouseID: Warehouse.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createWarehouse(warehouseID: metadata.warehouseID)
        case .updateWarehouse:
            struct Metadata: Codable {
                var warehouseID: Warehouse.IDValue
                var inactiveAt: Date?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .updateWarehouse(warehouseID: metadata.warehouseID, inactiveAt: metadata.inactiveAt)
        case .assignReturnItem:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var trackingNumber: String
                var pieceID: TrackingItemPiece.IDValue
                var trackingItemPieceInfo: String?
                var boxID: Box.IDValue?
                var boxName: String?
                var status: ReturnStatus
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignReturnItem(trackingItemID: metadata.trackingItemID, trackingNumber: metadata.trackingNumber, pieceID: metadata.pieceID, trackingItemPieceInfo: metadata.trackingItemPieceInfo, boxID: metadata.boxID, boxName: metadata.boxName, status: metadata.status)
            
        case .scanCameraQrCode:
            struct Metadata: Codable {
                var deviceID: String
                var cameraID: String
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .scanCameraQrCode(deviceID: metadata.deviceID, cameraID: metadata.cameraID)
        case .updatePackingRequestState:
            struct Metadata: Codable {
                var buyerTrackingItemID: BuyerTrackingItem.IDValue
                var state: BuyerTrackingItem.PackingRequestState
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .updatePackingRequestState(buyerTrackingItemID: metadata.buyerTrackingItemID, state: metadata.state)
        case .updateTrackingItemHoldState:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var holdState: TrackingItem.HoldState?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .updateTrackingItemHoldState(
                trackingItemID: metadata.trackingItemID,
                holdState: metadata.holdState
            )
        case .createAgent:
            struct Metadata: Codable {
                var agentID: Agent.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createAgent(agentID: metadata.agentID)
        case .assignInactiveUser:
            struct Metadata: Codable {
                var userID: User.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignInactiveUser(userID: metadata.userID
            )
        case .switchTrackingToAnotherWarehouse:
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var trackingNumber: String
                var sourceWarehouseID: Warehouse.IDValue
                var destinationWarehouseID: Warehouse.IDValue
                var sourceWarehouseName: String?
                var destinationWarehouseName: String?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .switchTrackingToAnotherWarehouse(trackingItemID: metadata.trackingItemID, trackingNumber: metadata.trackingNumber, sourceWarehouseID: metadata.sourceWarehouseID, destinationWarehouseID: metadata.destinationWarehouseID, sourceWarehouseName: metadata.sourceWarehouseName, destinationWarehouseName: metadata.destinationWarehouseName
            )
        case .createLabel:
            struct Metadata: Codable {
                var labelID: Label.IDValue
                var trackingNumber: String
                var superLabelID: Label.IDValue?
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createLabel(labelID: metadata.labelID, superLabelID: metadata.superLabelID, trackingNumber: metadata.trackingNumber)
        case .deleteLabels:
            struct Metadata: Codable {
                var labelIDs: [Label.IDValue]
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .deleteLabels(labelIDs: metadata.labelIDs)
        case .createLabelProduct:
            struct Metadata: Codable {
                var labelProductID: LabelProduct.IDValue
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .createLabelProduct(labelProductID: metadata.labelProductID)
        case .updateLabelProduct:
            struct Metadata: Codable {
                var labelProductID: LabelProduct.IDValue
                var name: String
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .updateLabelProduct(labelProductID: metadata.labelProductID, name: metadata.name)
        case .assignDeposit:
            struct Metadata: Codable {
                var buyerTrackingItemIDs: [BuyerTrackingItem.IDValue]
            }
            let metadata = try container.decode(Metadata.self, forKey: key)
            self = .assignDeposit(buyerTrackingItemIDs: metadata.buyerTrackingItemIDs)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unabled to decode enum."
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .assignCustomers(let trackingID, let customerIDs, let customerCodes):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var customerIDs: [Customer.IDValue]
                var customerCodes: [String]
            }
            let metadata = Metadata.init(trackingItemID: trackingID, customerIDs: customerIDs, customerCodes: customerCodes)
            try container.encode(metadata, forKey: .assignCustomers)
        case .trackingInfoFinalised(let trackingItemID):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
            }
            let metadata = Metadata.init(trackingItemID: trackingItemID)
            try container.encode(metadata, forKey: .trackingInfoFinalised)
        case .assignTrackingItemAlternativeRef(let trackingItemID, let alternativeRef):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var alternativeRef: String?
            }
            let metadata = Metadata(
                trackingItemID: trackingItemID,
                alternativeRef: alternativeRef
            )
            try container.encode(metadata, forKey: .assignTrackingItemAlternativeRef)
        case .addCustomItemToBox(
            let boxID,
            let customItemID,
            let customItemDetails,
            let customItemReference
        ):
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var customItemID: BoxCustomItem.IDValue
                var customItemDetails: String
                var customItemReference: String
            }
            let metadata = Metadata(
                boxID: boxID,
                customItemID: customItemID,
                customItemDetails: customItemDetails,
                customItemReference: customItemReference
            )
            try container.encode(metadata, forKey: .addCustomItemToBox)
        case .removeCustomItemFromBox(let boxID, let customItemDetails, let customItemReference):
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var customItemDetails: String
                var customItemReference: String
            }
            let metadata = Metadata(
                boxID: boxID,
                customItemDetails: customItemDetails,
                customItemReference: customItemReference
            )
            try container.encode(metadata, forKey: .removeCustomItemFromBox)
        case .assignTrackingItemStatus(
            let trackingNumber,
            let trackingItemID,
            let status):
            struct Metadata: Codable {
                var trackingNumber: String?
                var trackingItemID: TrackingItem.IDValue
                var status: TrackingItem.Status
            }
            let metadata = Metadata(
                trackingNumber: trackingNumber,
                trackingItemID: trackingItemID,
                status: status
            )
            try container.encode(metadata, forKey: .assignTrackingItemStatus)
        case .assignBox(let trackingItemID, let pieceID, let boxID):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var pieceID: TrackingItemPiece.IDValue?
                var boxID: String?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, pieceID: pieceID, boxID: boxID)
            try container.encode(metadata, forKey: .assignBox)
        case .assignShipment(trackingItemID: let trackingItemID, shipmentID: let shipmentID):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var shipmentID: String?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, shipmentID: shipmentID)
            try container.encode(metadata, forKey: .assignShipment)
        case .assignChain(let trackingItemID, let chain):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var chain: String?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, chain: chain)
            try container.encode(metadata, forKey: .assignChain)
        case .assignProducts(let trackingItemID, let productIDs):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var productIDs: [Product.IDValue]
            }
            let metadata = Metadata(trackingItemID: trackingItemID, productIDs: productIDs)
            try container.encode(metadata, forKey: .assignProducts)
        case .assignTrackingItemCustomerCode(let trackingItemID, let customerID, let customerCode):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var customerID: Customer.IDValue?
                var customerCode: String?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, customerID: customerID, customerCode: customerCode)
            try container.encode(metadata, forKey: .assignTrackingItemCustomerCode)
        case .assignTrackingItemAgentCode(let trackingItemID, let agentCode):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var agentCode: String?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, agentCode: agentCode)
            try container.encode(metadata, forKey: .assignTrackingItemAgentCode)
        case .assignTrackingItemDescription(let trackingItemID, let itemDescription):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var itemDescription: String?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, itemDescription: itemDescription)
            try container.encode(metadata, forKey: .assignTrackingItemDescription)
        case .assignTrackingItemFiles(let trackingItemID, let files):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var files: [String]?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, files: files)
            try container.encode(metadata, forKey: .assignTrackingItemFiles)
        case .assignProductImages(let trackingItemID, let productID, let images):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var productID: Product.IDValue
                var images: [String]?
            }
            let metadata = Metadata.init(trackingItemID: trackingItemID, productID: productID, images: images)
            try container.encode(metadata, forKey: .assignProductImages)
        case .assignProductQuantity(let trackingItemID, let productID, let quantity):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var productID: Product.IDValue
                var quantity: Int
            }
            let metadata = Metadata.init(trackingItemID: trackingItemID, productID: productID, quantity: quantity)
            try container.encode(metadata, forKey: .assignProductQuantity)
        case .assignProductDescription(let trackingItemID, let productID, let productDescription):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var productID: Product.IDValue
                var productDescription: String?
            }
            let metadata = Metadata.init(trackingItemID: trackingItemID, productID: productID, productDescription: productDescription)
            try container.encode(metadata, forKey: .assignProductDescription)
        case .deleteTrackingNumber(let trackingNumber):
            struct Metadata: Codable {
                var trackingNumber: String
            }
            let metadata = Metadata(trackingNumber: trackingNumber)
            try container.encode(metadata, forKey: .deleteTrackingNumber)
        case .deleteShipment(let shipmentID):
            struct Metadata: Codable {
                var shipmentID: Shipment.IDValue
            }
            let metadata = Metadata(shipmentID: shipmentID)
            try container.encode(metadata, forKey: .deleteShipment)
        case .commitShipment(let shipmentID):
            struct Metadata: Codable {
                var shipmentID: Shipment.IDValue
            }
            let metadata = Metadata(shipmentID: shipmentID)
            try container.encode(metadata, forKey: .commitShipment)
        case .deleteBox(let boxID):
            struct Metadata: Codable {
                var boxID: Box.IDValue
            }
            let metadata = Metadata(boxID: boxID)
            try container.encode(metadata, forKey: .deleteBox)
        case .assignBoxAgentCodes(let boxID, let agentCodes):
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var agentCodes: [String]?
            }
            let metadata = Metadata(boxID: boxID, agentCodes: agentCodes)
            try container.encode(metadata, forKey: .assignBoxAgentCodes)
        case .assignBoxName(let boxID, let name):
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var name: String?
            }
            let metadata = Metadata(boxID: boxID, name: name)
            try container.encode(metadata, forKey: .assignBoxName)
        case .assignBoxWeight(let boxID, let weight):
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var weight: Double?
            }
            let metadata = Metadata(boxID: boxID, weight: weight)
            try container.encode(metadata, forKey: .assignBoxWeight)
        case .assignPackBoxName(let packBoxID, let name):
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
                var name: String?
            }
            let metadata = Metadata(packBoxID: packBoxID, name: name)
            try container.encode(metadata, forKey: .assignPackBoxName)
        case .assignPackBoxWeight(let packBoxID, let weight):
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
                var weight: Double?
            }
            let metadata = Metadata(packBoxID: packBoxID, weight: weight)
            try container.encode(metadata, forKey: .assignPackBoxWeight)
        case .assignPackBox(let trackingItemID, let packBoxID):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var packBoxID: PackBox.IDValue?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, packBoxID: packBoxID)
            try container.encode(metadata, forKey: .assignPackBox)
        case .commitPackBox(let packBoxID):
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
            }
            let metadata = Metadata(packBoxID: packBoxID)
            try container.encode(metadata, forKey: .commitPackBox)
        case .createBox(let boxID):
            struct Metadata: Codable {
                var boxID: Box.IDValue
            }
            let metadata = Metadata(boxID: boxID)
            try container.encode(metadata, forKey: .createBox)
        case .createShipment(let shipmentID):
            struct Metadata: Codable {
                var shipmentID: Shipment.IDValue
            }
            let metadata = Metadata(shipmentID: shipmentID)
            try container.encode(metadata, forKey: .createShipment)
        case .createPackBox(let packBoxID):
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
            }
            let metadata = Metadata(packBoxID: packBoxID)
            try container.encode(metadata, forKey: .createPackBox)
        case .uncommitPackBox(let packBoxID):
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
            }
            let metadata = Metadata(packBoxID: packBoxID)
            try container.encode(metadata, forKey: .uncommitPackBox)
        case .createDelivery(let deliveryID):
            struct Metadata: Codable {
                var deliveryID: Delivery.IDValue
            }
            let metadata = Metadata(deliveryID: deliveryID)
            try container.encode(metadata, forKey: .createDelivery)
        case .assignDelivery(let packBoxID, let deliveryID):
            struct Metadata: Codable {
                var packBoxID: PackBox.IDValue
                var deliveryID: Delivery.IDValue?
            }
            let metadata = Metadata(packBoxID: packBoxID, deliveryID: deliveryID)
            try container.encode(metadata, forKey: .assignDelivery)
        case .deleteDelivery(let deliveryID):
            struct Metadata: Codable {
                var deliveryID: Delivery.IDValue
            }
            let metadata = Metadata(deliveryID: deliveryID)
            try container.encode(metadata, forKey: .deleteDelivery)
        case .assignDeliveryImages(let deliveryID, let images):
            struct Metadata: Codable {
                var deliveryID: Delivery.IDValue
                var images: [String]?
            }
            let metadata = Metadata.init(deliveryID: deliveryID, images: images)
            try container.encode(metadata, forKey: .assignDeliveryImages)
        case .commitDelivery(let deliveryID):
            struct Metadata: Codable {
                var deliveryID: Delivery.IDValue
            }
            let metadata = Metadata(deliveryID: deliveryID)
            try container.encode(metadata, forKey: .commitDelivery)
        case .createTrackingItem(trackingItemId: let trackingItemId):
            struct Metadata: Codable {
                var trackingItemId: TrackingItem.IDValue
            }
            let metadata = Metadata(trackingItemId: trackingItemId)
            try container.encode(metadata, forKey: .createTrackingItem)
        case .assignCustomerName(customerId: let customerId, customerName: let customerName):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var customerName: String
            }
            let metadata = Metadata(customerId: customerId, customerName: customerName)
            try container.encode(metadata, forKey: .assignCustomerName)
        case .assignCustomerCode(customerId: let customerId, customerCode: let customerCode):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var customerCode: String
            }
            let metadata = Metadata(customerId: customerId, customerCode: customerCode)
            try container.encode(metadata, forKey: .assignCustomerCode)
        case .assignCustomerAgentId(customerId: let customerId, agentID: let agentID):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var agentID: String
            }
            let metadata = Metadata(customerId: customerId, agentID: agentID)
            try container.encode(metadata, forKey: .assignCustomerAgentId)
        case .assignCreateCustomer(let customerID):
            struct Metadata: Codable {
                var customerID: Customer.IDValue
            }
            let metadata = Metadata(customerID: customerID)
            try container.encode(metadata, forKey: .assignCreateCustomer)
        case .assignCustomerPhoneNumber(customerId: let customerId, phoneNumber: let phoneNumber):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var phoneNumber: String
            }
            let metadata = Metadata(customerId: customerId, phoneNumber: phoneNumber)
            try container.encode(metadata, forKey: .assignCustomerPhoneNumber)
        case .assignCustomerEmail(customerId: let customerId, email: let email):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var email: String
            }
            let metadata = Metadata(customerId: customerId, email: email)
            try container.encode(metadata, forKey: .assignCustomerEmail)
        case .assignCustomerAddress(customerId: let customerId, address: let address):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var address: String
            }
            let metadata = Metadata(customerId: customerId, address: address)
            try container.encode(metadata, forKey: .assignCustomerAddress)
        case .assignCustomerNote(customerId: let customerId, note: let note):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var note: String
            }
            let metadata = Metadata(customerId: customerId, note: note)
            try container.encode(metadata, forKey: .assignCustomerNote)
        case .assignCustomerFacebook(customerId: let customerId, facebook: let facebook):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var facebook: String
            }
            let metadata = Metadata(customerId: customerId, facebook: facebook)
            try container.encode(metadata, forKey: .assignCustomerFacebook)
        case .assignCustomerZalo(customerId: let customerId, zalo: let zalo):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var zalo: String
            }
            let metatada = Metadata(customerId: customerId, zalo: zalo)
            try container.encode(metatada, forKey: .assignCustomerZalo)
        case .assignCustomerTelegram(customerId: let customerId, telegram: let telegram):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var telegram: String
            }
            let metadata = Metadata(customerId: customerId, telegram: telegram)
            try container.encode(metadata, forKey: .assignCustomerTelegram)
        case .assignCustomerPriceNote(customerId: let customerId, priceNote: let priceNote):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var priceNote: String
            }
            let metadata = Metadata(customerId: customerId, priceNote: priceNote)
            try container.encode(metadata, forKey: .assignCustomerPriceNote)
        case .assignCustomerIsProvince(customerId: let customerId, isProvince: let isProvince):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var isProvince: Bool
            }
            let metadata = Metadata(customerId: customerId, isProvince: isProvince)
            try container.encode(metadata, forKey: .assignCustomerIsProvince)
        case .assignCustomerGoogleLink(customerId: let customerId, googleLink: let googleLink):
            struct Metadata: Codable {
                var customerId: Customer.IDValue
                var googleLink: String
            }
            let metadata = Metadata(customerId: customerId, googleLink: googleLink)
            try container.encode(metadata, forKey: .assignCustomerGoogleLink)
        case .assignTrackingNumberBrokenProductDescription(trackingItemID: let trackingItemId, brokenProductDescription: let brokenProductDescription):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var brokenProductDescription: String?
            }
            let metadata = Metadata(trackingItemID: trackingItemId, brokenProductDescription: brokenProductDescription)
            try container.encode(metadata, forKey: .assignTrackingNumberBrokenProductDescription)
        case .assignTrackingNumberBrokenProductCustomerFeedback(trackingItemID: let trackingItemId, brokenProductCustomerFeedback: let brokenProductCustomerFeedback):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var brokenProductCustomerFeedback: TrackingItem.CustomerFeedback?
            }
            let metadata = Metadata(trackingItemID: trackingItemId, brokenProductCustomerFeedback: brokenProductCustomerFeedback)
            try container.encode(metadata, forKey: .assignTrackingNumberBrokenProductCustomerFeedback)
            
        case .assignCustomerPrices(let customerID, let customerPriceIDs):
            struct Metadata: Codable {
                var customerID: Customer.IDValue
                var customerPriceIDs: [CustomerPrice.IDValue]
            }
            let metadata = Metadata(customerID: customerID, customerPriceIDs: customerPriceIDs)
            try container.encode(metadata, forKey: .assignCustomerPrices)
        case .assignProductName(let customerID, let customerPriceID, let productName):
            struct Metadata: Codable {
                var customerID: Customer.IDValue
                var customerPriceID: CustomerPrice.IDValue
                var productName: String?
            }
            let metadata = Metadata.init(customerID: customerID, customerPriceID: customerPriceID, productName: productName)
            try container.encode(metadata, forKey: .assignProductName)
        case .assignUnitPrice(let customerID, let customerPriceID, let unitPrice):
            struct Metadata: Codable {
                var customerID: Customer.IDValue
                var customerPriceID: CustomerPrice.IDValue
                var unitPrice: Int
            }
            let metadata = Metadata.init(customerID: customerID, customerPriceID: customerPriceID, unitPrice: unitPrice)
            try container.encode(metadata, forKey: .assignUnitPrice)
        case .assignUser(let userID):
            struct Metadata: Codable {
                var userID: User.IDValue
            }
            let metadata = Metadata.init(userID: userID)
            try container.encode(metadata, forKey: .assignUser)
        case .assignAgents(let agentIDs, let userID):
            struct Metadata: Codable {
                var agentIDs: [Agent.IDValue]
                var userID: User.IDValue
            }
            let metadata = Metadata.init(agentIDs: agentIDs, userID: userID)
            try container.encode(metadata, forKey: .assignAgents)
        case .assignWarehouses(let warehouseIDs, let userID):
            struct Metadata: Codable {
                var warehouseIDs: [Warehouse.IDValue]
                var userID: User.IDValue
            }
            let metadata = Metadata.init(warehouseIDs: warehouseIDs, userID: userID)
            try container.encode(metadata, forKey: .assignWarehouses)
        case .updateUserScope(let userID, let scopes):
            struct Metadata: Codable {
                var userID: User.IDValue
                var scopes: [String]
            }
            let metadata = Metadata.init(userID: userID, scopes: scopes)
            try container.encode(metadata, forKey: .updateUserScope)
        case .createLot(let lotID):
            struct Metadata: Codable {
                var lotID: Lot.IDValue
            }
            let metadata = Metadata(lotID: lotID)
            try container.encode(metadata, forKey: .createLot)
        case .deleteLot(let lotID):
            struct Metadata: Codable {
                var lotID: Lot.IDValue
            }
            let metadata = Metadata(lotID: lotID)
            try container.encode(metadata, forKey: .deleteLot)
        case .unassignBoxShipment(let boxID, let shipmentID):
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var shipmentID: Shipment.IDValue
            }
            let metadata = Metadata(boxID: boxID, shipmentID: shipmentID)
            try container.encode(metadata, forKey: .unassignBoxShipment)
        case .addBoxToShipment(let boxID, let shipmentID):
            struct Metadata: Codable {
                var boxID: Box.IDValue
                var shipmentID: Shipment.IDValue
            }
            let metadata = Metadata(boxID: boxID, shipmentID: shipmentID)
            try container.encode(metadata, forKey: .addBoxToShipment)
        case .addTrackingItemPieceToBox(let pieceID, let boxID):
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
                var boxID: Box.IDValue
            }
            let metadata = Metadata(pieceID: pieceID, boxID: boxID)
            try container.encode(metadata, forKey: .addTrackingItemPieceToBox)
        case .createPiece(let pieceID):
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
            }
            let metadata = Metadata(pieceID: pieceID)
            try container.encode(metadata, forKey: .createPiece)
        case .deletePiece(let pieceID):
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
            }
            let metadata = Metadata(pieceID: pieceID)
            try container.encode(metadata, forKey: .deletePiece)
        case .updatePiece(let pieceID, let information):
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
                var information: String
            }
            let metadata = Metadata(pieceID: pieceID, information: information)
            try container.encode(metadata, forKey: .updatePiece)
        case .removeTrackingItemPieceFromBox(let pieceID, let boxID):
            struct Metadata: Codable {
                var pieceID: TrackingItemPiece.IDValue
                var boxID: Box.IDValue
            }
            let metadata = Metadata(pieceID: pieceID, boxID: boxID)
            try container.encode(metadata, forKey: .removeTrackingItemPieceFromBox)
        case .assignReturnRequest(let trackingItemID, let isReturn):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var isReturn: Bool
            }
            let metadata = Metadata(trackingItemID: trackingItemID, isReturn: isReturn)
            try container.encode(metadata, forKey: .assignReturnRequest)
        case .createWarehouse(let warehouseID):
            struct Metadata: Codable {
                var warehouseID: Warehouse.IDValue
            }
            let metadata = Metadata(warehouseID: warehouseID)
            try container.encode(metadata, forKey: .createWarehouse)
        case .updateWarehouse(let warehouseID, let inactiveAt):
            struct Metadata: Codable {
                var warehouseID: Warehouse.IDValue
                var inactiveAt: Date?
            }
            let metadata = Metadata(warehouseID: warehouseID, inactiveAt: inactiveAt)
            try container.encode(metadata, forKey: .updateWarehouse)
        case .assignReturnItem(let trackingItemID, let trackingNumber, let pieceID, let trackingItemPieceInfo, let boxID, let boxName, let status):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var trackingNumber: String
                var pieceID: TrackingItemPiece.IDValue
                var trackingItemPieceInfo: String?
                var boxID: Box.IDValue?
                var boxName: String?
                var status: ReturnStatus
            }
            let metadata = Metadata(trackingItemID: trackingItemID, trackingNumber: trackingNumber, pieceID: pieceID, trackingItemPieceInfo: trackingItemPieceInfo, boxID: boxID, boxName: boxName, status: status)
            try container.encode(metadata, forKey: .assignReturnItem)
            
        case .scanCameraQrCode(let deviceID, let cameraID):
            struct Metadata: Codable {
                var deviceID: String
                var cameraID: String
            }
            let metadata = Metadata(deviceID: deviceID, cameraID: cameraID)
            try container.encode(metadata, forKey: .scanCameraQrCode)
        case .updatePackingRequestState(let buyerTrackingItemID, let state):
            struct Metadata: Codable {
                var buyerTrackingItemID: BuyerTrackingItem.IDValue
                var state: BuyerTrackingItem.PackingRequestState
            }
            let metadata = Metadata(buyerTrackingItemID: buyerTrackingItemID, state: state)
            try container.encode(metadata, forKey: .updatePackingRequestState)
        case .updateTrackingItemHoldState(let trackingItemID, let holdState):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var holdState: TrackingItem.HoldState?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, holdState: holdState)
            try container.encode(metadata, forKey: .updateTrackingItemHoldState)
        case .createAgent(let agentID):
            struct Metadata: Codable {
                var agentID: Agent.IDValue
            }
            let metadata = Metadata(agentID: agentID)
            try container.encode(metadata, forKey: .createAgent)
        case .assignInactiveUser(let userID):
            struct Metadata: Codable {
                var userID: User.IDValue
            }
            let metadata = Metadata(userID: userID)
            try container.encode(metadata, forKey: .assignInactiveUser)
        case .switchTrackingToAnotherWarehouse(let trackingItemID, let trackingNumber, let sourceWarehouseID, let destinationWarehouseID, let sourceWarehouseName, let destinationWarehouseName):
            struct Metadata: Codable {
                var trackingItemID: TrackingItem.IDValue
                var trackingNumber: String
                var sourceWarehouseID: Warehouse.IDValue
                var destinationWarehouseID: Warehouse.IDValue
                var sourceWarehouseName: String?
                var destinationWarehouseName: String?
            }
            let metadata = Metadata(trackingItemID: trackingItemID, trackingNumber: trackingNumber, sourceWarehouseID: sourceWarehouseID, destinationWarehouseID: destinationWarehouseID, sourceWarehouseName: sourceWarehouseName, destinationWarehouseName: destinationWarehouseName)
            try container.encode(metadata, forKey: .switchTrackingToAnotherWarehouse)
        case .createLabel(let labelID, let superLabelID, let trackingNumber):
            struct Metadata: Codable {
                var labelID: Label.IDValue
                var superLabelID: Label.IDValue?
                var trackingNumber: String
            }
            let metadata = Metadata(labelID: labelID, superLabelID: superLabelID, trackingNumber: trackingNumber)
            try container.encode(metadata, forKey: .createLabel)
        case .deleteLabels(let labelIDs):
            struct Metadata: Codable {
                var labelIDs: [Label.IDValue]
            }
            let metadata = Metadata(labelIDs: labelIDs)
            try container.encode(metadata, forKey: .deleteLabels)
        case .createLabelProduct(let labelProductID):
            struct Metadata: Codable {
                var labelProductID: LabelProduct.IDValue
            }
            let metadata = Metadata(labelProductID: labelProductID)
            try container.encode(metadata, forKey: .createLabelProduct)
        case .updateLabelProduct(let labelProductID, let name):
            struct Metadata: Codable {
                var labelProductID: LabelProduct.IDValue
                var name: String
            }
            let metadata = Metadata(labelProductID: labelProductID, name: name)
            try container.encode(metadata, forKey: .updateLabelProduct)
        case .assignDeposit(let buyerTrackingItemIDs):
            struct Metadata: Codable {
                var buyerTrackingItemIDs: [BuyerTrackingItem.IDValue]
            }
            let metadata = Metadata(buyerTrackingItemIDs: buyerTrackingItemIDs)
            try container.encode(metadata, forKey: .assignDeposit)
        case .createBuyerTrackingItem(let buyerTrackingItemID, let requestType, let note, let packingRequest, let quantity, let deposit):
            struct Metadata: Codable {
                var buyerTrackingItemID: BuyerTrackingItem.IDValue
                var requestType: BuyerTrackingItem.RequestType
                var note: String?
                var packingRequest: String?
                var quantity: Int?
                var deposit: Int?
            }
            let metadata = Metadata(
                buyerTrackingItemID: buyerTrackingItemID,
                requestType: requestType,
                note: note,
                packingRequest: packingRequest,
                quantity: quantity,
                deposit: deposit)
            try container.encode(metadata, forKey: .createBuyerTrackingItem)
        case .updateBuyerTrackingItem(buyerTrackingItemID: let buyerTrackingItemID, note: let note):
            struct Metadata: Codable {
                var buyerTrackingItemID: BuyerTrackingItem.IDValue
                var note: String?
            }
            let metadata = Metadata(buyerTrackingItemID: buyerTrackingItemID, note: note)
            try container.encode(metadata, forKey: .updateBuyerTrackingItem)
        case .deleteBuyerTrackingItem(buyerTrackingItemID: let buyerTrackingItemID):
            struct Metadata: Codable {
                var buyerTrackingItemID: BuyerTrackingItem.IDValue
            }
            let metadata = Metadata(buyerTrackingItemID: buyerTrackingItemID)
            try container.encode(metadata, forKey: .deleteBuyerTrackingItem)
        }
    }
}
