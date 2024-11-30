import Vapor
import Foundation
import Fluent

struct BoxOutput: Content {
    let id: Box.IDValue?
    let name: String
    let agentCodes: [String]?
    let weight: Double?
    let trackingItems: [TrackingItemPieceInBoxOutput]?
    let trackingItemsCount: Int?
    let lotIndex: String?
    let customItems: [BoxCustomItemOutput]?
    
    init(id: Box.IDValue? = nil, name: String, agentCodes: [String]? = nil, weight: Double? = nil, trackingItems: [TrackingItemPieceInBoxOutput]? = nil, lotIndex: String?, trackingItemsCount: Int? = nil, customItems: [BoxCustomItemOutput]? = nil) {
        self.id = id
        self.name = name
        self.agentCodes = agentCodes
        self.weight = weight
        self.trackingItems = trackingItems
        self.lotIndex = lotIndex
        self.trackingItemsCount = trackingItemsCount
        self.customItems = customItems
    }
}

extension Box {
    func output() -> BoxOutput {
        .init(
            id: self.id,
            name: self.name,
            agentCodes: self.agentCodes,
            weight: self.weight,
            lotIndex: self.$lot.value??.lotIndex
        )
    }
    
    func toListOutput() async throws -> BoxOutput {
        let trackingItems = try self.pieces.compactMap{ $0.trackingItem }.removingDuplicates{ $0.id }
        return .init(
            id: self.id,
            name: self.name,
            weight: self.weight,
            lotIndex: self.$lot.value??.lotIndex,
            trackingItemsCount: trackingItems.count + self.customItems.count
        )
    }

    func toOutput(groupedChain: [String?: [TrackingItem]]? = nil, on db: Database) async throws -> BoxOutput {
        
        let trackingItemPieces = self.$pieces.value
        let trackingItems = try trackingItemPieces?
            .compactMap { $0.$trackingItem.value }
            .removingDuplicates { $0.id }
        
        let trackingItemPiecesWithReceivedAtVN = trackingItemPieces?.filter {
            $0.receivedAtVNAt != nil
        }.sorted { lhs, rhs in
            guard let lhsReceivedAtVNAt = lhs.receivedAtVNAt,
                  let rhsReceivedAtVNAt = rhs.receivedAtVNAt else {
                return false
            }
            return lhsReceivedAtVNAt.compare(rhsReceivedAtVNAt) == .orderedDescending
        }
        
        let trackingItemPiecesWithoutReceivedAtVN = trackingItemPieces?.filter {
            $0.receivedAtVNAt == nil
        }.sorted { lhs, rhs in
            guard let lhsBoxedAt = lhs.boxedAt,
                  let rhsBoxedAt = rhs.boxedAt else {
                return false
            }
            return lhsBoxedAt.compare(rhsBoxedAt) == .orderedAscending
        }
        return .init(
            id: self.id,
            name: self.name,
            agentCodes: self.agentCodes,
            weight: self.weight,
            trackingItems: try [trackingItemPiecesWithReceivedAtVN, trackingItemPiecesWithoutReceivedAtVN].compactMap { $0 }.flatMap { $0 }.map { piece in
                let chain = piece.trackingItem.chain
                let count = groupedChain?[chain]?.count
                return try piece.toOutput(totalTrackingInChain: count)
            },
            lotIndex: self.$lot.value??.lotIndex,
            trackingItemsCount: (trackingItems?.count ?? 0) + (self.$customItems.value?.count ?? 0),
            customItems: self.$customItems.value?.map { $0.output() }
        )
    }
}

