//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import Vapor
import Fluent
import JWT

protocol GoogleCloudRepository {
    func addValueToSpreadSheet(sheetID: String, sheetRange: String, values: [String]) async throws
}

struct DefaultGoogleCloudRepository: GoogleCloudRepository {
    var config: GoogleCloudConfig
    var client: Vapor.Client

    func addValueToSpreadSheet(sheetID: String, sheetRange: String, values: [String]) async throws {
        let token = try await self.getAccessToken()
        
        //https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/values/{range}:append
        
        let uri = URI(
            scheme: .https,
            host: "sheets.googleapis.com",
            path: "v4/spreadsheets/\(sheetID)/values/\(sheetRange):append",
            query: "valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS"
        )
        
        var headers = HTTPHeaders()
        headers.contentType = .json
        headers.bearerAuthorization = .init(token: token.accessToken)
        
        let content = GCValueRange(
            range: sheetRange,
            values: [values]
        )
        
        let response = try await self.client.post(
            uri,
            headers: headers,
            content: content)

        guard response.status == .ok else {
            throw GoogleCloudError.responseError(statusCode: response.status.code, body: response.description)
        }
    }

    private func getAccessToken() async throws -> GCAccessToken {
        let key = try RSAKey.private(pem: self.config.privateKey)
        let jwt = JWTSigner.rs256(key: key)
        
        let payload = GCJWTPayload(
            iss: self.config.clientEmail,
            scope: "https://www.googleapis.com/auth/spreadsheets"
        )
        let token = try jwt.sign(payload)
        let uri = URI(string: self.config.tokenURL)
        var headers = HTTPHeaders()
        headers.contentType = .urlEncodedForm
        let content = GCAccessTokenInput(assertion: token)
        let response = try await self.client.post(
            uri,
            headers: headers,
            content: content
        )
        return try response.content.decode(GCAccessToken.self)
    }
}

enum GoogleCloudError: Error, LocalizedError {
    case responseError(statusCode: UInt, body: String?)
    
    var errorDescription: String? {
        switch self {
        case .responseError(let statusCode, let body):
            return "Response Error - Code: \(statusCode), Body: \(body ?? "N/A")"
        }
    }
}

struct GoogleCloudRepositoryFactory: Sendable {
    var make: (@Sendable (Request) -> GoogleCloudRepository)?
    
    mutating func use(_ make: @escaping (@Sendable (Request) -> GoogleCloudRepository)) {
        self.make = make
    }
}

extension Application {
    private struct GoogleCloudRepositoryKey: StorageKey, Sendable {
        typealias Value = GoogleCloudRepositoryFactory
    }
    
    var google: GoogleCloudRepositoryFactory {
        get {
            self.storage[GoogleCloudRepositoryKey.self] ?? .init()
        }
        set {
            self.storage[GoogleCloudRepositoryKey.self] = newValue
        }
    }
}

extension Request {
    var google: GoogleCloudRepository {
        self.application.google.make!(self)
    }
}

struct GoogleCloudSpreadSheetKey: StorageKey {
    typealias Value = String
}

struct IsLoggingToGoogleSheetEnabled: StorageKey {
    typealias Value = Bool
}

struct GoogleCloudConfigKey: StorageKey {
    typealias Value = GoogleCloudConfig
}

extension Application {
    func loadGoogleConfig() throws {
        let directory = self.directory.workingDirectory
        let configDir = "Sources/App/Repositories/GoogleCloud"

        let data = try Data(contentsOf: URL(fileURLWithPath: directory)
            .appendingPathComponent(configDir, isDirectory: true)
            .appendingPathComponent("dclogistics-427e110bfddf.json", isDirectory: false))
        
        let decoder = JSONDecoder()
        let config = try decoder.decode(GoogleCloudConfig.self, from: data)
        self.googleCloudConfig = config
    }

    var googleCloudConfig: GoogleCloudConfig? {
        get {
            self.storage[GoogleCloudConfigKey.self]
        }
        set {
            self.storage[GoogleCloudConfigKey.self] = newValue
        }
    }

    var googleCloudSpreadSheet: String {
        get {
            self.storage[GoogleCloudSpreadSheetKey.self] ?? ""
        }
        set {
            self.storage[GoogleCloudSpreadSheetKey.self] = newValue
        }
    }

    var isLoggingToGoogleSheetEnabled: Bool {
        get {
            self.storage[IsLoggingToGoogleSheetEnabled.self] ?? false
        }
        set {
            self.storage[IsLoggingToGoogleSheetEnabled.self] = newValue
        }
    }
}

