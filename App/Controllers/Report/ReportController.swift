import Foundation
import Vapor
import Fluent
import SwiftDate

struct ReportController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("reports")
        let protected = groupedRoutes.grouped(
            UserJWTAuthenticator(),
            User.guardMiddleware()
        )
        protected.get("stockFromDeliToRepack", use: getStockFromDeliToRepackHandler)
        protected.get("stockFromRepackToBox", use: getStockFromRepackToBoxHandler)
        protected.get("stockFromDeliToReceiveAtVN", use: getStockFromDeliToReceiveAtVNHandler)
        protected.get("stockCount", use: getStockCountHandler)
		protected.get("trackingInfoFilling", use: getTrackingItemInfoFillingReportHandler)
    }

	private func getTrackingItemInfoFillingReportHandler(request: Request) async throws -> GetTrackingInfoFillingReportOutput {
		let input = try request.query.decode(GetTrackingInfoFillingReportInput.self)
		
		var toDate = input.toDate ?? Date().dateAtStartOf(.day)
		let fromDate = input.fromDate ?? toDate.addingTimeInterval(-7 * .oneDay)
		
		if fromDate > toDate {
			toDate = fromDate.addingTimeInterval(.oneDay)
		}

		let fillingActions = try await ActionLogger.query(on: request.db)
			.filter(.sql(raw: "\(ActionLogger.schema).created_at::DATE"),
							 .lessThanOrEqual, .bind(toDate))
			.filter(.sql(raw: "\(ActionLogger.schema).created_at::DATE"),
					.greaterThanOrEqual, .bind(fromDate))
			.filter(.sql(raw: "type ? 'trackingInfoFinalised'"))
			.filter(\.$user.$id != nil)
			.all()
		
		let allTrackingItemIDs = fillingActions.compactMap { action -> TrackingItem.IDValue? in
			guard case let .trackingInfoFinalised(trackingItemID) = action.type else {
				return nil
			}
			return trackingItemID
		}
		
		let agentTrackingItemIDs = try await TrackingItem.query(on: request.db)
			.filter(\.$id ~~ allTrackingItemIDs)
			.filter(\.$agentCode == input.agentCode)
			.all(\.$id)
		
		let agentFillingActions = fillingActions.filter { action in
			guard case let .trackingInfoFinalised(trackingItemID) = action.type else {
				return false
			}
			return agentTrackingItemIDs.contains(trackingItemID)
		}

		let allUsersWithAgent = try await User.query(on: request.db)
			.join(UserAgent.self, on: \UserAgent.$user
				.$id == \User.$id)
			.filter(UserAgent.self, \.$agent.$id == input.agentCode)
			.sort(\.$username)
			.all()
		
		var currentDate = fromDate
		var response: GetTrackingInfoFillingReportOutput = [:]
		
		while currentDate <= toDate {
			let dateISO = currentDate.toISODate()
			let fillingActionsInDay = agentFillingActions.filter { $0.createdAt?.toISODate() == dateISO }
			
			var fillingActionsByUser = [String: GetTrackingInfoFillingReportByUser]()
			
			for user in allUsersWithAgent {
				let userID = try user.requireID()

				fillingActionsByUser[userID.uuidString] = .init(
					id: userID,
					count: fillingActionsInDay.filter { $0.$user.id == userID}.count,
					name: user.username
				)
			}
			
			response[dateISO] = fillingActionsByUser
			currentDate = currentDate.addingTimeInterval(.oneDay)
		}

		return response
	}
    
    private func getStockFromDeliToRepackHandler(request: Request) async throws -> Page<TrackingItemOutput> {
        let input = try request.query.decode(GetStockInput.self)
        let limitedDay = 3.0
        let limitedDate = Date().addingTimeInterval(.oneDay*(-limitedDay))
        var query = TrackingItem.query(on: request.db)
            .with(\.$customers)
            .filter(\.$repackedAt == nil)
			.filter(\.$receivedAtVNAt == nil)
            .filter(\.$receivedAtUSAt <= limitedDate)
            .sort(\.$receivedAtUSAt, .ascending)
        if let agentID = input.agentID {
            query = query.filter(\.$agentCode == agentID)
        }
        let page = try await query.paginate(for: request)
        return .init(
            items: page.items.map { $0.output() },
            metadata: page.metadata)
    }
    
    private func getStockFromRepackToBoxHandler(request: Request) async throws -> Page<TrackingItemOutput> {
        let input = try request.query.decode(GetStockInput.self)
        let limitedDay = 3.0
        let limitedDate = Date().addingTimeInterval(.oneDay*(-limitedDay))
        var query = TrackingItem.query(on: request.db)
            .with(\.$customers)
            .filter(\.$boxedAt == nil)
            .filter(\.$repackedAt <= limitedDate)
        if let agentID = input.agentID {
            query = query.filter(\.$agentCode == agentID)
        }
        query = query.sort(\.$repackedAt, .ascending)
        let page = try await query.paginate(for: request)
        return .init(
            items: page.items.map { $0.output() },
            metadata: page.metadata)
    }
    
    private func getStockFromDeliToReceiveAtVNHandler(request: Request) async throws -> Page<TrackingItemOutput> {
        let input = try request.query.decode(GetStockInput.self)
        let limitedDay = 10.0
        let limitedDate = Date().addingTimeInterval(.oneDay*(-limitedDay))
        var query = TrackingItem.query(on: request.db)
            .with(\.$customers)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$receivedAtUSAt <= limitedDate)
            .sort(\.$receivedAtUSAt, .ascending)
        if let agentID = input.agentID {
            query = query.filter(\.$agentCode == agentID)
        }
        let page = try await query.paginate(for: request)
        return .init(
            items: page.items.map { $0.output() },
            metadata: page.metadata)
    }
    
    private func getStockCountHandler(request: Request) async throws -> StockCountOutput {
        let limitedDeliToRepackDate = Date().addingTimeInterval(.oneDay*(-3.0))
        let limitedRepackToBoxDate = Date().addingTimeInterval(.oneDay*(-3.0))
        let limitedDeliToReceiveAtVNDate = Date().addingTimeInterval(.oneDay*(-10.0))

        let deliToRepackCount = try await TrackingItem.query(on: request.db)
            .filter(\.$repackedAt == nil)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$receivedAtUSAt <= limitedDeliToRepackDate)
            .filter(\.$agentCode != nil)
            .count()
        let repackToBoxCount = try await TrackingItem.query(on: request.db)
            .filter(\.$boxedAt == nil)
            .filter(\.$repackedAt <= limitedRepackToBoxDate)
            .filter(\.$agentCode != nil)
            .count()
        let deliToReceiveAtVNCount = try await TrackingItem.query(on: request.db)
            .filter(\.$receivedAtVNAt == nil)
            .filter(\.$receivedAtUSAt <= limitedDeliToReceiveAtVNDate)
            .filter(\.$agentCode != nil)
            .count()
        
        return .init(
            deliToRepackCount: deliToRepackCount,
            repackToBoxCount: repackToBoxCount,
            deliToReceiveAtVN: deliToReceiveAtVNCount)
    }
}
