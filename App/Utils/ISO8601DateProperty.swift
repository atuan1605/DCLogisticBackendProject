//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import SwiftDate

@propertyWrapper
public struct ISO8601Date: Codable {
    internal var value: Date

    public var wrappedValue: Date {

        get { return value }
        set { value = newValue }

    }

    public init(date: Date) {
        self.value = date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        if let date = Date(isoDate: dateString) {
            self.value = date
        } else {
            throw AppError.invalidInput
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value.toISODate())
    }
}

@propertyWrapper
public struct ISO8601DateTime: Codable {
    internal var value: Date

    public var wrappedValue: Date {

        get { return value }
        set { value = newValue }

    }

    public init(date: Date) {
        self.value = date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        if let date = Date(isoDateTime: dateString) {
            self.value = date
        } else {
            throw AppError.invalidInput
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value.toISO())
    }
}

@propertyWrapper
public struct OptionalISO8601Date: Codable {
    internal var value: Date?

    public var wrappedValue: Date? {

        get { return value }
        set { value = newValue }

    }

    public init(date: Date?) {
        self.value = date
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = nil
        } else {
            let dateString = try container.decode(String.self)

            if let date = Date(isoDate: dateString) {
                self.value = date
            } else {
                throw AppError.invalidInput
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value?.toISODate())
    }
}

