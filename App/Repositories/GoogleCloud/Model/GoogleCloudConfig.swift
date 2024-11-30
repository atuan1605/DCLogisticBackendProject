//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation

struct GoogleCloudConfig: Codable {
    var type: String
    var projectID: String
    var privateKeyID: String
    var privateKey: String
    var clientEmail: String
    var clientID: String
    var authURI: String
    var tokenURL: String
}

extension GoogleCloudConfig {
    enum CodingKeys: String, CodingKey {
        case type
        case projectID = "project_id"
        case privateKeyID = "private_key_id"
        case privateKey = "private_key"
        case clientEmail = "client_email"
        case clientID = "client_id"
        case authURI = "auth_uri"
        case tokenURL = "token_uri"
    }
}

