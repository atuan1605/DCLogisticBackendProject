import Foundation
import Vapor

struct BoxCustomItemOutput: Content {
    var id: Box.IDValue?
    var details: String
    var reference: String
    var createdAt: Date?
    var updatedAt: Date?
}

extension BoxCustomItem {
    func output() -> BoxCustomItemOutput {
        .init(
            id: self.id,
            details: self.details,
            reference: self.reference,
            createdAt: self.createdAt,
            updatedAt: self.updatedAt
        )
    }
}
