import Vapor
import Foundation

struct CreateMultipleLabelsInput: Content {
    var items: [CreateLabelInput]
}
