import Foundation
import Vapor
import Fluent

struct AgentOutput: Content {
    
    let id: String?
    let name: String?
    let popularProducts: [String]?
    let primaryColor: String?
    let logo: String?
    let accentColor: String?
    let inactiveAt: Date?
    let createdAt: Date?
    
     init(
        id: String? = nil,
        name: String? = nil,
        popularProducts: [String]? = nil,
        primaryColor: String? = nil,
        logo: String? = nil,
        accentColor: String? = nil,
        inactiveAt: Date? = nil,
        createdAt: Date? = nil
     ) {
            self.id = id
            self.name = name
            self.popularProducts = popularProducts
            self.primaryColor = primaryColor
            self.logo = logo
            self.accentColor = accentColor
            self.inactiveAt = inactiveAt
            self.createdAt = createdAt
        }
}

extension Agent: HasOutput {
    
    func output() -> AgentOutput {
        .init(
            id: self.id,
            name: self.name,
            popularProducts: self.popularProducts,
            primaryColor: self.primaryColor,
            logo: self.logo,
            accentColor: self.accentColor,
            inactiveAt: self.inactiveAt,
            createdAt: self.createdAt
            )
    }
}

extension AgentOutput: CanBeInitByID {
    init(validID: String) {
        self .init(id: validID)
    }
}
