import Foundation
import Vapor
import Fluent

struct StockCountOutput: Content {
    let deliToRepackCount: Int
    let repackToBoxCount: Int
    let deliToReceiveAtVN: Int
}
