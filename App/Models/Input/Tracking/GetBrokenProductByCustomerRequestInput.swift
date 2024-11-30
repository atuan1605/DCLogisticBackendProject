import Foundation
import Vapor

struct GetBrokenProductByCustomerRequestInput: Content {
    var page: Int
    var per: Int
    var searchStrings: [String]?
    var isShowPendingOnly: Bool
}
