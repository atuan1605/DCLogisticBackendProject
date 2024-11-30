import Vapor
import Foundation

struct GetFlyingBackItemsOutput: Content {
    var items: [String : [TrackingItemOutput]]
}

extension GetFlyingBackItemsOutput {
    init (items: [TrackingItem]) {
        self.items = Dictionary(grouping: items) {item in
            guard
                let flyingBackDate = item.flyingBackAt
            else{
                return "No Date"
            }
            return flyingBackDate.toISODate()
        }.mapValues {
            $0.map {
                $0.output() } }
    }
}

