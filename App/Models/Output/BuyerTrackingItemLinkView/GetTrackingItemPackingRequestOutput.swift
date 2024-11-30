import Vapor
import Foundation

struct GetTrackingItemPackingRequestOutput: Content {
    var id: BuyerTrackingItemLinkView.IDValue?
    var trackingNumber: String?
    var packingRequest: String?
    var status: PackingRequestStatus
}

extension BuyerTrackingItemLinkView {
    func packingRequestOutput() -> GetTrackingItemPackingRequestOutput {
        var status: PackingRequestStatus = PackingRequestStatus.unprocessed
        if (self.$trackingItem.value?.repackedAt != nil 
            && self.$buyerTrackingItem.value?.createdAt ?? .distantPast < self.$trackingItem.value?.repackedAt ?? .distantPast) {
            status = PackingRequestStatus.processed
        }
        
        return .init(
            id: self.id,
            trackingNumber: self.$trackingItem.value?.trackingNumber,
            packingRequest: self.$buyerTrackingItem.value?.packingRequest,
            status: status
        )
    }
}
enum PackingRequestStatus: String, Content {
    case processed
    case unprocessed
}
