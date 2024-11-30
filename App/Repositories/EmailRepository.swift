//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import Vapor
import Fluent
import SendGrid
import Queues

struct AppFrontendURL: StorageKey {
    typealias Value = String
}

extension Application {
    var appFrontendURL: String? {
        get { self.storage[AppFrontendURL.self] }
        set { self.storage[AppFrontendURL.self] = newValue }
    }
}

protocol EmailRepository {
    func sendResetPasswordEmail(for buyer: Buyer,
                                resetPasswordToken: BuyerResetPasswordToken) throws -> EventLoopFuture<Void>
}

struct SendGridEmailRepository: EmailRepository {
    let appFrontendURL: String
    let queue: Queue
    let db: Database
    let eventLoop: EventLoop
    
    private func sendEmail(to address: String, title: String, content: String) throws -> EventLoopFuture<Void> {
        let payload = EmailJobPayload(destination: address,
                                       title: title, content: content)
        if Environment.get("REDIS_URL") != nil {
            return self.queue.dispatch(EmailJob.self,
                payload,
                maxRetryCount: 3)
        } else {
            return self.eventLoop.future()
        }
    }
    
    func sendResetPasswordEmail(for buyer: Buyer,
                                resetPasswordToken: BuyerResetPasswordToken) throws -> EventLoopFuture<Void> {
        let emailTitle = "Reset Mật khẩu"
        let emailContent = """
        <p>Để reset lại mật khẩu, vui lòng click vào <a clicktracking=off href="\(self.appFrontendURL)/resetpassword?token=\(resetPasswordToken.value)">link</a>.</p>
        """
        
        return try self.sendEmail(to: buyer.email,
                                  title: emailTitle,
                                  content: emailContent)
    }
}

struct EmailRepositoryRepositoryFactory: Sendable {
    var make: (@Sendable (Request) -> EmailRepository)?
    
    mutating func use(_ make: @escaping (@Sendable (Request) -> EmailRepository)) {
        self.make = make
    }
}

extension Application {
    private struct EmailRepositoryRepositoryKey: StorageKey, Sendable {
        typealias Value = EmailRepositoryRepositoryFactory
    }

    var emails: EmailRepositoryRepositoryFactory {
        get {
            self.storage[EmailRepositoryRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[EmailRepositoryRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var emails: EmailRepository {
        self.application.emails.make!(self)
    }
}



