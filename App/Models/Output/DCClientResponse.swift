import Vapor
import Foundation

struct DCClientBuyerResponse: Content, Codable {
    var id: UUID
    var username: String
    var email: String
    var passwordHash: String
    var phoneNumber: String
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var verifiedAt: Date?
    var packingRequestLeft: Int?
}


struct DCClientBuyerTrackingResponse: Content, Codable {
    var note: String
    var createdAt: Date?
    var updatedAt: Date?
    var buyer: DCClientBuyerResponse
    var packingRequest: String
    var trackingNumber: String
}

