import Foundation
import Vapor

struct VideoDownloadingJobIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let queueID = request.parameters.get(VideoDownloadingJob.parameter, as: VideoDownloadingJob.IDValue.self) {
            let queue = try await VideoDownloadingJob.find(queueID, on: request.db)
            request.videoDownloadingJob = queue
        }
        return try await next.respond(to: request)
    }
}

struct VideoDownloadingJobKey: StorageKey {
    typealias Value = VideoDownloadingJob
}

extension Request {
    var videoDownloadingJob: VideoDownloadingJob? {
        get {
            self.storage[VideoDownloadingJobKey.self]
        }
        set {
            self.storage[VideoDownloadingJobKey.self] = newValue
        }
    }

    func requireVideoDownloadingJob() throws -> VideoDownloadingJob {
        guard let videoDownloadingJob = self.videoDownloadingJob else {
            throw AppError.videoDownloadingJobNotFound
        }
        return videoDownloadingJob
    }

}
