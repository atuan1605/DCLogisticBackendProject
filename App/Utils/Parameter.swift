//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import Vapor
import Fluent

protocol Parameter {
    static var parameter: String { get }
    static var parameterPath: PathComponent { get }
}

extension Parameter {
    static var parameterPath: PathComponent {
        return .parameter(self.parameter)
    }
}

extension Parameter where Self: Model { // TrackingItem -> tracking_item -> tracking_item_id
    static var parameter: String {
        let className = String(describing: self).snakeCased()
        return "\(className)_id"
    }
}
