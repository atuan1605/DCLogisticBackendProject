import Vapor
import Foundation

struct GetArchivedItemsOutput: Content {
    var items: [String: [TrackingItemOutput]]
}

extension GetArchivedItemsOutput {
    init(items: [TrackingItem]) {
        self.items = Dictionary(grouping: items) { item in
            guard
                let archiveDate = item.archivedAt
            else{
                return "No Date"
            }
            return archiveDate.toISODate()
        }.mapValues{ $0.map { $0.output()}}
    }
}
