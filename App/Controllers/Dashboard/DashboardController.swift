import Foundation
import Vapor
import Fluent
import CSV

struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("dashboards")
        
//        let protected = groupedRoutes.grouped(
//            UserJWTAuthenticator(),
//            User.guardMiddleware()
//        )
//        protected.get("customerReport", use: getCustomerReportHandler)
//        protected.get("customerReport", "csv", use: getCustomerReportCSVHandler)
    }
    
//    private func getCustomerReportHandler(req: Request) async throws -> CustomerReportDashbroadOutput {
//        let input = try req.query.decode(GetCustomerReportInput.self)
//
//        let query = TrackingItem.query(on: req.db)
//            .with(\.$customer)
//            .filter(\.$deliveredAt != nil)
//        if let customerIDs = input.customerIDs {
//            query.filter(\.$customer.$id ~~ customerIDs)
//        }
//        if let startDate = input.startDate {
//            query.filter(.sql(raw: "\(TrackingItem.schema).delivered_at::DATE"),
//                         .greaterThanOrEqual, .bind(startDate))
//        }
//        if let endDate = input.endDate {
//            query.filter(.sql(raw: "\(TrackingItem.schema).delivered_at::DATE"),
//                         .lessThanOrEqual, .bind(endDate))
//        }
//
//        let trackingItems = try await query.all()
//
//        return try await CustomerReportDashbroadOutput(items: trackingItems, on: req.db)
//
//    }
//    private func getCustomerReportCSVHandler(req: Request) async throws -> ClientResponse {
//        let output = try await self.getCustomerReportHandler(req: req)
//
//        let items = output.clients.values.flatMap { client in
//            client.compactMap { item in
//                item.products.flatMap { product in
//                    product.map {
//                        return CSVRow(
//                            date: item.deliveredAt ?? "N/A",
//                            agentCode: item.agentCode ?? "N/A",
//                            trackingNumber: item.trackingNumber ?? "N/A",
//                            productName: $0.name ?? "N/A",
//                            quantity: $0.quantity ?? 0,
//                            customerCode: item.customerCode ?? "N/A")
//                    }
//                }
//            }
//        }.flatMap { $0 }
//
//        let document = try CSVEncoder().sync.encode(items)
//        var headers = HTTPHeaders()
//        headers.add(name: .contentType, value: "text/csv")
//        headers.add(name: .contentDisposition, value: "attachment; filename=customer_report.csv")
//        let response = ClientResponse(status: .ok,
//                                      headers: headers,
//                                      body: ByteBuffer(data: document))
//        return response
//    }
}
