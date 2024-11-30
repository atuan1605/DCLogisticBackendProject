import Vapor
import Foundation

struct CreateMultipleSubLabelsInput: Content {
    var subItems: [CreateSubLabelInput]
}
