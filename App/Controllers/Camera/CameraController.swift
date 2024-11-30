import Vapor
import Fluent
import Foundation

struct CameraController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes
            .grouped("cameras")
            .grouped(UserJWTAuthenticator(),User.guardMiddleware())
        groupedRoutes.get(use: getCamerasHandler)
        groupedRoutes.post(":cameraID", "logScanQr", use: logScanQrHandler)
        
    }
    
    private func getCamerasHandler(req: Request) async throws -> [String] {
        let cameras = try await Camera.query(on: req.db)
            .all()
        return cameras.compactMap { $0.id }
    }
    
    private func logScanQrHandler(request: Request) async throws -> HTTPResponseStatus {
        let input = try request.content.decode(LogScanCameraQrCodeInput.self)
        if let cameraID = request.parameters.get("cameraID", as: String.self) {
            request.appendUserAction(.scanCameraQrCode(deviceID: input.deviceID, cameraID: cameraID))
        }
        return .ok
    }
}
