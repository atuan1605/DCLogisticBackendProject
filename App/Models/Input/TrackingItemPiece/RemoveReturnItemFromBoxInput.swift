import Vapor
import Foundation

struct RemoveReturnItemFromBoxInput: Content {
    var status: ReturnStatus
    var boxID: Box.IDValue
    var boxName: String
}
