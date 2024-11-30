import Vapor
import Foundation

struct GetPackBoxesByCustomerOutput: Content {
    var id: PackBox.IDValue?
    var name: String
    var weight: Double
    var status: Bool
    var trackingItems: [GetPackedAtVNItemsOutput]?
}

extension PackBox {
    func toCustomerOutput() -> GetPackBoxesByCustomerOutput {
        let check = self.weight != nil && !self.trackingItems.isEmpty
        return .init(
            id: self.id,
            name: self.name,
            weight: self.weight ?? 0,
            status: check,
            trackingItems: trackingItems.map{ $0.toPackedAtVNOutput() }
        )
    }
}

