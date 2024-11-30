import Foundation
import Vapor

struct FileController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let groupedRoutes = routes.grouped("files")

        let authenticated = groupedRoutes
            .grouped(UserJWTAuthenticator())
            .grouped(User.guardMiddleware())

        authenticated.on(.POST, ":agentID", body: .collect(maxSize: "5mb"), use: uploadHandler)
        groupedRoutes.get(":agentID", ":fileID", use: getHandler)
    }

    private func getHandler(request: Request) async throws -> ClientResponse {
        guard
            let agentID = request.parameters.get("agentID", as: String.self),
            !agentID.isEmpty,
            let friendlyAgentID = agentID.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let fileID = request.parameters.get("fileID", as: String.self)
        else {
            throw AppError.invalidInput
        }

        return try await request
            .fileStorages
            .get(name: fileID,
                 folder: "agent-\(friendlyAgentID)")
    }

    private func uploadHandler(request: Request) async throws -> String {
        guard
            let agentID = request.parameters.get("agentID", as: String.self),
            !agentID.isEmpty,
            let friendlyAgentID = agentID.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let buffer = request.body.data,
            let contentType = request.headers.contentType
        else {
            throw AppError.invalidInput
        }
        let input = try request.query.decode(UploadFileQueryInput.self)
        let data = Data.init(buffer: buffer)
        var fileName = UUID().uuidString
        if let origin = input.origin {
            fileName = "\(origin)_\(fileName)"
        }
        return try await request
            .fileStorages
            .upload(data: data,
                contentType: contentType.description,
                with: fileName,
                to: "agent-\(friendlyAgentID)"
            )
    }
}
