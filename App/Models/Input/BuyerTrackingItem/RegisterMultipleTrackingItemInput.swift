import Foundation
import Vapor

struct RegisterMultipleTrackingItemInput: Content {
    var trackingNumbers: [String]
    var sharedNote: String?
    var sharedPackingRequest: String?
//    var deposit: Int
    var quantity: Int?
}
