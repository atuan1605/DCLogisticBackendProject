import Foundation
import Vapor

struct UpdateProccessingCustomerRequestInput: Content {
    var quantity: Int?
    var note: String?
    var packingRequestState: BuyerTrackingItem.PackingRequestState?
}
