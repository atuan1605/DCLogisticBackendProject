import Vapor
import Foundation

struct TrackingItemCountByDateOutput: Content {
    var total: Int
    var files: Int
    var flyingBack: Int
    var unflyingBack: Int
}

extension TrackingItemCountByDateOutput {
    init(items: [TrackingItem]) {
        self.total = items.count
        self.files = items.filter { ($0.$products.value?.first?.images != nil) }.count
        self.flyingBack = items.filter{ $0.flyingBackAt != nil }.count
        self.unflyingBack = items.filter{ $0.flyingBackAt == nil }.count
    }
}
