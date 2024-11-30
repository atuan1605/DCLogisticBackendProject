import Vapor
import Foundation

struct TrackingItemDCOutput: Content {
    var id: TrackingItem.IDValue?
    var trackingNumber: String
    var stateTrails: [TrackingItemStateTrail]
    var boxedAt: Date?
    var trackingItemReferences: String?
}

struct TrackingItemStateTrail: Content {
    var state: TrackingItem.Status
    var updatedAt: Date?
}

extension TrackingItem {
    func dcOutput() -> TrackingItemDCOutput {
        var targetStates: [TrackingItemStateTrail] = []
        if self.receivedAtUSAt != nil {
            let state = TrackingItemStateTrail(state: .receivedAtUSWarehouse, updatedAt: self.receivedAtUSAt)
            targetStates.append(state)
        }
        if self.flyingBackAt != nil {
            let state = TrackingItemStateTrail(state: .flyingBack, updatedAt: self.flyingBackAt)
            targetStates.append(state)
        }
        if self.receivedAtVNAt != nil {
            let state = TrackingItemStateTrail(state: .receivedAtVNWarehouse, updatedAt: self.receivedAtVNAt)
            targetStates.append(state)
        }
        if self.deliveredAt != nil {
            let state = TrackingItemStateTrail(state: .deliveredAtVN, updatedAt: self.deliveredAt)
            targetStates.append(state)
        }
        return .init(
            id: self.id,
            trackingNumber: self.trackingNumber,
            stateTrails: targetStates,
            boxedAt: self.boxedAt,
            trackingItemReferences: self.$trackingItemReferences.value?.compactMap({ item in
                item.trackingNumber
            }).joined(separator: ", ")
        )
    }
}
