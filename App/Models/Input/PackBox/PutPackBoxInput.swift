import Vapor
import Foundation

struct UpdatePackBoxInput: Content {
    var name: String?
    var weight: Double?
}
