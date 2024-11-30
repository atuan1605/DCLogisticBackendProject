import Vapor
import Foundation

struct CreateWarehouseInput: Content {
    var name: String
    var address: String?
}

extension CreateWarehouseInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("address", as: String.self)
    }
}

extension CreateWarehouseInput {
    func toWarehouse() -> Warehouse {
        return .init(name: self.name, address: self.address)
    }
}
