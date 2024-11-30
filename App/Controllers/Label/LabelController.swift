import Foundation
import Vapor
import Fluent
import SQLKit

struct LabelController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("labels")
        
        let authenticated = groupedRoutes
            .grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())
        
        authenticated.post(use: createLabelsHandler)
        authenticated.get(use: getUnscanLabelsHandler)
        authenticated.get("scanned", use: getScannedLabelsHandler)
        
        let labelRoutes = authenticated
            .grouped(Label.parameterPath)
            .grouped(LabelIdentifyingMiddleWare())
        
        labelRoutes.post("subLabels", use: createSubLabelsHandler)
        labelRoutes.delete(use: deletedLabelHandler)
        labelRoutes.put("printed", use: printLabelHandler)
//        labelRoutes.put(use: updateLabelHandler)
    }
    
    private func printLabelHandler(req: Request) async throws -> LabelOutput {
        guard let labelID: Label.IDValue = req.parameters.get(Label.parameter) else {
            throw AppError.invalidInput
        }
        
        let printedLabel = try await req.db.transaction { transaction in
            guard var targetLabel = try await Label.query(on: transaction)
                .filter(\.$id == labelID)
                .with(\.$warehouse)
                .with(\.$customer)
                .with(\.$labelProduct, withDeleted: true)
                .first()
            else {
                throw AppError.labelNotFound
            }
            targetLabel.printedAt = Date()
            try await targetLabel.save(on: transaction)
            if targetLabel.$superLabel.id == nil {
                try await Label.query(on: transaction)
                    .filter(\.$superLabel.$id == labelID)
                    .set(\.$printedAt, to: Date())
                    .update()
                try await targetLabel.$subLabels.load(on: transaction)
            } else {
                guard let superLabel = try await targetLabel.$superLabel.query(on: transaction)
                    .with(\.$subLabels)
                    .with(\.$warehouse)
                    .with(\.$customer)
                    .with(\.$labelProduct, withDeleted: true)
                    .first()
                else {
                    throw AppError.labelNotFound
                }
                if superLabel.subLabels.allSatisfy({ $0.printedAt != nil }) {
                    superLabel.printedAt = Date()
                    try await superLabel.save(on: transaction)
                }
                targetLabel = superLabel
            }
            return targetLabel
        }
        return printedLabel.output()
    }
    
    private func deletedLabelHandler(req: Request) async throws -> HTTPResponseStatus {
        let label = try req.requireLabel()
        if label.$superLabel.id == nil {
            let subLabels = try await label.$subLabels.get(on: req.db)
            try req.appendUserAction(.deleteLabels(labelIDs: subLabels.map{ try $0.requireID()}))
            try await subLabels.delete(on: req.db)
        }
        try req.appendUserAction(.deleteLabels(labelIDs: [label.requireID()]))
        try await label.delete(on: req.db)
        return .ok
    }
    
