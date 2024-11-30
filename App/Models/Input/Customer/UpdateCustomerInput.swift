import Foundation
import Vapor

struct UpdateCustomerInput: Content {
    let customerName: String?
    let customerCode: String?
    let phoneNumber: String?
    let email: String?
    let address: String?
    let note: String?
    let agentID: String?
    let facebook: String?
    let zalo: String?
    let telegram: String?
    let priceNote: String?
    let isProvince: Bool?
    let googleLink: String?
}
