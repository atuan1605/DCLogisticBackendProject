import Foundation
import Vapor

struct CreateMultipleBuyerTrackingItemInput: Content {
    var trackingNumbers: [String]
    var requestType: BuyerTrackingItem.RequestType
    var note: String?
    var packingRequest: String?
    var quantity: Int?
    var deposit: Int?
}

extension CreateMultipleBuyerTrackingItemInput {
    
    func isValid() -> Bool {
        if self.requestType == .specialRequest {
            let packingRequest = self.packingRequest ?? ""
            let quantity = self.quantity ?? 0
            let hasPackingRequest = !packingRequest.isEmpty && quantity == 0 // Có packing request và ko có quantity
            let hasQuantityCheck = quantity > 10 && packingRequest.isEmpty // Có quantity và ko có packing request
            let hasBothCheck = !packingRequest.isEmpty && quantity > 10 // có cả packing request và cả quantity
            return hasPackingRequest || hasQuantityCheck || hasBothCheck
        } else if self.requestType == .quantityCheck {
            let quantity = self.quantity ?? 0
            return quantity > 1 && quantity <= 10 && self.deposit == nil
        }
        return self.deposit == nil
    }
    
    func validTrackingNumbers() -> [String] {
        return self.trackingNumbers.compactMap { $0.requireValidTrackingNumber() }
    }
    
    func toBuyerTrackingItems(buyerID: Buyer.IDValue) -> [BuyerTrackingItem] {
        return trackingNumbers.map({ trackingNumber in
                .init(
                    note: self.note ?? "",
                    packingRequest: self.packingRequest ?? "",
                    buyerID: buyerID,
                    trackingNumber: trackingNumber,
                    quantity: self.quantity,
                    deposit: self.deposit,
                    requestType: self.requestType)
        })
    }
}
