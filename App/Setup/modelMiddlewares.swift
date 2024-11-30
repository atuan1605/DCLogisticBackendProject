//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation
import Vapor

func modelMiddlewares(_ app: Application) throws {
    app.databases.middleware.use(ProductModelMiddleware())
    app.databases.middleware.use(TrackingItemModelMiddleware())
}

