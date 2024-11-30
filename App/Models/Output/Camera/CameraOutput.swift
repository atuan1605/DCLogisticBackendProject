import Vapor
import Foundation

struct CameraOutput: Content {
    var id: Camera.IDValue?
    var name: String
}

extension Camera {
    func output() -> CameraOutput {
        return .init(id: self.id, name: self.name)
    }
}
