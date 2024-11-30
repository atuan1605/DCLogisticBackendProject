import Foundation
import Vapor
import Fluent

final class TrackingCameraDetail: Model, @unchecked Sendable {
    
    static let schema: String = "tracking_camera_details"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "tracking_item_id")
    var trackingItem: TrackingItem
    
    @Parent(key: "camera_id")
    var camera: Camera
    
    @Field(key: "step")
    var step: Step
    
    @OptionalField(key: "device_id")
    var deviceID: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @OptionalField(key: "record_finish_at")
    var recordFinishAt: Date?
    
    init() {}
    
    init(
        trackingItemID: TrackingItem.IDValue,
        cameraID: Camera.IDValue,
        step: Step,
        deviceID: String? = nil) {
            self.$trackingItem.id = trackingItemID
            self.$camera.id = cameraID
            self.step = step
            self.deviceID = deviceID
    }
}

extension TrackingCameraDetail: Parameter {}

extension TrackingCameraDetail {
    
    enum Step: String, Codable {
        case pack
    }
}
