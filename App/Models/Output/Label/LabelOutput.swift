import Vapor
import Foundation

struct LabelOutput: Content {
    var id: Label.IDValue?
    var trackingNumber: String
    var quantity: Int
    var warehouseName: String?
    var agentCode: Agent.IDValue
    var reference: String?
    var productName: String?
    var customerCode: String?
    var superLabelID: Label.IDValue?
    var receivedAtUSAt: Date?
    var receivedAtVNAt: Date?
    var flyingBackAt: Date?
    var simplifiedTrackingNumber: String
    var subLabels: [LabelOutput]?
    var printedAt: Date?
}

extension Label {
    func output() -> LabelOutput {
        return .init(
            id: self.id,
            trackingNumber: self.trackingNumber,
            quantity: self.quantity,
            warehouseName: self.$warehouse.value?.name,
            agentCode: self.$agent.id,
            reference: self.reference,
            productName: self.$labelProduct.value?.name,
            customerCode: self.$customer.value?.customerCode,
            superLabelID: self.$superLabel.id,
            receivedAtUSAt: self.$trackingItem.value??.receivedAtUSAt,
            receivedAtVNAt: self.$trackingItem.value??.boxedAt,
            flyingBackAt: self.$trackingItem.value??.flyingBackAt,
            simplifiedTrackingNumber: self.simplifiedTrackingNumber,
            subLabels: self.$subLabels.value?.map{ $0.output() },
            printedAt: self.printedAt
        )
    }
}
