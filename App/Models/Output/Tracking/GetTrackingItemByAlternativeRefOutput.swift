import Vapor
import Foundation

struct TrackingItemByAlternativeRefOutput: Content {
    var id: TrackingItem.IDValue?
    var createdAt: Date?
    var trackingNumber: String?
    var alternativeRef: String?
    var boxName: String?
    var shipmentCode: String?
    var lots: String?
}

extension TrackingItem {
    func outputByAlternativeRef() -> TrackingItemByAlternativeRefOutput {
        let lotIndex = self.$pieces.value?.compactMap {
            $0.$box.wrappedValue?.$lot.value??.lotIndex
        }
        return .init(
            id: self.id,
            createdAt: self.createdAt,
            trackingNumber: self.trackingNumber,
            alternativeRef: self.alternativeRef,
            boxName: self.$pieces.value?.compactMap { $0.$box.wrappedValue?.name }.uniqued().joined(separator: ", "),
            shipmentCode: self.$pieces.value?.compactMap { $0.$box.wrappedValue?.$shipment.value??.shipmentCode }.uniqued().joined(separator: ", "),
            lots: lotIndex?.uniqued().joined(separator: ", ")
        )
    }
}
