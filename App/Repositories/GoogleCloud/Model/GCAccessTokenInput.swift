//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import JWT
import Vapor

struct GCJWTPayload: Codable, JWTPayload {
    var iss: String
    var scope: String
    var aud: String
    var exp: TimeInterval
    var iat: TimeInterval
    
    func verify(using signer: JWTKit.JWTSigner) throws { }
    
    init(iss: String, scope: String) {
        self.iss = iss
        self.scope = scope
        self.aud = "https://oauth2.googleapis.com/token"
        let now = Date()
        self.iat = now.timeIntervalSince1970
        self.exp = now.addingTimeInterval(60*60).timeIntervalSince1970
    }
}

struct GCAccessTokenInput: Content {
    let grantType: String
    let assertion: String

    init(assertion: String) {
        self.grantType = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        self.assertion = assertion
    }
    
    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case assertion
    }
}

