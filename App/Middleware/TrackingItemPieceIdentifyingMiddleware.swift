import Vapor
import Foundation
import Fluent

struct TrackingItemPieceIdentifyingMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        if let pieceID = request.parameters.get(TrackingItemPiece.parameter, as: TrackingItem.IDValue.self) {
            guard let trackingItem = request.trackingItem  else {
                throw AppError.trackingItemNotFound
            }
                request.trackingItemPiece = try await trackingItem.$pieces.query(on: request.db)
                    .filter(\.$id == pieceID)
                    .first()
        }
        return try await next.respond(to: request)
    }
}

struct TrackingItemPieceKey: StorageKey {
    typealias Value = TrackingItemPiece
}

extension Request {
    var trackingItemPiece: TrackingItemPiece? {
        get {
            self.storage[TrackingItemPieceKey.self]
        }
        set {
            self.storage[TrackingItemPieceKey.self] = newValue
        }
    }
    
    func requiredTrackingItemPiece() throws -> TrackingItemPiece {
        guard let trackingItemPiece = self.trackingItemPiece else {
            throw AppError.trackingItemPieceNotFound
        }
        return trackingItemPiece
    }
}
