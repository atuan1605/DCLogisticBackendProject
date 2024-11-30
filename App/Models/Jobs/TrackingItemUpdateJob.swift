import Vapor
import Fluent
import Queues

struct TrackingItemStatusUpdateJob: AsyncJob {
	struct Payload: Codable {
		var timestampt: Date
		var trackingNumber: String
		var sheetName: String?
		var status: TrackingItem.Status
        var pieces: [String]?
	}

	func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
		let trackingNumber = payload.trackingNumber
		
		guard trackingNumber.isValidTrackingNumber() else {
			throw AppError.invalidInput
		}
		
		let db = context.application.db

		if let existingTrackingItem = try await TrackingItem.query(on: db)
			.filter(trackingNumbers: [trackingNumber])
            .with(\.$pieces)
			.first() {
			if existingTrackingItem.status.power < payload.status.power {
				try await db.transaction { transactionDB in
                    if let piecesInfo = payload.pieces {
                        var targetPieces : [TrackingItemPiece] = []
                        existingTrackingItem.pieces.forEach {
                            if let info = $0.information, piecesInfo.contains(info) {
                                targetPieces.append($0)
                            }
                        }
                        try await targetPieces.asyncForEach { piece in
                            switch payload.status {
                            case .new, .registered, .receivedAtUSWarehouse, .repacking, .repacked, .archiveAtVN, .packedAtVN, .packBoxCommitted, .deliveredAtVN:
                                break
                            case .boxed:
                                piece.boxedAt = payload.timestampt
                            case .flyingBack:
                                piece.flyingBackAt = payload.timestampt
                            case .receivedAtVNWarehouse:
                                piece.receivedAtVNAt = payload.timestampt
                            }
                            try await piece.save(on: transactionDB)
                        }

						let keyPath = try payload.status.keyPath()
						var targetPieceKeyPath: KeyPath<TrackingItemPiece, OptionalFieldProperty<TrackingItemPiece, Date>>? = nil
						switch keyPath {
						case \.$boxedAt:
							targetPieceKeyPath = \TrackingItemPiece.$boxedAt
						case \.$flyingBackAt:
							targetPieceKeyPath = \TrackingItemPiece.$flyingBackAt
						case \.$receivedAtVNAt:
							targetPieceKeyPath = \TrackingItemPiece.$receivedAtVNAt
						default:
							break
						}
                        if let targetPieceKeyPath, existingTrackingItem.pieces.allSatisfy({ piece in
							piece[keyPath: targetPieceKeyPath].wrappedValue != nil
                        }) {
                            existingTrackingItem.update(using: keyPath, to: payload.timestampt)
                            let trackingItemID = try existingTrackingItem.requireID()
                            let logger = ActionLogger(
                                userID: nil,
                                agentIdentifier: payload.sheetName,
                                type: .assignTrackingItemStatus(trackingNumber: existingTrackingItem.trackingNumber, trackingItemID: trackingItemID, status: payload.status)
                            )
                            try await existingTrackingItem.save(on: transactionDB)
                            try await logger.save(on: transactionDB)
                        }
                    } else {
                        if existingTrackingItem.pieces.count == 1 {
                            try await existingTrackingItem.pieces.asyncForEach { piece in
                                switch payload.status {
                                case .new, .registered, .receivedAtUSWarehouse, .repacking, .repacked, .archiveAtVN, .packedAtVN, .packBoxCommitted, .deliveredAtVN:
                                    break
                                case .boxed:
                                    piece.boxedAt = payload.timestampt
                                case .flyingBack:
                                    piece.flyingBackAt = payload.timestampt
                                case .receivedAtVNWarehouse:
                                    piece.receivedAtVNAt = payload.timestampt
                                }
                                try await piece.save(on: transactionDB)
                            }
                            let keyPath = try payload.status.keyPath()
                            existingTrackingItem.update(using: keyPath, to: payload.timestampt)
                            let trackingItemID = try existingTrackingItem.requireID()
                            let logger = ActionLogger(
                                userID: nil,
                                agentIdentifier: payload.sheetName,
                                type: .assignTrackingItemStatus(trackingNumber: existingTrackingItem.trackingNumber, trackingItemID: trackingItemID, status: payload.status)
                            )
                            try await existingTrackingItem.save(on: transactionDB)
                            try await logger.save(on: transactionDB)
						} else {
							throw AppWithOutputError.piecesNotFound("No piece info provided")
						}
                    }
				}
				
				try await context.application.queues.queue.dispatch(
					DeprecatedTrackingItemStatusUpdateJob.self,
					.init(
						trackingNumber: existingTrackingItem.trackingNumber,
						status: payload.status,
						timestampt: payload.timestampt
					)
				)
			}
		} else {
			let newTrackingItem = TrackingItem(trackingNumber: trackingNumber)
			let keyPath = try payload.status.keyPath()
			newTrackingItem.update(using: keyPath, to: payload.timestampt)
			
			try await db.transaction { transactionDB in
				try await newTrackingItem.save(on: transactionDB)
				let trackingItemID = try newTrackingItem.requireID()
				let logger = ActionLogger(
					userID: nil,
					agentIdentifier: payload.sheetName,
                    type: .assignTrackingItemStatus(trackingNumber: newTrackingItem.trackingNumber, trackingItemID: trackingItemID, status: payload.status)
				)
				try await logger.save(on: transactionDB)
				let defaultPiece = TrackingItemPiece(
					information: "default",
					trackingItemID: trackingItemID)
				try await defaultPiece.save(on: transactionDB)
			}
			try await context.application.queues.queue.dispatch(
				DeprecatedTrackingItemStatusUpdateJob.self,
				.init(
					trackingNumber: newTrackingItem.trackingNumber,
					status: payload.status,
					timestampt: payload.timestampt
				)
			)
		}
		
		
	}

	func error(_ context: QueueContext, _ error: Error, _ payload: Payload) async throws {
		let db = context.application.db
		let encoder = JSONEncoder()
		let data = try encoder.encode(payload)
		let failedJob = FailedJob(payload: data, jobIdentifier: String(describing: Self.self), error: "\(error)", trackingNumber: payload.trackingNumber)
		try await failedJob.save(on: db)
	}
}
