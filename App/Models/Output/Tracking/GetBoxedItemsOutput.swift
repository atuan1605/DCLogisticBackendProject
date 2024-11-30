import Vapor
import Foundation

struct GetBoxedItemsOutput : Content {
    var items: [String : [TrackingItemOutput]]
}

extension GetBoxedItemsOutput {
    init (items: [TrackingItem]) {
        self.items = Dictionary(grouping: items) { item in
            guard
                let boxedDate = item.boxedAt
            else{
                return "No Date"
            }
            return boxedDate.toISODate()
        }.mapValues{ $0.map { $0.output() } }
    }
}

