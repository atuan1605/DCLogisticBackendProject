import Foundation
import Fluent
import Vapor

final class Customer: Model, @unchecked Sendable {
    static let schema: String = "customers"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @Field(key: "customer_name")
    var customerName: String?
    
    @Field(key: "customer_code")
    var customerCode: String
    
    @OptionalField(key: "phone_number")
    var phoneNumber: String?
    
    @OptionalField(key: "email")
    var email: String?
    
    @OptionalField(key: "address")
    var address: String?
    
    @OptionalField(key: "note")
    var note: String?
    
    @Parent(key: "agent_id")
    var agent: Agent
    
    @Siblings(through: TrackingItemCustomer.self, from: \.$customer, to: \.$trackingItem)
    var trackingItems: [TrackingItem]
    
    @Group(key: "social_links")
    var socialLinks: SocialLinks
    
    @OptionalField(key: "price_note")
    var priceNote: String?
    
    @OptionalField(key: "is_province")
    var isProvince: Bool?
    
    @OptionalField(key: "google_link")
    var googleLink: String?
    
    @Children(for: \.$customer)
    var prices: [CustomerPrice]
    
    @Children(for: \.$customer)
    var packBoxes: [PackBox]
    
    @Children(for: \.$customer)
    var trackingItemCustomers: [TrackingItemCustomer]
    
    init() { }
    
    init(
        customerName: String,
        customerCode: String,
        agentID: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        address: String? = nil,
        note: String? = nil,
        socialLinks: SocialLinks,
        priceNote: String? = nil,
        isProvince: Bool? = nil,
        googleLink: String? = nil
    ) {
        self.customerName = customerName
        self.customerCode = customerCode
        self.$agent.id = agentID
        self.phoneNumber = phoneNumber
        self.email = email
        self.address = address
        self.note = note
        self.socialLinks = socialLinks
        self.priceNote = priceNote
        self.isProvince = isProvince
        self.googleLink = googleLink
    }
}

extension Customer: Parameter {}

final class SocialLinks: Fields, @unchecked Sendable {
    
    @Field(key: "facebook")
    var facebook: String?
    
    @Field(key: "zalo")
    var zalo: String?
    
    @Field(key: "telegram")
    var telegram: String?
    
    init(facebook: String? = nil, zalo: String? = nil, telegram: String? = nil) {
        self.facebook = facebook
        self.zalo = zalo
        self.telegram = telegram
    }
    
    init() { }
}

extension Customer {
    func normalizeEmail() -> String? {
        return self.email?.normalizeString()
    }
    
}
