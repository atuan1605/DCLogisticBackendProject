import Vapor
import Foundation
import Fluent

struct CustomerOutput: Content {
    var id: Customer.IDValue?
    var customerCode: String
    var customerName: String?
    var agentCode: String
    var phoneNumber: String?
    var email: String?
    var address: String?
    var note: String?
    var socialLinks: SocialLinks
    var trackingItemsCount: Int?
    var weight: Double?
    var priceNote: String?
    var isProvince: Bool?
    var googleLink: String?
    var customerPrices: [CustomerPriceOutput]?
}

struct CustomerForListOutput: Content {
    var id: Customer.IDValue?
    var customerCode: String
    var trackingItemsCount: Int
    var email: String?
    var note: String?
    var totalWeight: Double?
}

struct CustomerCodeOutput: Content {
    var id: Customer.IDValue?
    var customerCode: String
}

extension Customer {
    
    func output() -> CustomerOutput {
        return .init(
            id: self.id,
            customerCode: self.customerCode,
            customerName: self.customerName,
            agentCode: self.$agent.value?.name ?? "",
            phoneNumber: self.phoneNumber,
            email: self.email,
            address: self.address,
            note: self.note,
            socialLinks: self.socialLinks,
            trackingItemsCount: self.$trackingItems.value?.count,
            weight: try? self.$trackingItems.value?
                .compactMap { $0.packBox }
                .removingDuplicates { $0.id }
                .compactMap { $0.weight }.reduce(0, +) ?? 0,
            priceNote: self.priceNote,
            isProvince: self.isProvince,
            googleLink: self.googleLink,
            customerPrices: self.$prices.value?.map { $0.toOutput() })
    }
    
    func outputByCode() -> CustomerCodeOutput {
        return .init(
            id: self.id,
            customerCode: self.customerCode
        )
    }

    func outputForList() -> CustomerForListOutput {
        return .init(
            id: self.id,
            customerCode: self.customerCode,
            trackingItemsCount: self.$trackingItems.value?.count ?? 0,
            email: self.email,
            note: self.note,
            totalWeight: try? self.$trackingItems.value?
                .compactMap { $0.packBox }
                .removingDuplicates { $0.id }
                .compactMap { $0.weight }.reduce(0, +) ?? 0
            )
    }
}
