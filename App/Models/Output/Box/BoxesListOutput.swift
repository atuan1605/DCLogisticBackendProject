import Vapor
import Foundation
import Fluent

struct BoxesListOutput: Content {
    let id: Box.IDValue?
    let name: String
    let lotIndex: String?
    let totalAgentCode: [String : Int]
    let createdAt: Date?
    let trackingCount: Int?
    let customItemCount: Int?
    let itemCount: Int?
}

extension Box {
    func toUncommitedOutput(on db: Database) async throws ->  BoxesListOutput {
        let lot = try await self.$lot.get(on: db)
        let trackingItems = try await self.$pieces.query(on: db)
                .with(\.$trackingItem)
                .all()
                .map { $0.trackingItem }
        let customItemCount = try await self.$customItems.query(on: db).count()
        return .init(
            id: self.id,
            name: self.name,
            lotIndex: lot?.lotIndex,
            totalAgentCode: Dictionary(grouping: trackingItems, by: { item in
                return item.agentCode ?? "N/A"
            }).mapValues{
                return $0.count
            },
            createdAt: self.createdAt,
            trackingCount: trackingItems.count,
            customItemCount: customItemCount,
            itemCount: customItemCount + trackingItems.count
        )
    }
}
