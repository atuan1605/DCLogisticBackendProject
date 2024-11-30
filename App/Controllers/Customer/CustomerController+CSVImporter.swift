import Foundation
import Vapor
import Fluent
import CodableCSV

extension CustomerController {
    
    func registerCSVImporterRoutes(routes: RoutesBuilder) throws {
        let grouped = routes.grouped("importData")
        grouped.on(.POST, ":agentID", body: .collect(maxSize: "80mb"), use: importCustomersHandler)
    }

    private func importCustomersHandler(request: Request) async throws -> Int {
        guard let buffer = request.body.data,
            let agentID = request.parameters.get("agentID", as: String.self),
        !agentID.isEmpty else {
            throw AppError.invalidInput
        }
        let data = Data(buffer: buffer)
        let reader = try CSVReader(input: data) {
            $0.headerStrategy = .none
            $0.presample = false
            $0.escapingStrategy = .doubleQuote
            $0.delimiters.row = "\r\n"
        }
        let dbCustomerCodes = try await Customer.query(on: request.db)
            .field(\.$customerCode).unique().all()
            .map { $0.customerCode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        var insertData: [CreateCustomerInput] = []
        var count = 0
        while let row = try reader.readRow() {
            count +=  1
            if count <= 2 {
                continue
            }
            else {
                if let code = row.get(at: 4), let customerCode = row.get(at: 9), !code.isEmpty && !customerCode.isEmpty && !dbCustomerCodes.contains(customerCode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) {
                    let item = CreateCustomerInput(agentID: agentID, res: row)
                    insertData.append(item)
                }
            }
        }
        
        let customers = insertData.compactMap{ $0.toCustomer() }
        try await customers.create(on: request.db)
        try customers.forEach { customer in
            try request.appendUserAction(.assignCreateCustomer(customerID: customer.requireID()))
        }
        return customers.count
    }
}
