import Foundation
import Vapor
import Fluent

struct CustomterInfoOutput: Content {
    let ordersCount: Int
    let receiptsCount: Int
    let vnCount: Int
    let usCount: Int
    let weight: Double
    let info: CustomerOutput
}
