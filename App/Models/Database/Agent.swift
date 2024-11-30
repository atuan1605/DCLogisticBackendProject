import Foundation
import Vapor
import Fluent

final class Agent: Model, @unchecked Sendable {
    static let schema: String = "agents"

    @ID(custom: .id)
    var id: String?

    @Field(key: "name")
    var name: String

    @Field(key: "popular_products")
    var popularProducts: [String]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Children(for: \.$agent)
    var buyers: [Buyer]

    @Siblings(through: UserAgent.self, from: \.$agent, to: \.$user)
    var users: [User]
    
    @OptionalField(key:"primary_color")
    var primaryColor: String?
    
    @OptionalField(key: "accent_color")
    var accentColor: String?
    
    @OptionalField(key: "logo")
    var logo: String?
    
    @OptionalField(key: "inactive_at")
    var inactiveAt: Date?
    
    init() { }

    init(
        id: String?,
        name: String,
        popularProducts: [String] = ["iPad, iPhone, AirPod, Clothes"],
        primaryColor: String = "#d70e30",
        accentColor: String = "#000",
        logo: String? = Environment.process.DEFAULT_LOGO_ID) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.accentColor = accentColor
        self.popularProducts = popularProducts
        self.logo = logo
    }
}

extension Agent: Parameter { }
