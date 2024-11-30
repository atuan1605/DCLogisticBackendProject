import Foundation
import Vapor

struct BuyerTrackingItemLinkViewOutput: Content {
    var buyerTrackingItem: BuyerTrackingItemOutput?
    var trackingItem: TrackingItemOutput?
}

extension BuyerTrackingItemLinkView {
    
    func output() -> BuyerTrackingItemLinkViewOutput {
        let trackingItem = self.$trackingItem.value?.output()
        let buyerTrackingItem = self.$buyerTrackingItem.value?.output()
        return .init(
            buyerTrackingItem: buyerTrackingItem,
            trackingItem: trackingItem)
    }
    
    func output(currentBuyerEmail: String) -> BuyerTrackingItemLinkViewOutput {
        var trackingItem = self.$trackingItem.value?.output()
        let buyerTrackingItem = self.$buyerTrackingItem.value?.output()
        let customerEmails = trackingItem?.customers?.compactMap { $0.email }
        if let customerEmails = customerEmails, !customerEmails.contains(currentBuyerEmail) {
            trackingItem?.products = []
        }
        return .init(
            buyerTrackingItem: buyerTrackingItem,
            trackingItem: trackingItem)
    }
}
