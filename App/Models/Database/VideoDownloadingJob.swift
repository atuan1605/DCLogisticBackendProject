import Vapor
import Foundation
import Fluent

final class VideoDownloadingJob: Model, @unchecked Sendable {
    static let schema: String = "video_downloading_jobs"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Timestamp(key: "deleted_at", on: .delete)
    var deletedAt: Date?
    
    @OptionalField(key: "finished_at")
    var finishedAt: Date?
    
    @Field(key: "payload")
    var payload: Payload
    
    @Parent(key: "tracking_id")
    var trackingItem: TrackingItem
    
    struct Payload: Codable {
        var trackingID: TrackingItem.IDValue
        var startDate: Date
        var endDate: Date
        var channel: String
    }
    
    init( ) { }
    
    init (trackingID: TrackingItem.IDValue, payload: VideoDownloadingJob.Payload) {
        self.$trackingItem.id = trackingID
        self.payload = payload
    }
}

extension VideoDownloadingJob: Parameter { }
