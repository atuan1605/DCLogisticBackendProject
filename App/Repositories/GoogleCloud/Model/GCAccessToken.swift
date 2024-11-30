//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation

struct GCAccessToken: Codable {
    let accessToken: String
    let expiresIn: Int
    let scope: String?
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case scope
        case tokenType = "token_type"
    }
}
