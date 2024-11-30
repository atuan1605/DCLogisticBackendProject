//
//  File.swift
//  
//
//  Created by Phan Anh Tran on 28/10/2022.
//

import Foundation

protocol HasCreatedAt {
    var createdAt: Date? { get }
}

extension Array where Element: HasCreatedAt {
    func sortCreatedAtDescending() -> [Element] {
        let allWithout = self.filter {
            $0.createdAt == nil
        }
        var allWith = self.filter {
            $0.createdAt != nil
        }.sorted { lhs, rhs in
            guard let lhsCreatedAt = lhs.createdAt, let rhsCreatedAt = rhs.createdAt else {
                return false
            }
            return lhsCreatedAt.compare(rhsCreatedAt) == .orderedDescending
        }
        
        allWith.append(contentsOf: allWithout)
        return allWith
    }
}
