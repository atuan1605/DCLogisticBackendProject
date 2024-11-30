import Foundation
import Vapor
import Fluent
import Queues


struct FaultyTrackingItemNotificationJob: AsyncJob {
    struct Payload: Content {
        var trackingNumber: String
        var faultDescription: String
        var receivedAtUSAt: Date
    }

    func dequeue(_ context: Queues.QueueContext, _ payload: Payload) async throws {
        let client = context.application.client

        let dcClient = DefaultDCClientRepository(
            baseURL: Environment.process.DCClient_BASE_URL ?? "",
            client: client
        )

        try await dcClient.notifyFaultyTrackingItem(
            trackingNumber: payload.trackingNumber,
            faultDescription: payload.faultDescription,
            receivedAtUSAt: payload.receivedAtUSAt
        )
    }

    func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
        let db = context.application.db
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let failedJob = FailedJob(payload: data, jobIdentifier: String(describing: Self.self), error: "\(error)", trackingNumber: payload.trackingNumber)
        try await failedJob.save(on: db)
    }
}
