import Foundation
import Vapor

typealias GetTrackingImagesOutput = [TrackingImageOutput]

struct TrackingImageOutput: Content {
    var agent: String
    var fileID: String
}
