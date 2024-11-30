import Vapor
import Foundation

struct GetTrackingInfoForBoxedStepOutput: Content {
    var trackingID: TrackingItem.IDValue?
    var piecesWithoutBoxCount: Int?
    var warningState: [WarningState]
    var packingRequestDetail: String?
}

enum WarningState: String, Content{
    case returnTracking
    case pieces
    case noImage
    case packingRequest
}
