import Foundation
import Vapor
import Fluent
import Queues

struct ExtractPackingVideoJob: AsyncJob {
    
    struct Payload: Content {
        var warehouse: Warehouse
        var startDate: Date
        var endDate: Date
        var trackingID: TrackingItem.IDValue
        var channel: String
    }
    
    func dequeue(_ context: Queues.QueueContext, _ payload: Payload) async throws {
        let db = context.application.db
        let targetPayload: VideoDownloadingJob.Payload = .init(trackingID: payload.trackingID, startDate: payload.startDate, endDate: payload.endDate, channel: payload.channel)
        
        try await VideoDownloadingJob.query(on: db)
            .filter(\.$trackingItem.$id == payload.trackingID)
            .delete()
        let videoDownloadingJob = VideoDownloadingJob.init(trackingID: payload.trackingID,payload: targetPayload)
        try await videoDownloadingJob.save(on: db)
        guard let server = payload.warehouse.dvrDomain,
              let username = payload.warehouse.dvrAccount,
              let password = payload.warehouse.dvrPassword else {
            throw AppError.cannotExtractPackingVideo
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
                    "\(dateFormatter.string(from: payload.startDate))",
                    "--endtime",
                    "\(dateFormatter.string(from: payload.endDate))",
                    "--concat",
                    "--trim",
                    "--cameras=\(payload.channel)",
                    "--videoname",
                    "\(payload.trackingID.uuidString)"
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
        let data = try encoder.encode(payload)
        let failedJob = FailedJob(payload: data, jobIdentifier: String(describing: Self.self), error: "\(error)", trackingNumber: payload.trackingID.uuidString)
        try await failedJob.save(on: db)
        let videoDownloadingJob = try await VideoDownloadingJob.query(on: db)
            .filter(\.$trackingItem.$id == payload.trackingID)
            .first()
        videoDownloadingJob?.finishedAt = Date()
        try await videoDownloadingJob?.save(on: db)
    }
}
