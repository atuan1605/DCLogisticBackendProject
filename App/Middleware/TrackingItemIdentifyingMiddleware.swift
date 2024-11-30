import Foundation
import Vapor

struct TrackingItemIdentifyingMiddleware: AsyncMiddleware {
    func respond(
        to request: Request,
        chainingTo next: AsyncResponder
    ) async throws -> Response {
        if let trackingItemID = request.parameters.get(TrackingItem.parameter, as: TrackingItem.IDValue.self) {
            let trackingItem = try await TrackingItem.find(trackingItemID, on: request.db)
            request.trackingItem = trackingItem
        }
        // logic trong middleware
        return try await next.respond(to: request)
    }
}

struct TrackingItemKey: StorageKey {
    typealias Value = TrackingItem
}

extension Request {
    var trackingItem: TrackingItem? {
        get {
            self.storage[TrackingItemKey.self]
        }
        set {
            self.storage[TrackingItemKey.self] = newValue
        }
    }

    func requireTrackingItem() throws -> TrackingItem {
        guard let trackingItem = self.trackingItem else {
            throw AppError.trackingItemNotFound
        }
        return trackingItem
    }

}
