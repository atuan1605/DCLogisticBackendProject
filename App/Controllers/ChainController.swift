import Vapor
import Foundation
import Fluent


struct ChainController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
//        let groupedRoutes = routes.grouped("chains")
//        groupedRoutes.group(ScopeCheckMiddleware(requiredScope: .updateTrackingItems)) {
//            $0.get(":chainID","updateCustomerCode", use: getTrackingItemsInChainHandler)
//        }
    }

//    private func getTrackingItemsInChainHandler(req: Request) async throws -> [TrackingItemOutput] {
//        guard let chainID = req.parameters.get("chainID")?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//        else {
//            throw AppError.invalidInput
//        }
//        let input = try req.content.decode(UpdateCustomerCodeInChainInput.self)
//        let trackingItems = try await TrackingItem.query(on: req.db)
//            .with(\.$customer)
//            .filter(\.$chain == chainID)
//            .all()
//        try await req.db.transaction{ db in
//            try await trackingItems.asyncForEach({ trackingItem in
//                if let customerID = input.customerID, customerID != trackingItem.customer?.id {
//                    guard let customer = try await Customer.query(on: db)
//                        .filter(\.$id == customerID)
//                        .first()
//                    else {
//                        throw AppError.customerNotFound
//                    }
//                    trackingItem.customer?.id  = customerID
//                    try req.appendUserAction(.assignTrackingItemCustomerCode(trackingItemID: trackingItem.requireID(), customerID: customerID, customerCode: customer.customerCode))
//                } else if let customerCode = input.customerCode {
//                     let customers = try await Customer.query(on: req.db)
//                     .field(\.$id)
//                     .field(\.$customerCode)
//                     .withDeleted()
//                     .all().map {
//                         $0.customerCode = $0.customerCode.replacingOccurrences(of: " ", with: "").lowercased()
//                         return $0
//                     }
//                     if let customer = customers.first(where: { $0.customerCode == customerCode.replacingOccurrences(of: " ", with: "").lowercased() }) {
//                        if try customer.requireID() != trackingItem.customer?.id  {
//                            trackingItem.customer?.id  = try customer.requireID()
//                            try req.appendUserAction(.assignTrackingItemCustomerCode(trackingItemID: trackingItem.requireID(), customerID: customer.requireID(), customerCode: customer.customerCode))
//                        }
//                    } else {
//                        throw AppError.customerCodeNotFound
//                    }
//                }
//                if trackingItem.hasChanges {
//                    try await trackingItem.save(on: db)
//                }
//            })
//        }
//        return trackingItems.map {
//            $0.output()
//        }
//    }
}
