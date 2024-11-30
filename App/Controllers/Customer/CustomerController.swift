import Vapor
import Fluent
import Foundation
import SQLKit

struct CustomerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )
            
        let scopeRoute = protected.grouped(ScopeCheckMiddleware(requiredScope: [.customers]))
            .grouped("customers")
        
        scopeRoute.get("total", use: getTotalCustomersAndTrackingItemsHandler)
        scopeRoute.get("totalByAgent", use: getTotalCustomerAndTrackingByAgentHandler)
        scopeRoute.post(use: createCustomerHandler)
        scopeRoute.get("list", use: getCustomersHandler)
        scopeRoute.get("suggest", use: getCustomersSuggestByCodeHandler)
        scopeRoute.get("selections", use: getCustomerSelectionsHandler)
        scopeRoute.get("trackingItems", use: getTrackingItemsByCustomerHandler)
        
        try self.registerCSVImporterRoutes(routes: scopeRoute)
        
        let customerRoutes = scopeRoute
            .grouped(Customer.parameterPath)
            .grouped(CustomerIdentifyingMiddleware())
//        customerRoutes.get("deliveries", use: getDeliveriesHandler)
        
        customerRoutes.get(use: getCustomerDetailHandler)
        
        let shipmentRoutes = customerRoutes
            .grouped("deliveries")
            .grouped(Delivery.parameterPath)
            .grouped(DeliveryIdentifyingMiddleware())
        shipmentRoutes.get(use: getCustomerDeliveryDetailHandler)
        
        customerRoutes.group(ScopeCheckMiddleware(requiredScope: .updateCustomers)) {
            let groupedRoutes = $0.grouped("prices")
            groupedRoutes.post(use: createCustomerPriceHandler)
            groupedRoutes.get("productNameSuggestions", use: getProductNameSuggestionsHandler)
            $0.put(use: updateCustomerHander)
            $0.delete(use: deleteCustomerHandler)
            let priceRoute = groupedRoutes
                .grouped(CustomerPrice.parameterPath)
                .grouped(CustomerPriceIdentifyingMiddleware())
            priceRoute.patch(use: updateCustomerPriceHandler)
            priceRoute.delete(use: deleteCustomerPriceHandler)
            
        }
    }
    
    private func getCustomerSelectionsHandler(request: Request) async throws -> [CustomerOutput] {
        let input = try request.query.decode(CustomerSelectionsInput.self)
        let customerIDs = input.customerIDs
        let customers = try await Customer.query(on: request.db)
            .filter(\.$id ~~ customerIDs)
            .all()
        return customers.map { $0.output() }
    }
    
    private func getCustomerDetailHandler(req: Request) async throws -> CustomterInfoOutput {
        let customer = try req.requireCustomer()
        let customerID = try customer.requireID()
        let trackingItems = try await req.trackingItems.get(by: customerID, queryModifier: { builder in
            builder.with(\.$packBox)
        })
        let ordersCount = trackingItems.count
        let receiptsCount = trackingItems.filter { $0.deliveredAt != nil }.count
        let vnCount = trackingItems.filter { $0.status.power >= 6 }.count
        let usCount = trackingItems.filter { $0.status.power < 6 }.count
        let weight = try await PackBox.query(on: req.db)
            .filter(\.$customerCode == customer.customerCode).all().compactMap(\.weight).reduce(0, +)
        customer.$trackingItems.value = trackingItems
        try await customer.$prices.load(on: req.db)
        try await customer.$agent.load(on: req.db)
        return CustomterInfoOutput(
            ordersCount: ordersCount,
            receiptsCount: receiptsCount,
            vnCount: vnCount,
            usCount: usCount,
            weight: weight,
            info: customer.output())
    }
    
    private func getTotalCustomersAndTrackingItemsHandler(req: Request) async throws -> TotalCustomersAndTrackingItemsOutput {
        let customers = try await Customer.query(on: req.db).all()
        let trackingItems = try await TrackingItem.query(on: req.db)
            .filter(\.$deliveredAt != nil)
            .all()
        return TotalCustomersAndTrackingItemsOutput(items: trackingItems, customers: customers)
    }
    
    private func createCustomerHandler(req: Request) async throws -> CustomerForListOutput{
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .updateCustomers) else {
            throw AppError.invalidScope
        }
        try CreateCustomerInput.validate(content: req)
        var input = try req.content.decode(CreateCustomerInput.self)
        if let safePhoneNumber = input.phoneNumber, !safePhoneNumber.isEmpty {
            guard let phoneNumber = safePhoneNumber.validPhoneNumber() else {
                throw AppError.invalidPhoneNumber
            }
            input.phoneNumber = phoneNumber
        }
        if (try await Customer.query(on: req.db)
            .filter(\.$customerCode == input.customerCode)
            .first()) != nil {
            throw AppError.customerCodeAlreadyExists
        }
         
        let newCustomer = input.toCustomer()
        try await newCustomer.save(on: req.db)
        try req.appendUserAction(.assignCreateCustomer(customerID: newCustomer.requireID()))
        
        return newCustomer.outputForList()
    }
    
