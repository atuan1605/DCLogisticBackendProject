//import Vapor
//import Foundation
//import Fluent
//
//struct DCClientResponseController: RouteCollection {
//    func boot(routes: RoutesBuilder) throws {
//        let groupedRoutes = routes.grouped("dcClients")
//        groupedRoutes.post("buyers", use: createBuyersHandler)
//        groupedRoutes.post("buyerTrackingItems", use: createBuyerTrackingItemHandler)
//    }
//    
//    private func createBuyersHandler(req: Request) async throws -> HTTPResponseStatus {
//        let client = req.application.client
//        let dcClient = DefaultDCClientRepository(
//            baseURL: Environment.process.DCClient_BASE_URL ?? "",
//            client: client
//        )
//        let buyers = try await dcClient.getBuyers()
//        
//        try await buyers.asyncForEach { buyer in
//            let newBuyer = Buyer(
//                id: buyer.id,
//                username: buyer.username,
//                passwordHash: buyer.passwordHash,
//                email: buyer.email,
//                phoneNumber: buyer.phoneNumber,
//                verifiedAt: buyer.verifiedAt,
//                createdAt: buyer.createdAt,
//                updatedAt: buyer.updatedAt,
//                deletedAt: buyer.deletedAt,
//                agentID: "DC"
//            )
//            try await newBuyer.save(on: req.db)
//        }
//        return .ok
//    }
//    
//    private func createBuyerTrackingItemHandler(req: Request) async throws -> HTTPResponseStatus {
//        let client = req.application.client
//        let dcClient = DefaultDCClientRepository(
//            baseURL: Environment.process.DCClient_BASE_URL ?? "",
//            client: client
//        )
//        let buyerTrackingItems = try await dcClient.getBuyerTrackingItems()
//        
//        try await buyerTrackingItems.asyncForEach { buyerTrackingItem in
//            let newBuyerTrackingItem = BuyerTrackingItem(note: buyerTrackingItem.note, packingRequest: buyerTrackingItem.packingRequest, buyerID: buyerTrackingItem.buyer.id, trackingNumber: buyerTrackingItem.trackingNumber, quantity: 1)
//            try await newBuyerTrackingItem.save(on: req.db)
//        }
//        return .ok
//    }
//}
