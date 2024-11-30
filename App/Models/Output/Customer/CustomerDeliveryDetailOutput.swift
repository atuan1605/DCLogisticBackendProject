import Foundation
import Vapor

struct CustomerDeliveryDetailOutput: Content {
    let trackingItemsCount: Int
    let totalWeight: Double
    let productsCount: Int
    let commitedAt: Date?
    let products: [ProductOutput]
    let packBoxes: [CustomerPackBoxOutput]
}
