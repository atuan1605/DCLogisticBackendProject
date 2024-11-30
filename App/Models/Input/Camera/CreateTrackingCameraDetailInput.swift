import Foundation
import Vapor

struct CreateTrackingCameraDetailInput: Content {
    let cameraID: String
    let step: TrackingCameraDetail.Step
    let deviceID: String?
}

extension CreateTrackingCameraDetailInput {
    
    func toTrackingCameraDetail(trackingID: TrackingItem.IDValue) -> TrackingCameraDetail {
        .init(
            trackingItemID: trackingID,
            cameraID: self.cameraID,
            step: self.step,
            deviceID: self.deviceID)
    }
}
