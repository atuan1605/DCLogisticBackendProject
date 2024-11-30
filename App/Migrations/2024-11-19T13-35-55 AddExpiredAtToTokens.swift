import Foundation
import Fluent
import SQLKit

struct AddExpiredAtToTokens: AsyncMigration {
    func prepare(on database: Database) async throws {
        let defaultExpiredAt = Date().addingTimeInterval(.oneDay*10)
        let defaultCreatedAt = Date()
        try await database.schema(Token.schema)
            .field("expired_at", .datetime, .required, .sql(raw: "DEFAULT '\(defaultExpiredAt.toISOString())'::date"))
            .field("created_at", .datetime, .sql(raw: "DEFAULT '\(defaultCreatedAt.toISOString())'::date"))
            .field("updated_at", .datetime, .sql(raw: "DEFAULT '\(defaultCreatedAt.toISOString())'::date"))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Token.schema)
            .deleteField("expired_at")
            .deleteField("created_at")
            .deleteField("updated_at")
            .update()
    }
}



