import Vapor
import Foundation

struct CreateLabelInput: Content {
    var warehouseID: Warehouse.IDValue
    var agentID: Agent.IDValue
    var customerID: Customer.IDValue
    var labelProductName: String
    var labelProductID: LabelProduct.IDValue?
    var reference: String?
    var quantity: Int
}

extension CreateLabelInput {
    enum CodingKeys: String, CodingKey {
        case warehouseID
        case agentID
        case customerID
        case labelProductName
        case labelProductID
        case reference
        case quantity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.warehouseID = try container.decode(Warehouse.IDValue.self, forKey: .warehouseID)
        self.agentID = try container.decode(Agent.IDValue.self, forKey: .agentID)
        self.customerID = try container.decode(Customer.IDValue.self, forKey: .customerID)
        self.labelProductName = try container.decode(String.self, forKey: .labelProductName)
        self.labelProductID = try container.decodeIfPresent(LabelProduct.IDValue.self, forKey: .labelProductID)
        self.reference = try container.decodeIfPresent(String.self, forKey: .reference)
        self.quantity = try container.decode(Int.self, forKey: .quantity)
    }
}

