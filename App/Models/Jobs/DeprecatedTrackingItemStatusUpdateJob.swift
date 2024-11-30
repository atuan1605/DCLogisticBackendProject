import Foundation
import Vapor
import Fluent
import Queues


struct DeprecatedTrackingItemStatusUpdateJob: AsyncJob {
    struct Payload: Codable {
        var trackingNumber: String
        var status: TrackingItem.Status
        var timestampt: Date
    }

    func dequeue(_ context: Queues.QueueContext, _ payload: Payload) async throws {
        let client = context.application.client
		
		if context.application.isLoggingToGoogleSheetEnabled {
			let googleRepo = DefaultGoogleCloudRepository(
				config: context.application.googleCloudConfig!,
				client: client
			)

			try await googleRepo.addValueToSpreadSheet(
				sheetID: context.application.googleCloudSpreadSheet,
				sheetRange: payload.status.rawValue,
				values: [payload.timestampt.toISOString(), payload.trackingNumber]
			)
		}

//        let dcClient = DefaultDCClientRepository(
//            baseURL: Environment.process.DCClient_BASE_URL ?? "",
//            client: client
//        )
//
//        try await dcClient.pushTrackedItemStatus(
//            timestampt: payload.timestampt,
//            trackingNumber: payload.trackingNumber,
//            status: payload.status
//        )
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        let db = context.application.db
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let failedJob = FailedJob(payload: data, jobIdentifier: String(describing: Self.self), error: "\(error)", trackingNumber: payload.trackingNumber)
        try await failedJob.save(on: db)
    }
}
