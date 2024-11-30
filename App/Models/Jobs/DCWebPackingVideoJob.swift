import Foundation
import Vapor
import Fluent
import Queues

struct DCWebPackingVideoJob: AsyncJob {
    struct Payload: Content {
        var warehouse: Warehouse
        var videoDownloadingJobID: VideoDownloadingJob.IDValue
    }
    func dequeue(_ context: Queues.QueueContext, _ payload: Payload) async throws {
        let db = context.application.db
        guard let server = payload.warehouse.dvrDomain,
              let username = payload.warehouse.dvrAccount,
              let password = payload.warehouse.dvrPassword else {
            throw AppError.cannotExtractPackingVideo
        }
        guard let videoDownloadingJob = try await VideoDownloadingJob.query(on: db)
            .filter(\.$id == payload.videoDownloadingJobID)
            .first()
        else {
            throw AppError.videoDownloadingJobNotFound
        }
        do {
            let process = Process()
            if let pythonPath = Environment.process.PYTHON_LAUNCH_PATH {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
                process.executableURL = URL(fileURLWithPath: pythonPath)
                process.arguments = [
                    "main.py",
                    "--server",
                    "\(server)",
                    "--user",
                    "\(username)",
                    "--password",
                    "\(password)",
                    "--starttime",
                    "\(dateFormatter.string(from: videoDownloadingJob.payload.startDate))",
                    "--endtime",
                    "\(dateFormatter.string(from: videoDownloadingJob.payload.endDate))",
                    "--concat",
                    "--trim",
                    "--cameras=\(videoDownloadingJob.payload.channel)",
                    "--videoname",
                    "\(videoDownloadingJob.payload.trackingID.uuidString)"
                ]
                let stdout = Pipe()
                process.standardOutput = stdout
                try process.run()
                process.waitUntilExit()
            }
            videoDownloadingJob.finishedAt = Date()
            try await videoDownloadingJob.save(on: db)
        } catch (let error) {
            print(error)
        }
        
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        let db = context.application.db
        let encoder = JSONEncoder()
        guard let videoDownloadingJob = try await VideoDownloadingJob.query(on: db)
            .filter(\.$id == payload.videoDownloadingJobID)
            .first()
        else {
            throw AppError.videoDownloadingJobNotFound
        }
        let data = try encoder.encode(payload)
        let failedJob = FailedJob(payload: data, jobIdentifier: String(describing: Self.self), error: "\(error)", trackingNumber: videoDownloadingJob.payload.trackingID.uuidString)
        try await failedJob.save(on: db)
        videoDownloadingJob.finishedAt = Date()
        try await videoDownloadingJob.save(on: db)
    }
}

