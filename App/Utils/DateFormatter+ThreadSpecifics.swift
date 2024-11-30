//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Vapor
import NIO

fileprivate final class PSAISO8601 {
    nonisolated(unsafe) fileprivate static let threadSpecific: ThreadSpecificVariable<ISO8601DateFormatter> = .init()
}

extension ISO8601DateFormatter {
    static var psaThreadSpecific: ISO8601DateFormatter {
        if let existing = PSAISO8601.threadSpecific.currentValue {
            return existing
        } else {
            let new = ISO8601DateFormatter()
            PSAISO8601.threadSpecific.currentValue = new
            return new
        }
    }
}
