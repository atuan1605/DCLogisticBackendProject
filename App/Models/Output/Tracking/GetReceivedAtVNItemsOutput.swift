import Vapor
import Foundation

struct GetReceivedAtVNItemsOutput: Content {
    var items: [String : [TrackingItemOutput]]
}

extension GetReceivedAtVNItemsOutput {
    init(items: [TrackingItem]) {
        self.items = Dictionary(grouping: items) { item in
            guard
                let receivedAtVnDate = item.receivedAtVNAt
            else {
                return "No Date"
            }
            return receivedAtVnDate.toISODate()
        }.mapValues {
            $0.sortCreatedAtDescending().map{ $0.output() } }
        }
}
                     
