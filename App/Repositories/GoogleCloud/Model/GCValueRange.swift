//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import Vapor

struct GCValueRange: Content {
    var range: String
    var majorDimension: String = "ROWS"
    var values: [[String]]
}

