import Vapor
import Foundation

struct GetRepackingItemsOutput: Content {
    var items: [String: [TrackingItemOutput]]
}

extension GetRepackingItemsOutput{
    init(items: [TrackingItem]){
        let result = items.reduce([String: [TrackingItem]]()){ carry, next in
            guard
                let repackingDate = next.repackingAt
            else{
                return carry
            }
            var newCarry = carry
            let key = repackingDate.toISODate()
            var targetArray = [TrackingItem]()
            
            if let existingArray = carry[key] {
                targetArray = existingArray
            }
            
            targetArray.append(next)
            newCarry[key] = targetArray.sortCreatedAtDescending()
            return newCarry
            
        }
        self.items = result.mapValues {
            return $0.map { $0.output() }
        }
    }
}
