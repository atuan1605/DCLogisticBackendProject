import Vapor
import Foundation

struct UpdateBuyerTrackingItemsDepositInput: Content {
    var buyerTrackingItemIDs: [BuyerTrackingItem.IDValue]
}
