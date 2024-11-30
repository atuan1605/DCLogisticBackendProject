import Foundation
import Vapor
import Fluent

struct WarehouseOutput: Content, Hashable {
    let id: Warehouse.IDValue?
    let name: String
    let address: String?
    let inactiveAt: Date?
    let createdAt: Date?
    let reference: String?
}

extension Warehouse {
    func output() -> WarehouseOutput {
        return .init(
            id: self.id,
            name: self.name,
            address: self.address,
            inactiveAt: self.inactiveAt,
            createdAt: self.createdAt,
            reference: self.reference
        )
    }
}
