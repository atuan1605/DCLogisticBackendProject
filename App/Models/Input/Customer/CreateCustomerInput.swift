import Vapor
import Foundation
import Fluent

struct CreateCustomerInput: Content {
    
    var customerName: String
    var customerCode: String
    var agentID: String
    var phoneNumber: String?
    var email: String?
    var address: String?
    var note: String?
    var socialLinks: SocialLinksOutput
    var priceNote: String?
    var isProvince: Bool?
    var googleLink: String?
    
    internal init(
        customerName: String,
        customerCode: String,
        agentID: String,
        phoneNumber: String? = nil,
        email: String? = nil,
        address: String? = nil,
        note: String? = nil,
        socialLinks: SocialLinksOutput = .init(),
        priceNote: String? = nil,
        isProvince: Bool? = nil,
        googleLink: String? = nil) {
        self.customerName = customerName
        self.customerCode = customerCode
        self.agentID = agentID
        self.phoneNumber = phoneNumber
        self.email = email
        self.address = address
        self.note = note
        self.socialLinks = socialLinks
        self.priceNote = priceNote
        self.isProvince = isProvince
        self.googleLink = googleLink
    }
    
    
    init(agentID: String, res: [String]) {
        self.customerName = res.get(at: 2) ?? ""
        self.customerCode = res.get(at: 9) ?? ""
        self.agentID = agentID
        self.phoneNumber = ("+84 \(res.get(at: 5) ?? "")").validPhoneNumber()
        self.email = res.get(at: 3)
        self.address = res.get(at: 13)
        self.note = res.get(at: 7)
        self.socialLinks = SocialLinksOutput(facebook: res.get(at: 6))
        self.priceNote = res.get(at: 1)
        self.isProvince = !(res.get(at: 8)?.isEmpty ?? true)
        self.googleLink = res.get(at: 11)
    }
}

struct SocialLinksOutput: Content {
    
    var facebook: String?
    var zalo: String?
    var telegram: String?
    
    func toSocialLink() -> SocialLinks {
        return .init(
            facebook: self.facebook,
            zalo: self.zalo,
            telegram: self.telegram)
    }
}

extension CreateCustomerInput: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("customerName", as: String.self, is: !.empty)
        validations.add("customerCode", as: String.self, is: !.empty)
        validations.add("agentID", as: String.self, is: !.empty)
    }
}

extension CreateCustomerInput {
    func toCustomer() -> Customer {
        return .init(
            customerName: self.customerName.uppercased(),
            customerCode: self.customerCode.uppercased(),
            agentID: self.agentID,
            phoneNumber: self.phoneNumber,
            email: self.email,
            address: self.address,
            note: self.note,
            socialLinks: self.socialLinks.toSocialLink(),
            priceNote: self.priceNote,
            isProvince: self.isProvince,
            googleLink: self.googleLink
        )
    }
}
