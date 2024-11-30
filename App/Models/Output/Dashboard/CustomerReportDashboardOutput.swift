import Vapor
import Foundation
import Fluent

struct CustomerReportDashbroadOutput: Content {
    var clients: [String : [SaleByClient]]
}

extension CustomerReportDashbroadOutput {
    struct SaleByClient: Content {
        var deliveredAt: String?
        var customerCode: String?
        var trackingNumber: String?
        var agentCode: String?
        var products: [ProductDashboardOutput]?
    }
}

extension CustomerReportDashbroadOutput {
    init(items: [TrackingItem], on db: Database) async throws {
        let trackingItems = try await items.sortCreatedAtDescending().asyncMap({
            return try await $0.toDashboardOutput(on: db)
        }).sorted(by: {lhs, rhs in
            return lhs.customerCode ?? "" < rhs.customerCode ?? ""
        })
        
        self.clients = Dictionary(grouping: trackingItems) { trackingItem in
            guard let deliveredAt = trackingItem.deliveredAt else {
                return "N/A"
            }
            return deliveredAt
        }
    }
}

extension TrackingItem {
    func toDashboardOutput(on db: Database) async throws -> CustomerReportDashbroadOutput.SaleByClient {
        let products = try await self.$products.get(on: db)
        return .init(
            deliveredAt: self.deliveredAt?.toISODate(),
            customerCode: self.$customers.value?.map(\.customerCode).joined(separator: ", "),
            trackingNumber: self.trackingNumber,
            agentCode: self.agentCode,
            products: products.map {
                $0.toDashboardOutput()
            })
    }
}



