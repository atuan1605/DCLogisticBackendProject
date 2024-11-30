import Foundation
import Vapor

/*
 {
    "ISODate": {
        "ChainID": [
            TrackingItem1,
            TrackingItem2
        ]
    }
 }
 */

struct GetRepackedItemsOutput: Content {
    var grouped: [String: [String: [TrackingItemOutput]]]
}

extension GetRepackedItemsOutput {
    init(items: [TrackingItem] ){
        // [String: [TrackingItem]]
        self.grouped = Dictionary.init(grouping: items) { item in
            guard let repackedAt = item.repackedAt else {
                return "N/A"
            }
            return repackedAt.toISODate()
        }.mapValues { value in
            // [String: [String: [TrackingItem]]]
            return Dictionary.init(grouping: value) { item in
                return item.chain ?? "N/A"
            }.mapValues {
                // [String: [String: [TrackingItemOutput]]]
                $0.map { $0.output() }
            }
        }
    }
}

/*
 {
    "ISODate": [
        {
            chainID: String,
            items: [TrackingItemOutput]
        }
    ]
 }
 */


struct GetRepackedItemsOutput2: Content {
    var grouped: [String: [Chain]]

    struct Chain: Content {
        let chainID: String
        let items: [TrackingItemOutput]
    }
}

extension GetRepackedItemsOutput2 {
    init(items: [TrackingItem]) {
        // [String: [TrackingItem]]
        self.grouped = Dictionary.init(grouping: items) { item in
            guard let repackedAt = item.repackedAt else {
                return "N/A"
            }
            return repackedAt.toISODate()
        }.mapValues { value in
            // [TrackingItem] => [Chain]
            let groupedByChain = Dictionary.init(grouping: value) { item in
                return item.chain ?? "N/A"
            } // => [String: [TrackingItem]]
            
            return groupedByChain.keys.map { chainID in
                return Chain.init(
                    chainID: chainID,
                    items: groupedByChain[chainID]?.sortCreatedAtDescending().map { $0.output() } ?? []
                )
            }
        }
    }
}







