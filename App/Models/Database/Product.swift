import Foundation
import Vapor
import Fluent
import SQLKit

final class Product: Model, @unchecked Sendable {
    static let schema: String = "products"

    @ID(key: .id)
    var id: UUID?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?

    @Field(key: "images")
    var images: [String]

    @Field(key: "index")
    var index: Int

    @Field(key: "description")
    var description: String

    @Field(key: "quantity")
    var quantity: Int

    @Parent(key: "tracking_item_id")
    var trackingItem: TrackingItem

    init() { }

    init(
        trackingItemID: TrackingItem.IDValue,
        images: [String],
        index: Int,
        description: String,
        quantity: Int
    ) {
        self.$trackingItem.id = trackingItemID
        self.images = images
        self.index = index
        self.description = description
        self.quantity = quantity
    }
}

extension Product {
	var hasAllRequiredInformation: Bool {
		return !self.description.isEmpty
			&& self.quantity > 0
			&& !self.images.isEmpty
	}
}

extension Product: Parameter { }

extension Array where Element: Product {
    var description: String {
        return self.map {
            return "\($0.quantity) \($0.description)"
        }.joined(separator: ", ")
    }
}

struct ProductModelMiddleware: AsyncModelMiddleware {
    func update(model: Product, on db: Database, next: AnyAsyncModelResponder) async throws {
        try await next.update(model, on: db)

        let trackingItem = try await model.$trackingItem.get(on: db)
        if
            let agentCode = trackingItem.agentCode,
            let agent = try await Agent.find(agentCode, on: db),
            let sqlDB = db as? SQLDatabase
        {
            struct QueryRow: Content {
                var keyword: String
                var count: Int
            }
            let topDescriptions = try await sqlDB.raw("""
            select p.description as \(ident: "keyword"), count(distinct p.id) as \(ident: "count")
            from products p
            left join tracking_items ti on ti.id = p.tracking_item_id
            where ti.agent_code = \(bind: agentCode) and p.description <> \(bind: "")
            group by p.description
            order by count(distinct p.id) desc
            limit 5;
            """).all(decoding: QueryRow.self)

            var products = ["iPad", "Laptop", "Airpod"]
            let topProducts = topDescriptions.map(\.keyword)
            products.insert(contentsOf: topProducts, at: 0)
            products.removeDuplicates()
            products = products.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            
            agent.popularProducts = Array(products.prefix(10))

            if agent.hasChanges {
                try await agent.save(on: db)
            }
        }
    }
}
