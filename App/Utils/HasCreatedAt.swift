//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
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

