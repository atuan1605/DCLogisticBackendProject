//
//  File.swift
//  Logistic
//
//  Created by Anh Tuan on 19/11/24.
//

import Foundation


extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}

extension Array {
    
    func get(at index: Int) -> Element? {
        guard index >= 0 && self.count > index else {
            return nil
        }
        return self[index]
    }
    
    func removingDuplicates<K: Hashable>(by keyForValue: (Element) throws -> K) throws -> [Element] {
        let dict = try Dictionary(grouping: self, by: keyForValue)
        return dict.mapValues { $0.first }.compactMap { $0.value }
    }

    mutating func removeDuplicates<K: Hashable>(by keyForValue: (Element) throws -> K) throws {
        self = try self.removingDuplicates(by: keyForValue)
    }

    func indexed<K: Hashable>(by keyForValue: (Element) throws -> K) throws -> [K: Element] {
        return try self.reduce(into: [K: Element]()) { carry, next in
            let key = try keyForValue(next)
            carry[key] = next
        }
    }

    func grouped<K: Hashable>(by keyForValue: (Element) throws -> K) throws -> [K: [Element]] {
        return try Dictionary.init(grouping: self, by: keyForValue)
    }
}

extension Sequence {
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
    
    func asyncMap<T>(
        _ operation: (Element) async throws -> T
    ) async rethrows -> [T] {
        var returns = [T]()
        for element in self {
            let returnValue = try await operation(element)
            returns.append(returnValue)
        }
        return returns
    }
    
    func asyncCompactMap<T>(
        _ operation: (Element) async throws -> T?
    ) async rethrows -> [T] {
        var returns = [T]()
        for element in self {
            if let returnValue = try await operation(element) {
                returns.append(returnValue)
            }
        }
        return returns
    }

    func asyncReduce<Result>(
        _ initialResult: Result,
        _ nextPartialResult: ((Result, Element) async throws -> Result)
    ) async rethrows -> Result {
        var result = initialResult
        for element in self {
            result = try await nextPartialResult(result, element)
        }
        return result
    }
}

