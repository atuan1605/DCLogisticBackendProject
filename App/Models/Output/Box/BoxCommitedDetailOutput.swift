import Vapor
import Foundation

struct BoxCommitedDetailOutput: Content {
    let grouped: [String: [String: [TrackingItemOutput]]]?
}

extension BoxCommitedDetailOutput {
    init(items: [TrackingItem]) {
        self.grouped = Dictionary.init(grouping: items) { item in
            guard let flyingBackAt = item.flyingBackAt else {
                return "N/A"
            }
            return flyingBackAt.toISODate()
        }.mapValues { value in
            return Dictionary.init(grouping: value) { item in
                return item.chain ?? "N/A"
            }.mapValues {
                $0.map {
                    $0.output()
                }
            }
        }
    }
}
