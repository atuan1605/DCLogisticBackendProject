import Foundation
import Vapor

struct GetRepackingTotalsOutput: Content {
    let allTime: [String: Int]
    let today: [String: Int]
    let yesterday: [String: Int]
}

extension GetRepackingTotalsOutput {
    init(items: [TrackingItem]) throws {
        // ["DC": [TrackingItem1, TrackingItem2, ...], "HNC": [...], "N/A": [...]]

        // logic
        self.allTime = Dictionary(grouping: items, by: { item in
            return item.agentCode ?? "N/A"
        }).mapValues {
            return $0.count
        }

        let today = Date().toISODate()
        let tomorrow = Date().addingTimeInterval(.oneDay).toISODate()
        let todayItems = items.filter { item in
            guard let receivedAtUSAt = item.receivedAtUSAt else {
                return false
            }
            
            return receivedAtUSAt.toISODate() >= today && receivedAtUSAt.toISODate() < tomorrow
        }
        self.today = Dictionary(grouping: todayItems, by: { item in
            return item.agentCode ?? "N/A"
        }).mapValues {
            return $0.count
        }
        let yesterday = Date().addingTimeInterval(.oneDay*(-1)).toISODate()
        let yesterdayItems = items.filter { item in
            guard let receivedAtUSAt = item.receivedAtUSAt else {
                return false
            }
            
            return receivedAtUSAt.toISODate() >= yesterday && receivedAtUSAt.toISODate() < today
        }
        self.yesterday = Dictionary(grouping: yesterdayItems, by: { item in
            return item.agentCode ?? "N/A"
        }).mapValues {
            return $0.count
        }
    }
}
