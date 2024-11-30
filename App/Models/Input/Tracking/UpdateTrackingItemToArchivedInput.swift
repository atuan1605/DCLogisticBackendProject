import Vapor
import Foundation

struct UpdateTrackingItemToArchivedInput: Content {
    var trackingNumber: String
    var shipmentCode: String
    var boxName: String
    var agentCode: String?
}

extension UpdateTrackingItemToArchivedInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("trackingNumber", as: String.self, is: !.empty && .count(7...))
        validations.add("shipmentCode", as: String.self, is: !.empty && .alphanumeric)
        validations.add("boxName", as: String.self, is: !.empty && .alphanumeric)
    }
}

extension UpdateTrackingItemToArchivedInput {
    func toTrackingItem() throws -> TrackingItem {
        let targetTrackingNumber = self.trackingNumber.removingNonAlphaNumericCharacters()

        guard targetTrackingNumber.isValidTrackingNumber() else {
            throw AppError.invalidInput
        }

        return .init(
            trackingNumber: targetTrackingNumber,
            agentCode: self.agentCode
        )
    }
}
