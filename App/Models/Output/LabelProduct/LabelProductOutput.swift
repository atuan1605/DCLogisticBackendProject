import Vapor
import Foundation

struct LabelProductOutput: Content {
    var id: LabelProduct.IDValue?
    var name: String
    var code: String
    var updatedAt: Date?
}

extension LabelProduct {
    func output() -> LabelProductOutput {
        return .init(
            id: self.id,
            name: self.name,
            code: self.code,
            updatedAt: self.updatedAt
        )
    }
}
