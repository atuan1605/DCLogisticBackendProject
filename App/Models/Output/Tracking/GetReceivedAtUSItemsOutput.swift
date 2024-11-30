import Foundation
import Vapor

struct GetReceivedAtUSItemsOutput: Content {
    var items: [String: [TrackingItemOutput]]
}

extension GetReceivedAtUSItemsOutput {
    init(items: [TrackingItem]) {
//        var result: [String: [TrackingItemOutput]] = [:]

//        items.forEach { item in
//            guard
//                let receivedAtUSDate = item.receivedAtUSAt
//            else {
//                return
//            }
//            let key = receivedAtUSDate.toISODate()
//
//            if var existingArray = result[key] {
//                existingArray.append(item.toOutput())
//                result[key] = existingArray
//            } else {
//                result[key] = [item.toOutput()]
//            }
//        }

//        items.forEach { item in
//            guard
//                let receivedAtUSDate = item.receivedAtUSAt
//            else {
//                return
//            }
//            let key = receivedAtUSDate.toISODate()
//            var targetArray = [TrackingItemOutput]()
//
//            if let existingArray = result[key] {
//                targetArray = existingArray
//            }
//
//            targetArray.append(item.toOutput())
//            result[key] = targetArray
//        }
        
//        result = items.reduce([String: [TrackingItemOutput]]()) { carry, next in
//            guard
//                let receivedAtUSDate = next.receivedAtUSAt
//            else {
//                return carry
//            }
//            var newCarry = carry
//            let key = receivedAtUSDate.toISODate()
//            var targetArray = [TrackingItemOutput]()
//
//            if let existingArray = carry[key] {
//                targetArray = existingArray
//            }
//
//            targetArray.append(next.toOutput())
//            newCarry[key] = targetArray
//            return newCarry
//        }
        
//        self.items = result
        
        self.items = Dictionary(grouping: items) { item in
            guard
                let receivedAtUSDate = item.receivedAtUSAt
            else {
                return "No Date"
            }
            return receivedAtUSDate.toISODate()
        }.mapValues { $0.sortCreatedAtDescending().map { $0.output() } }
    }
}