//    private func getDeliveriesHandler(req: Request) async throws -> [CustomerDeliveryOuput] {
//        let customer = try req.requireCustomer()
//        let customerCode = customer.customerCode
//        let customerId = try customer.requireID()
//
//        let deliveries = try await Delivery.query(on: req.db)
//            .join(PackBox.self, on: \PackBox.$delivery.$id == \Delivery.$id)
//            .filter(PackBox.self, \.$customerCode == customerCode)
//            .unique()
//            .fields(for: Delivery.self)
//            .all()
//        return try await deliveries.asyncMap({
//            try await $0.output(customerId: customerId, on: req.db)
//        }).sorted(by: { lhs,rhs in
//            return lhs.commitedAt ?? .distantPast > rhs.commitedAt ?? .distantPast
//        })
//    }
    
    private func getCustomersSuggestByCodeHandler(req: Request) async throws -> [CustomerCodeOutput] {
        let authUser = try req.requireAuthUser()
        let agentIDs = try await authUser.$agents.query(on: req.db).all(\.$id)

        let input = try req.query.decode(GetCustomersByCodeQueryInput.self)
        let query = Customer.query(on: req.db)
            .field(\.$id)
            .field(\.$customerCode)
            .filter(\.$agent.$id ~~ agentIDs)
            .filter(.sql(raw: "\(Customer.schema).customer_code"),
                         .custom("ILIKE"),
                         .bind("%\(input.customerCode)%"))
            .sort(\.$customerCode, .ascending)
        let customers = try await query
            .limit(10)
            .all()
        return customers.map { $0.outputByCode() }
    }

    private func getCustomersHandler(req: Request) async throws -> Page<CustomerForListOutput> {
        let input = try req.query.decode(GetCustomersQueryInput.self)
        var query = Customer.query(on: req.db)
            .filter(\.$agent.$id == input.agentID)
            
        if let searchInput = input.searchString {
            query = query.group(.or) { orBuilder in
                orBuilder.filter(.sql(raw: "\(Customer.schema).customer_code"), .custom("ILIKE"), .bind("%\(searchInput)%"))
                orBuilder.filter(.sql(raw: "\(Customer.schema).email"), .custom("ILIKE"), .bind("%\(searchInput)%"))
            }
        }
        let page = try await query
            .with(\.$trackingItems) {
                $0.with(\.$packBox)
            }
            .sort(\.$createdAt, .descending)
            .paginate(for: req)
        return .init(items: page.items.map { $0.outputForList() }, metadata: page.metadata)
    }
    
    private func getTotalCustomerAndTrackingByAgentHandler(req: Request) async throws -> TotalCustomerAndTrackingItemByAgentOutput {
        let input = try req.query.decode(GetCustomersQueryInput.self)
        let customers = try await Customer.query(on: req.db)
            .filter(\.$agent.$id == input.agentID)
            .with(\.$trackingItems)
            .sort(\.$createdAt, .descending)
            .all()
        return .init(customers: customers)
    }
    
    private func updateCustomerHander(req: Request) async throws -> CustomerOutput {
        let user = try req.requireAuthUser()
        guard user.hasRequiredScope(for: .updateCustomers) else {
            throw AppError.invalidScope
        }
        let customer = try req.requireCustomer()
        let input = try req.content.decode(UpdateCustomerInput.self)
        let customerId = try customer.requireID()
        if let customerName = input.customerName, customerName != customer.customerName {
            customer.customerName = customerName
            req.appendUserAction(.assignCustomerName(customerId: customerId, customerName: customerName))
        }
        if let customerCode = input.customerCode, customerCode != customer.customerCode {
            customer.customerCode = customerCode
            req.appendUserAction(.assignCustomerCode(customerId: customerId, customerCode: customerCode))
        }
        if let agentID = input.agentID, agentID != customer.$agent.id {
            customer.$agent.id = agentID
            req.appendUserAction(.assignCustomerAgentId(customerId: customerId, agentID: agentID))
        }
        if let phoneNumber = input.phoneNumber, phoneNumber != customer.phoneNumber {
            guard let number = phoneNumber.validPhoneNumber() else {
                throw AppError.invalidPhoneNumber
            }
            customer.phoneNumber = number
            req.appendUserAction(.assignCustomerPhoneNumber(customerId: customerId, phoneNumber: phoneNumber))
        }
        if let email = input.email, email != customer.email {
            customer.email = email
            req.appendUserAction(.assignCustomerEmail(customerId: customerId, email: email))
        }
        if let address = input.address, address != customer.address {
            customer.address = address
            req.appendUserAction(.assignCustomerAddress(customerId: customerId, address: address))
        }
        if let note = input.note, note != customer.note {
            customer.note = note
            req.appendUserAction(.assignCustomerNote(customerId: customerId, note: note))
        }
        if let facebook = input.facebook, facebook != customer.socialLinks.facebook {
            customer.socialLinks.facebook = facebook
            req.appendUserAction(.assignCustomerFacebook(customerId: customerId, facebook: facebook))
        }
        if let zalo = input.zalo, zalo != customer.socialLinks.zalo {
            customer.socialLinks.zalo = zalo
            req.appendUserAction(.assignCustomerZalo(customerId: customerId, zalo: zalo))
        }
        if let telegram = input.telegram, telegram != customer.socialLinks.telegram {
            customer.socialLinks.telegram = telegram
            req.appendUserAction(.assignCustomerTelegram(customerId: customerId, telegram: telegram))
        }
        if let priceNote = input.priceNote, priceNote != customer.priceNote {
            customer.priceNote = priceNote
            req.appendUserAction(.assignCustomerPriceNote(customerId: customerId, priceNote: priceNote))
        }
        if let isProvince = input.isProvince, isProvince != customer.isProvince {
            customer.isProvince = isProvince
            req.appendUserAction(.assignCustomerIsProvince(customerId: customerId, isProvince: isProvince))
        }
        if let googleLink = input.googleLink, googleLink != customer.googleLink {
            customer.googleLink = googleLink
            req.appendUserAction(.assignCustomerGoogleLink(customerId: customerId, googleLink: googleLink))
        }
        if customer.hasChanges {
            try await customer.save(on: req.db)
        }
        let _ = try await customer.$trackingItems.query(on: req.db)
            .with(\.$packBox)
            .all()
        try await customer.$prices.load(on: req.db)
        return customer.output()
    }
    
    func getCustomerDeliveryDetailHandler(req: Request) async throws -> CustomerDeliveryDetailOutput {
        let customer = try req.requireCustomer()
        let delivery = try req.requireDelivery()
        
        let customerID = try customer.requireID()
        let deliveryID = try delivery.requireID()
        
        let trackingItems = try await req.trackingItems.get(by: customerID) { builder in
            builder
                .with(\.$products)
                .with(\.$packBox) {
                    $0.with(\.$trackingItems)
                    $0.with(\.$delivery)
                }
        }.filter { $0.packBox?.delivery?.id == deliveryID }
        
        let deliveredTrackingItems = trackingItems.filter { $0.deliveredAt != nil }
        let trackingItemsCount = deliveredTrackingItems.count //Số tracking đã giao
        let totalWeight = try deliveredTrackingItems
            .compactMap { $0.packBox }.removingDuplicates { $0.id }
            .compactMap { $0.weight }.reduce(0, +)
        let productsCount = deliveredTrackingItems.compactMap { $0.products.compactMap { $0.quantity }.reduce(0,+) }.reduce(0, +)
        let commitedAt = delivery.commitedAt
        let products = deliveredTrackingItems.compactMap { $0.products.map { $0.toOutput() } }.flatMap { $0 }
        let packBoxes = try trackingItems.compactMap { $0.packBox }.removingDuplicates { $0.id } .map { $0.output(customerID: customerID)}
        return CustomerDeliveryDetailOutput(
            trackingItemsCount: trackingItemsCount,
            totalWeight: totalWeight,
            productsCount: productsCount,
            commitedAt: commitedAt,
            products: products,
            packBoxes: packBoxes)
    }
    
    private func createCustomerPriceHandler(req: Request) async throws -> CustomerPriceOutput {
        let customer = try req.requireCustomer()
        let customerID = try customer.requireID()
        
        let newCustomerPrice = CustomerPrice(
            customerID: customerID,
            unitPrice: 0,
            productName: ""
        )
        
        try await newCustomerPrice.save(on: req.db)
        
        let allCustomerPriceIDs = try await customer.$prices.query(on: req.db).all(\.$id)
        req.appendUserAction(.assignCustomerPrices(customerID: customerID, customerPriceIDs: allCustomerPriceIDs))
        return newCustomerPrice.toOutput()
    }
    
    private func updateCustomerPriceHandler(req: Request) async throws -> CustomerPriceOutput {
        try UpdateCustomerPriceInput.validate(content: req)
        let input = try req.content.decode(UpdateCustomerPriceInput.self)
        let customerPrice = try req.requireCustomerPrice()
        let customerPriceID = try customerPrice.requireID()
        let customer = try req.requireCustomer()
        let customerID = try customer.requireID()
        if let productName = input.productName, productName != customerPrice.productName {
            customerPrice.productName = productName
            req.appendUserAction(.assignProductName(customerID: customerID, customerPriceID: customerPriceID, productName: productName))
        }
        if let unitPrice = input.unitPrice, unitPrice != customerPrice.unitPrice {
            customerPrice.unitPrice = unitPrice
            req.appendUserAction(.assignUnitPrice(customerID: customerID, customerPriceID: customerPriceID, unitPrice: unitPrice))
        }
        
        if customerPrice.hasChanges {
            try await customerPrice.save(on: req.db)
        }
        
        return customerPrice.toOutput()
    }
    
    private func deleteCustomerPriceHandler(req: Request) async throws -> HTTPResponseStatus {
        let customerPrice = try req.requireCustomerPrice()
        try await customerPrice.delete(on: req.db)
        let customer = try req.requireCustomer()
        let customerID = try customer.requireID()
        let allcustomerPriceIDs = try await customer.$prices.query(on: req.db)
            .all(\.$id)
        req.appendUserAction(.assignCustomerPrices(customerID: customerID, customerPriceIDs: allcustomerPriceIDs))
        return .ok
    }
    
    private func getProductNameSuggestionsHandler(request: Request) async throws -> [String] {
        let customer = try request.requireCustomer()
        let agent = try await customer.$agent.get(on: request.db)
        let agentID = try agent.requireID()
        if let sqlDB = request.db as? SQLDatabase
        {
            struct QueryRow: Content {
                var keyword: String
                var count: Int
            }
            let topProductName = try await sqlDB.raw("""
            select cp.product_name as \(ident: "keyword"), count(distinct cp.id) as \(ident: "count")
            from customer_prices cp
            left join customers c on c.id = cp.customer_id
            where c.agent_id = \(bind: agentID) and cp.product_name <> \(bind: "")
            group by cp.product_name
            order by count(distinct cp.id) desc
            limit 5;
            """).all(decoding: QueryRow.self)
            
            var productNames = ["iPad", "Laptop", "Airpod"]
            let topProducts = topProductName.map(\.keyword)
            productNames.insert(contentsOf: topProducts, at: 0)
            productNames.removeDuplicates()
            productNames = productNames.filter {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            
            return Array(productNames.prefix(10))
        }
        return ["iPad", "Laptop", "Airpod"]
    }
    
    private func deleteCustomerHandler(request: Request) async throws -> HTTPResponseStatus {
        let customer = try request.requireCustomer()
        let trackingItemCount = try await customer.$trackingItems.get(on: request.db).count
        if trackingItemCount == 0 {
            try await customer.delete(on: request.db)
        }
        else {
            throw AppWithOutputError.customerTrackingItemsAlreadyExist(trackingItemCount)
        }
        return .ok
    }
    
    private func getTrackingItemsByCustomerHandler(req: Request) async throws -> Page<TrackingItemWithAllProduct> {
        let input = try req.query.decode(GetTrackingItemsByCustomerQueryInput.self)
        let query = TrackingItem.query(on: req.db)
            .with(\.$products)
            .with(\.$customers)
            .sort(\.$receivedAtUSAt, .descending)
            .filter(\.$agentCode == input.agentID)
        if let customerID = input.customerID {
            query.join(TrackingItemCustomer.self, on: \TrackingItemCustomer.$trackingItem.$id == \TrackingItem.$id)
                .join(Customer.self, on: \Customer.$id == \TrackingItemCustomer.$customer.$id)
                .filter(Customer.self, \.$id == customerID)
        }
        let page = try await query.fields(for: TrackingItem.self).unique().paginate(for: req)
        
        return .init(
            items: page.items.map{ $0.outputWithProduct()}, metadata: page.metadata
        )
    }
        
}

extension QueryBuilder where Model: Shipment {
    @discardableResult func filter(shipments: [String]) -> Self {
        guard !shipments.isEmpty else {
            return self
        }
        
        let regexSuffixGroup = shipments.joined(separator: "|")
        let fullRegex = "^.*(\(regexSuffixGroup))$"
        
        return self.filter(.sql(raw: "\(Shipment.schema).name"),.custom("~*"), .bind(fullRegex))
    }
}
