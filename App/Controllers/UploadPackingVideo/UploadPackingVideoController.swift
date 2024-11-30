import Foundation
import Vapor
import Fluent

struct UploadPackingVideoController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("packingVideos")
        let authenticated = groupedRoutes
            .grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())
        
        authenticated.get(use: getTrackingItemHandler)
        authenticated.get("downloadingJob", use: getVideoDownloadingJobHandler)
        authenticated.get(":fileID", use: getVideoHandler)
        let trackingItemUnauthenticatedRoutes = groupedRoutes
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())
        trackingItemUnauthenticatedRoutes.on(.POST, body: .collect(maxSize: "100mb"), use: uploadVideoHandler)
        
        let trackingItemAuthenticatedRoutes = authenticated
            .grouped(TrackingItem.parameterPath)
            .grouped(TrackingItemIdentifyingMiddleware())
        trackingItemAuthenticatedRoutes.post("extractPackingVideo", use: extractPackingVideoHandler)
        trackingItemAuthenticatedRoutes.put("cameraDetail", use: updateCameraDetailHandler)
        trackingItemAuthenticatedRoutes.post("cameraDetail", use: createTrackingCameraDetailHandler)
        let queueRoutes = authenticated.grouped("queues")
            .grouped(VideoDownloadingJob.parameterPath)
            .grouped(VideoDownloadingJobIdentifyingMiddleware())
        queueRoutes.delete(use: removePackingVideoHandler)
    }
    
    private func createTrackingCameraDetailHandler(request: Request) async throws -> TrackingCameraDetailOutput {
        let trackingItem = try request.requireTrackingItem()
        let trackingID = try trackingItem.requireID()
        let input = try request.content.decode(CreateTrackingCameraDetailInput.self)
        var targetDetail: TrackingCameraDetail = .init()
        let existDetail = try await TrackingCameraDetail.query(on: request.db)
            .filter(\.$trackingItem.$id == trackingID)
            .filter(\.$step == input.step)
            .first()
        if let existDetail = existDetail {
            targetDetail = existDetail
            if existDetail.$camera.id != input.cameraID {
                targetDetail.$camera.id = input.cameraID
                try await targetDetail.save(on: request.db)
                targetDetail = existDetail
            }
        } else {
            let insertDetail = input.toTrackingCameraDetail(trackingID: trackingID)
            try await insertDetail.create(on: request.db)
            targetDetail = insertDetail
        }
        return targetDetail.output()
    }
    
    private func updateCameraDetailHandler(req: Request) async throws -> HTTPResponseStatus {
        let trackingItem = try req.requireTrackingItem()
        let trackingItemID = try trackingItem.requireID()
        let now = Date()
        try await TrackingCameraDetail.query(on: req.db)
            .filter(\.$trackingItem.$id == trackingItemID)
            .set(\.$recordFinishAt, to: now)
            .update()
        return .ok
    }
    
    private func extractPackingVideoHandler(request: Request) async throws -> HTTPResponseStatus {
        return try await request.trackingItems.extractPackingVideo(request: request)
    }
    
    private func getTrackingItemHandler(req: Request) async throws -> GetTrackingItemPackingVideoOutput {
        let input = try req.query.decode(GetTrackingItemPackingVideoQueryInput.self)
        guard let trackingItem = try await TrackingItem.query(on: req.db)
            .filter(searchStrings: [input.searchString], includeAlternativeRef: true)
            .with(\.$packingVideoQueues)
            .with(\.$products)
            .with(\.$warehouse)
            .with(\.$customers)
            .first()
        else {
            throw AppError.trackingItemNotFound
        }
        guard trackingItem.status.power >= 3 else {
            throw AppError.cannotExtractPackingVideo
        }
        return trackingItem.packingVideoOutput()
    }
    
    private func removePackingVideoHandler(req: Request) async throws -> HTTPResponseStatus {
        let queueID = try req.requireVideoDownloadingJob().requireID()
        try await VideoDownloadingJob.query(on: req.db)
            .filter(\.$id == queueID)
            .delete()
        return .ok
    }
    
    private func getVideoDownloadingJobHandler(req: Request) async throws -> Page<GetTrackingItemPackingVideoOutput> {
        let queues = try await VideoDownloadingJob.query(on: req.db)
            .all()
        let grouped = try queues.grouped(by: {$0.$trackingItem.id})
        let trackingIDs = queues.compactMap { $0.$trackingItem.id }
        let query = TrackingItem.query(on: req.db)
            .filter(\.$id ~~ trackingIDs)
            .with(\.$products)
            .with(\.$warehouse)
            .with(\.$customers)
            .join(VideoDownloadingJob.self, on: \VideoDownloadingJob.$trackingItem.$id == \TrackingItem.$id, method: .left)
            .sort(VideoDownloadingJob.self, \.$finishedAt, .descending)
        let page = try await query.paginate(for: req)
        return .init(
            items: try page.items.map{ item in
                item.$packingVideoQueues.value = try grouped[item.requireID()]
                return item.packingVideoOutput() },
            metadata: page.metadata
        )
    }
    
    private func uploadVideoHandler(request: Request) async throws -> String {
        var fileID = ""
        let trackingItem = try request.requireTrackingItem()
        guard trackingItem.status.power >= 3 else {
            throw AppError.invalidStatus
        }
        let input = try request.content.decode(UploadPackingVideoInput.self)
        guard let videoName = input.file?.filename, videoName.contains("_cut") else {
            throw AppError.invalidInput
        }
        if let file = input.file {
            fileID = try await request.fileStorages
                .upload(file: file, to: "packingvideos")
        }
        if !fileID.isEmpty {
            trackingItem.packingVideoFile = fileID
            try await trackingItem.save(on: request.db)
            let fileManager = FileManager.default
            let filePath = "Downloads/\(videoName)"
            if fileManager.fileExists(atPath: filePath) {
                try fileManager.removeItem(atPath: filePath)
            }
        }
        return fileID
    }
    
    private func getVideoHandler(request: Request) async throws -> ClientResponse {
        guard let fileID = request.parameters.get("fileID", as: String.self) else {
            throw AppError.invalidInput
        }
        return try await request.fileStorages.get(name: fileID, folder: "packingvideos")
    }

}
