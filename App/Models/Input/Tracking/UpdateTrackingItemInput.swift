import Vapor
import Foundation

struct UpdateTrackingItemInput: Content {
    var trackingNumber: String?
    var alternativeRef: OptionalValue<String>?
    var customerIDs: [Customer.IDValue]?
    var agentCode: OptionalValue<String>?
    var files: [String]?
    var warehouseID: Warehouse.IDValue?
    var itemDescription: OptionalValue<String>?
    var brokenProductDescription: OptionalValue<String>?
    var brokenProductCustomerFeedback: OptionalValue<TrackingItem.CustomerFeedback>?
    var products: [UpdateProductInput]?
    var isReturnRequest: Bool?
    var packingRequestNote: String?
}

extension UpdateTrackingItemInput {
    enum CodingKeys: String, CodingKey {
        case trackingNumber
        case alternativeRef
        case customerIDs
        case agentCode
        case files
        case warehouseID
        case itemDescription
        case brokenProductDescription
        case brokenProductCustomerFeedback
        case products
        case isReturnRequest
        case packingRequestNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.trackingNumber) {
            let value = try container.decodeIfPresent(String.self, forKey: .trackingNumber)
            self.trackingNumber = value
        } else{
            self.trackingNumber = nil
        }
        if container.contains(.alternativeRef) {
            let value = try container.decodeIfPresent(String.self, forKey: .alternativeRef)
            self.alternativeRef = OptionalValue(value: value)
        } else {
            self.alternativeRef = nil
        }
        if container.contains(.customerIDs) {
            let value = try container.decodeIfPresent([Customer.IDValue].self, forKey: .customerIDs)
            self.customerIDs = value
        } else{
            self.customerIDs = nil
        }
        if container.contains(.agentCode) {
            let value = try container.decodeIfPresent(String.self, forKey: .agentCode)
            self.agentCode = OptionalValue(value: value)
        } else{
            self.agentCode = nil
        }
        if container.contains(.itemDescription) {
            let value = try container.decodeIfPresent(String.self, forKey: .itemDescription)
            self.itemDescription = OptionalValue(value: value)
        } else{
            self.itemDescription = nil
        }
        if container.contains(.files) {
            let value = try container.decodeIfPresent([String].self, forKey: .files)
            self.files = value
        } else{
            self.files = nil
        }
        if container.contains(.warehouseID) {
            let value = try container.decodeIfPresent(Warehouse.IDValue.self, forKey: .warehouseID)
            self.warehouseID = value
        } else{
            self.warehouseID = nil
        }
        if container.contains(.brokenProductDescription) {
            let value = try container.decodeIfPresent(String.self, forKey: .brokenProductDescription)
            self.brokenProductDescription = OptionalValue(value: value)
        }
        else {
            self.brokenProductDescription = nil
        }
        if container.contains(.brokenProductCustomerFeedback) {
            let value = try container.decodeIfPresent(TrackingItem.CustomerFeedback.self, forKey: .brokenProductCustomerFeedback)
            self.brokenProductCustomerFeedback = OptionalValue(value: value)
        }
        else {
            self.brokenProductCustomerFeedback = nil
        }
        if container.contains(.products) {
            let value = try container.decodeIfPresent([UpdateProductInput].self, forKey: .products)
            self.products = value
        } else {
            self.products = nil
        }
        if container.contains(.isReturnRequest) {
            let value = try container.decodeIfPresent(Bool.self, forKey: .isReturnRequest)
            self.isReturnRequest = value
        } else {
            self.isReturnRequest = nil
        }
        if container.contains(.packingRequestNote) {
            let value = try container.decodeIfPresent(String.self, forKey: .packingRequestNote)
            self.packingRequestNote = value
        } else {
            self.packingRequestNote = nil
        }
    }
}

struct OptionalValue<T: Codable>: Codable {
    var value: T?

    init(value: T?) {
        self.value = value
    }
}
