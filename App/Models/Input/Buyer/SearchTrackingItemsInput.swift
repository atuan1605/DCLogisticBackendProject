import Foundation
import Vapor

struct SearchTrackingItemsInput: Content {
    
    let trackingNumbers: [String]
}

extension SearchTrackingItemsInput {
    func validTrackingNumbers() -> [String] {
        return self.trackingNumbers.compactMap { $0.requireValidTrackingNumber() }
    }
}

extension SearchTrackingItemsInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("trackingNumbers", as: [String].self, is: !.empty)
    }
}
