import Vapor
import Foundation

struct TrackingItemPieceReportOutput: Content {
    var id: TrackingItemPiece.IDValue?
    var trackingNumber: String?
    var information: String?
    var receivedAtUSAt: Date?
    var flyingBackAt: Date?
    var files: [String]?
    var receivedAtVNAt: Date?
    var customers: String?
}

extension TrackingItemPiece {
    func reportOutput() -> TrackingItemPieceReportOutput {
        let customerCode = self.$trackingItem.value?.$customers.value?.filter{ !$0.customerCode.isEmpty }
        var targetCustomer: String? = nil
        if let customerCode = customerCode, !customerCode.isEmpty {
            targetCustomer = customerCode.map(\.customerCode).joined(separator: ", ")
        }
        return .init(
            id: self.id,
            trackingNumber: self.$trackingItem.value?.trackingNumber,
            information: self.information,
            receivedAtUSAt: self.$trackingItem.value?.receivedAtUSAt,
            flyingBackAt: self.flyingBackAt,
            files: self.$trackingItem.value?.$products.value?.first?.images,
            receivedAtVNAt: self.$trackingItem.value?.receivedAtVNAt,
            customers: targetCustomer
        )
    }
}
