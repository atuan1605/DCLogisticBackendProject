import Foundation
import Vapor

struct CustomerSelectionsInput: Content {
    let customerIDs: [Customer.IDValue]
}
