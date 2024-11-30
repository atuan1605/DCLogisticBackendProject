import Foundation
import Vapor

struct CreateTrackingItemInput: Content {
    var trackingReferences: [String]?
    var trackingNumber: String
    var agentCode: String?
    var warehouseID: Warehouse.IDValue?
}

extension CreateTrackingItemInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("trackingNumber", as: String.self, is: .init(validate: { value in
            TrackingNumberValidatorResult(trackingNumber: value)
        }))
    }
}

struct TrackingNumberValidatorResult: ValidatorResult {
    var isFailure: Bool {
        return !trackingNumber.isValidTrackingNumber()
    }
    var trackingNumber: String
    var successDescription: String? = "tracking number validated"
    var failureDescription: String? = "invalid tracking number"
    
    init(trackingNumber: String) {
        self.trackingNumber = trackingNumber
    }
}

extension CreateTrackingItemInput {
    func toTrackingItem() throws -> TrackingItem {
		guard let targetTrackingNumber = self.trackingNumber.requireValidTrackingNumber() else {
            throw AppError.invalidInput
        }

        return .init(
            trackingNumber: targetTrackingNumber,
            agentCode: self.agentCode,
            warehouseID: self.warehouseID
        )
    }
}
