import Vapor
import Foundation

struct GetTrackingItemPieceOutput: Content {
    var id: TrackingItemPiece.IDValue?
    var information: String?
    var createdAt: Date?
    var trackingNumber: String
    var boxName: String?
    var shipment: String?
    var lot: String?
    var boxID: Box.IDValue?
    var shipmentID: Shipment.IDValue?
    var lotID: Lot.IDValue?
}

extension TrackingItemPiece {
    func output(trackingNumber: String) -> GetTrackingItemPieceOutput {
        return .init(
            id: self.id,
            information: self.information,
            createdAt: self.createdAt,
            trackingNumber: trackingNumber,
            boxName: self.$box.wrappedValue?.name,
            shipment: self.$box.wrappedValue?.$shipment.wrappedValue?.shipmentCode,
            lot: self.$box.wrappedValue?.$lot.wrappedValue?.lotIndex,
            boxID: self.$box.wrappedValue?.id,
            shipmentID: self.$box.wrappedValue?.$shipment.id,
            lotID: self.$box.wrappedValue?.$lot.wrappedValue?.id
        )
    }
}