//    private func updateLabelHandler(req: Request) async throws -> [LabelOutput] {
//        let label = try req.requireLabel()
//        guard label.$superLabel.id == nil else {
//            throw AppError.subLabelCantBeUpdated
//        }
//        let subLabels = try await Label.query(on: req.db)
//            .filter(\.$superLabel.$id == label.requireID())
//            .all()
//        try await label.$labelProduct.load(on: req.db)
//        let input = try req.content.decode(UpdateLabelInput.self)
//        if let warehouseID = input.warehouseID, warehouseID != label.$warehouse.id {
//            label.$warehouse.id = warehouseID
//        }
//        if let agentID = input.agentID, agentID != label.$agent.id {
//            label.$agent.id = agentID
//        }
//        if let customerID = input.customerID, customerID != label.$customer.id {
//            label.$customer.id = customerID
//        }
//        if let reference = input.reference, reference != label.reference {
//            label.reference = reference
//        }
//        if let quantity = input.quantity, quantity != label.quantity {
//            if !subLabels.isEmpty {
//                let sublabelsQuantity = subLabels.compactMap{ $0.quantity}.reduce(0, +)
//                guard quantity >= sublabelsQuantity else {
//                    throw AppError.invalidInput
//                }
//            } else {
//                label.quantity = quantity
//            }
//        }
//        if let labelProductName = input.labelProductName, labelProductName.normalized() != label.labelProduct.name {
//            let existedProductsCount = try await
//            LabelProduct.query(on: req.db)
//                .count()
//            var targetProduct = try await LabelProduct.query(on: req.db)
//                .filter(\.$name == labelProductName.normalized())
//                .first()
//            if targetProduct == nil {
//                let newLabelProduct = LabelProduct(code: (existedProductsCount + 1).toFormattedString(), name: labelProductName.normalized())
//                try await newLabelProduct.save(on: req.db)
//                targetProduct = newLabelProduct
//            }
//            guard let targetProduct = targetProduct else {
//                throw AppError.productNotFound
//            }
//            label.$labelProduct.id = try targetProduct.requireID()
//        }
//        if label.hasChanges {
//            
//            let formattedDate = label.createdAt?.toISODate().replacingOccurrences(of: "-", with: "")
//            var trackingNumber = "\(formattedDate + warehouse.name + formattedCount + customer.customerCode + targetProduct.code)-000"
//            
//            label.trackingNumber = trackingNumber
//            try await label.save(on: req.db)
//            try await subLabels.asyncForEach { subLabel in
//                subLabel.$agent.id
//                subLabel.$warehouse.id
//                subLabel.reference
//                
//                
//            }
//        }
//    }
    
    private func getUnscanLabelsHandler(req: Request) async throws -> Page<LabelOutput> {
        
        let input = try req.query.decode(GetLabelQueryInput.self)
        let query = Label.query(on: req.db)
            .filter(\.$trackingItem.$id == nil)
            .filter(\.$superLabel.$id == nil)
            .with(\.$subLabels)
            .with(\.$warehouse)
            .with(\.$customer)
            .with(\.$labelProduct, withDeleted: true)
            
        if let warehouseID = input.warehouseID {
            query.filter(\.$warehouse.$id == warehouseID)
        }
        if let agentID = input.agentID {
            query.filter(\.$agent.$id == agentID)
        }
        let page = try await query.sort(\.$updatedAt, .descending).sort(\.$trackingNumber, .ascending).paginate(for: req)
        return .init(
            items: page.items.map { $0.output() },
            metadata: page.metadata)
    }
    
    private func getScannedLabelsHandler(req: Request) async throws -> Page<LabelOutput> {
        let input = try req.query.decode(GetLabelQueryInput.self)
        let query = Label.query(on: req.db)
            .filter(\.$trackingItem.$id != nil)
            .with(\.$warehouse)
            .with(\.$subLabels)
            .with(\.$customer)
            .with(\.$trackingItem, withDeleted: true)
            .with(\.$labelProduct, withDeleted: true)
        
        if let warehouseID = input.warehouseID {
            query.filter(\.$warehouse.$id == warehouseID)
        }
        if let agentID = input.agentID {
            query.filter(\.$agent.$id == agentID)
        }
        let page = try await query.sort(\.$updatedAt, .descending).paginate(for: req)
        return .init(
            items: page.items.map { $0.output() },
            metadata: page.metadata)
    }
    
    private func createSubLabelsHandler(req: Request) async throws -> [LabelOutput] {
        let superLabel = try req.requireLabel()
        let input = try req.content.decode(CreateMultipleSubLabelsInput.self)
        let subLabelCount = try await superLabel.$subLabels.get(on: req.db).count
        guard input.subItems.map({ $0.quantity }).reduce(0, +) <= superLabel.quantity else {
            throw AppError.invalidInput
        }
        let newSubLabels = try input.subItems.enumerated().map { index, subItemInput in
            let formattedCount = (subLabelCount + index + 1).formatNumber(minimumOf: 3)
            let formattedQuantity = subItemInput.quantity.formatNumber(minimumOf: 3)
            return Label(
                trackingNumber: "\(superLabel.trackingNumber)-\(formattedCount)-\(formattedQuantity)",
                quantity: subItemInput.quantity,
                warehouseID: superLabel.$warehouse.id,
                agentID: superLabel.$agent.id,
                customerID: superLabel.$customer.id,
                labelProductID: superLabel.$labelProduct.id,
                superLabelID: try superLabel.requireID()
            )
        }
        try await newSubLabels.create(on: req.db)
        try newSubLabels.forEach {
            try req.appendUserAction(.createLabel(labelID: $0.requireID(), superLabelID: superLabel.requireID(), trackingNumber: $0.trackingNumber))
        }
        return newSubLabels.map{ $0.output() }
    }
    
    private func createLabelsHandler(req: Request) async throws -> HTTPResponseStatus {

        var input = try req.content.decode(CreateMultipleLabelsInput.self)
        let now = Date()
        let fromDate = now.dateAtStartOf(.day)
        let toDate = now.dateAtEndOf(.day)
        let formattedDate = now.toISODate().replacingOccurrences(of: "-", with: "")
        
        let labelsCount = try await Label.query(on: req.db)
            .filter(.sql(raw: "\(Label.schema).created_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
            .filter(.sql(raw: "\(Label.schema).created_at::DATE"), .lessThanOrEqual, .bind(toDate))
            .count()
        let trackingItemsCount = try await TrackingItem.query(on: req.db)
            .filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"), .greaterThanOrEqual, .bind(fromDate))
            .filter(.sql(raw: "\(TrackingItem.schema).received_at_us_at::DATE"), .lessThanOrEqual, .bind(toDate))
            .count()
        let labelProductsCount = try await LabelProduct.query(on: req.db).count()
        
        let totalCount = labelsCount + trackingItemsCount
        
        let warehouses = try await Warehouse.query(on: req.db)
            .filter(\.$id ~~ input.items.map{ $0.warehouseID })
            .all()
        let customers = try await Customer.query(on: req.db)
            .filter(\.$id ~~ input.items.map { $0.customerID })
            .all()
        let agents = try await Agent.query(on: req.db)
            .filter(\.$id ~~ input.items.map { $0.agentID })
            .all()
        let newLabelProductsInput = input.items.filter { $0.labelProductID == nil }
        let newLabelProducts = newLabelProductsInput.enumerated().map { index, input in
            let newProduct = LabelProduct(code: ( labelProductsCount + index + 1).formatNumber(minimumOf: 3), name: input.labelProductName)
            return newProduct
        }
        try await newLabelProducts.create(on: req.db)
        try newLabelProducts.forEach {
            try req.appendUserAction(.createLabelProduct(labelProductID: $0.requireID()))
        }
        
        input.items = try input.items.enumerated().map { index, createInput in
            var temp = createInput
            if let newProduct = newLabelProducts.first(where: { $0.name == temp.labelProductName }) {
                temp.labelProductID = try newProduct.requireID()
            }
            return temp
        }
        let labelProducts = try await LabelProduct.query(on: req.db)
            .filter(\.$id ~~ input.items.compactMap{ $0.labelProductID })
            .all()
        let newLabels = try input.items.enumerated().map { index, createLabelInput in
            
            guard let warehouse = warehouses.first(where: { $0.id == createLabelInput.warehouseID}) else {
                throw AppError.warehouseNotFound
            }
            guard agents.first(where: { $0.id == createLabelInput.agentID}) != nil else {
                throw AppError.agentNotFound
            }
            guard let customer = customers.first(where: { $0.id == createLabelInput.customerID}) else {
                throw AppError.customerNotFound
            }
            guard let targetLabelProduct = labelProducts.first(where: { $0.id == createLabelInput.labelProductID}) else {
                throw AppError.labelProductNotFound
            }
            let formattedCount = (totalCount + index + 1).formatNumber(minimumOf: 3)
            let trackingNumber = ("\(formattedDate + warehouse.name + formattedCount + customer.customerCode)-\(targetLabelProduct.code)-000")
                .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let newLabel = Label(
                trackingNumber: trackingNumber,
                quantity: createLabelInput.quantity,
                reference: createLabelInput.reference,
                warehouseID: createLabelInput.warehouseID,
                agentID: createLabelInput.agentID,
                customerID: createLabelInput.customerID,
                labelProductID: try targetLabelProduct.requireID()
            )
            return newLabel
        }
        try await newLabels.create(on: req.db)
        try newLabels.forEach { newLabel in
            try req.appendUserAction(.createLabel(labelID: newLabel.requireID(), superLabelID: nil, trackingNumber: newLabel.trackingNumber))
        }
        return .ok
    }
    
}

extension Int {
    func formatNumber(minimumOf digit: Int) -> String {
        if self >= Int(pow(10.0, Double(digit))) {
            return "\(self)"
        }
        return String(format: "%0\(digit)d", self)
    }
}

extension String {
   
    func barCodeSimplify() -> String {
    let pattern = "[^\\p{Print}]"
    return self.replacingOccurrences(of: pattern, with: "", options: .regularExpression).replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
    }
}
