import Vapor
import Foundation

struct AddBoxToShipmentInput: Content {
    var boxIDs: [Box.IDValue]
}
