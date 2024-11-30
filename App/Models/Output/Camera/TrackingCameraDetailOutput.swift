import Foundation
import Vapor

struct TrackingCameraDetailOutput: Content {
    var id: TrackingCameraDetail.IDValue?
    var trackingItemID: TrackingItem.IDValue?
    var cameraID: Camera.IDValue?
    var step: TrackingCameraDetail.Step?
    var deviceID: String?
    var recordFinishAt: Date?
}

extension TrackingCameraDetail {
    
    func output() -> TrackingCameraDetailOutput {
        .init(
            id: self.id,
            trackingItemID: self.$trackingItem.id,
            cameraID: self.$camera.id,
            step: self.step,
            deviceID: self.deviceID,
            recordFinishAt: self.recordFinishAt)
    }
}
