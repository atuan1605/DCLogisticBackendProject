import Vapor
import Foundation
import Fluent

struct PackBoxOutput: Content {
    let id: PackBox.IDValue?
    let name: String
    let weight: Double?
    let commitedAt: Date?
    let trackingItemCount: Int
    let items: [String : [TrackingItemOutput]]?
    let customer: Customer.IDValue?
    
    init(id: PackBox.IDValue? = nil, name: String, weight: Double? = nil, commitedAt: Date? = nil, trackingItemCount: Int, items: [String : [TrackingItemOutput]]?,customer: Customer.IDValue? = nil) {
        self.id = id
        self.name = name
        self.weight = weight
        self.commitedAt = commitedAt
        self.trackingItemCount = trackingItemCount
        self.items = items
        self.customer = customer
    }
}

struct CustomerPackBoxOutput: Content {
    let name: String
    let trackingItemsCount: Int
    let trackingItems: [TrackingItemOutput]
}

extension PackBox {
    func toOutput(on db: Database) async throws -> PackBoxOutput {
        let trackingItems = try await self.$trackingItems.get(on: db)
        let grouped = Dictionary(grouping: trackingItems) { item in
            return item.chain ?? "N/A"
        }.mapValues {
            $0.map { $0.output() }.sorted { lhs, rhs in
                lhs.packedAtVnAt ?? Date() > rhs.packedAtVnAt ?? Date()
            }
        }
        return .init(
            id: self.id,
            name: self.name,
            weight: self.weight,
            commitedAt: self.commitedAt,
            trackingItemCount: trackingItems.count,
            items: grouped,
            customer: self.$customer.id
        )
    }
    
    func output(customerID: UUID) -> CustomerPackBoxOutput {
        // let trackingItems = self.trackingItems.filter { $0.$customer.id == customerID }
        trackingItems = []
        return .init(
            name: self.name,
            trackingItemsCount: self.trackingItems.count,
            trackingItems: trackingItems.map { $0.output() }.sorted(by: { lhs, rhs in
                lhs.packboxComitedAt ?? .distantPast > rhs.packboxComitedAt ?? .distantPast
            })
        )
    }
}
