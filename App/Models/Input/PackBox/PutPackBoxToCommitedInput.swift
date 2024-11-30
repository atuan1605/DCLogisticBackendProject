import Vapor
import Foundation

struct PutPackBoxToCommitedInput: Content {
    let packBoxIDs: [PackBox.IDValue]
}
