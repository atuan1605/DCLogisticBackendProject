//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Fluent
import Vapor
import FluentKit
import FluentPostgresDriver

func databases(_ app: Application) throws {
    if app.environment == .testing {
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_TEST_HOST") ?? "localhost",
            port: Environment.get("DATABASE_TEST_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_TEST_USERNAME") ?? "dclogistics",
            password: Environment.get("DATABASE_TEST_PASSWORD") ?? "ABC1234",
            database: Environment.get("DATABASE_TEST_NAME") ?? "dclogistics_test"
        ), as: .psql)
    } else if let databaseURL = Environment.process.DATABASE_URL {
        var tlsConfig: TLSConfiguration = .makeClientConfiguration()
        tlsConfig.certificateVerification = .none
        let nioSSLContext = try NIOSSLContext(configuration: tlsConfig)
        var config = try SQLPostgresConfiguration(url: databaseURL)
        config.coreConfiguration.tls = .require(nioSSLContext)

        try app.databases.use(
            .postgres(
                configuration: config,
                maxConnectionsPerEventLoop: 2,
                connectionPoolTimeout: .minutes(2),
                sqlLogLevel: .error
            ), as: .psql)
    } else {
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "dclogistics",
            password: Environment.get("DATABASE_PASSWORD") ?? "ABC1234",
            database: Environment.get("DATABASE_NAME") ?? "dclogistics"
        ), as: .psql)
    }
}

