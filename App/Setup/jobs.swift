//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import Vapor
import QueuesRedisDriver
import Queues

public func jobs(app: Application) throws {
//    let emailJob = EmailJob()
//    app.queues
//        .add(emailJob)
//    app.queues.add(DeprecatedTrackingItemStatusUpdateJob())
//    app.queues.add(FaultyTrackingItemNotificationJob())
//    app.queues.add(TrackingItemStatusUpdateJob())
//    app.queues.add(ExtractPackingVideoJob())
//    app.queues
//        .schedule(PeriodicallyUpdateJob())
//        .minutely()
//        .at(0)

    if !app.environment.isRelease && app.environment != .testing {
//        app.logger.log(level: .error, "RUNNING APP AT NON-PRODUCTION")
        try app.queues.startInProcessJobs()
        try app.queues.startScheduledJobs()
    }
}

