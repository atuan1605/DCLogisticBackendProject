import Foundation
import Vapor
import CodableCSV

struct TestController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let grouped = routes.grouped("tests")
        grouped.get("testAddingValueIntoSpreadsheet", use: testAddingValueIntoSpreadsheetHandler)
        grouped.get("createDefaultAgents", use: createDefaultAgents)
        grouped.get("createDefaultWarehouses", use: createDefaultWarehousesHandler)
        grouped.get("checkScope", use: checkScopeHandler)
        grouped.on(.PUT, "customerEmail", body: .collect(maxSize: "80mb"), use: updateCustomerEmailsHandler)
    }
    
    private func updateCustomerEmailsHandler(request: Request) async throws -> HTTPResponseStatus {
        guard let buffer = request.body.data else {
            throw AppError.invalidInput
        }
        let data = Data(buffer: buffer)
        let reader = try CSVReader(input: data) {
            $0.headerStrategy = .none
            $0.presample = false
            $0.escapingStrategy = .doubleQuote
            $0.delimiters.row = "\r\n"
            $0.encoding = .utf8
        }
        
        let customers = try await Customer.query(on: request.db)
            .all()
        var updatedCustomers: [Customer] = []
        let grouped = try customers.grouped { customer in
            customer.customerCode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var count = 0
        while let row = try reader.readRow() {
            count += 1
            if count <= 2 {
                continue
            } else {
                if let email = row.get(at: 3), let customerCode = row.get(at: 9)?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty && email.validEmail() && !customerCode.isEmpty {
                    if let customer = grouped[customerCode]?.first {
                        customer.email = email
                        updatedCustomers.append(customer)
                    }
                }
            }
        }

//        try await request.db.transaction { transaction in
//            try await updatedCustomers.asyncForEach { customer in
//                try await customer.save(on: transaction)
//            }
//        }
        return .ok
    }

    private func checkScopeHandler(request: Request) async throws -> Int {
        let scopes: User.Scope = [.usAppAccess, .vnAppAccess]

        return scopes.rawValue
    }

    private func createDefaultWarehousesHandler(request: Request) async throws -> HTTPResponseStatus {
        let defaultWarehouses: [Warehouse] = [
            .init(name: "2127"),
            .init(name: "402"),
            .init(name: "620")
        ]
        
        try await request.db.transaction { db in
            try await defaultWarehouses.create(on: db)
            
            let allUsers = try await User.query(on: db)
                .all()
            
            try await defaultWarehouses.enumerated().asyncForEach { index, warehouse in
                try await allUsers.asyncForEach { user in
                    try await user.$warehouses.attach(warehouse, on: db) {
                        $0.index = index
                    }
                }
            }
        }

        return .ok
    }

    private func createDefaultAgents(request: Request) async throws -> HTTPResponseStatus{
        let defaultAgents: [String] = ["DC", "HNC", "MD", "KN"]
        let defaultProducts: [String] = ["iPad", "Laptop", "Airpod"]

        let agents = defaultAgents.map {
            return Agent(id: $0, name: $0, popularProducts: defaultProducts)
        }

        try await request.db.transaction { db in
            try await agents.create(on: db)
            
            let allUser = try await User.query(on: db)
                .all()
            
            try await allUser.asyncForEach { user in
                try await user.$agents.attach(agents, on: db)
            }
        }

        return .ok
    }

    private func testAddingValueIntoSpreadsheetHandler(request: Request) async throws -> HTTPResponseStatus {
        try await request.google.addValueToSpreadSheet(
            sheetID: request.application.googleCloudSpreadSheet,
            sheetRange: "SomeRangeNotThere",
            values: ["a", "b"]
        )
        return .ok
    }
}
