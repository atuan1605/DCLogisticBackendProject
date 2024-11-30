import Foundation
import Vapor

struct BuyerOutput: Content {
    var id: Buyer.IDValue?
    var username: String
    var email: String
    var phoneNumber: String
    var createdAt: Date?
    var updatedAt: Date?
    var verifiedAt: Date?
    var packingRequestLeft: Int?
    var customerCode: String?
    var isAdmin: Bool
    var isPublicImages: Bool
}

extension Buyer: HasOutput {
    func output() -> BuyerOutput {
        .init(
            id: self.id,
            username: self.username,
            email: self.email,
            phoneNumber: self.phoneNumber,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            verifiedAt: self.verifiedAt,
            packingRequestLeft: self.packingRequestLeft,
            isAdmin: self.isAdmin,
            isPublicImages: self.isPublicImages
        )
    }
    
    func outputWithCustomer(customerCode: String?) -> BuyerOutput {
        .init(
            id: self.id,
            username: self.username,
            email: self.email,
            phoneNumber: self.phoneNumber,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            verifiedAt: self.verifiedAt,
            packingRequestLeft: self.packingRequestLeft,
            customerCode: customerCode,
            isAdmin: self.isAdmin,
            isPublicImages: self.isPublicImages
        )
    }
}
