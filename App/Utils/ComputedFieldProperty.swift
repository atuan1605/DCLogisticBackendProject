import Foundation
import Fluent

extension Fields {
    public typealias ComputedField<Value> = ComputedFieldProperty<Self, Value>
        where Value: Codable
}

@propertyWrapper
public final class ComputedFieldProperty<Model, Value>
    where Model: FluentKit.Fields, Value: Codable & Sendable
{
    public let key: FieldKey
    var outputValue: Value?
    var inputValue: DatabaseQuery.Value?
    
    public var projectedValue: ComputedFieldProperty<Model, Value> {
        self
    }

    public var wrappedValue: Value {
        get {
            guard let value = self.value else {
                fatalError("Cannot access field before it is initialized or fetched: \(self.key)")
            }
            return value
        }
        set {
            fatalError("Cannot set computed field: \(self.key)")
        }
    }

    public init(key: FieldKey) {
        self.key = key
    }
}

extension ComputedFieldProperty: CustomStringConvertible {
    public var description: String {
        "@\(Model.self).Field<\(Value.self)>(key: \(self.key))"
    }
}

// MARK: Property

extension ComputedFieldProperty: AnyProperty { }

extension ComputedFieldProperty: Property {
    public var value: Value? {
        get {
            if let value = self.inputValue {
                switch value {
                case .bind(let bind):
                    return bind as? Value
                case .enumCase(let string):
                    return string as? Value
                case .default:
                    fatalError("Cannot access default field for '\(Model.self).\(key)' before it is initialized or fetched")
                default:
                    fatalError("Unexpected input value type for '\(Model.self).\(key)': \(value)")
                }
            } else if let value = self.outputValue {
                return value
            } else {
                return nil
            }
        }
        set {
            self.inputValue = newValue.map { .bind($0) }
        }
    }
}

// MARK: Queryable

extension ComputedFieldProperty: AnyQueryableProperty {
    public var path: [FieldKey] {
        [self.key]
    }
}

extension ComputedFieldProperty: QueryableProperty { }

// MARK: Query-addressable

extension ComputedFieldProperty: AnyQueryAddressableProperty {
    public var anyQueryableProperty: AnyQueryableProperty { self }
    public var queryablePath: [FieldKey] { self.path }
}

extension ComputedFieldProperty: QueryAddressableProperty {
    public var queryableProperty: ComputedFieldProperty<Model, Value> { self }
}

// MARK: Database

extension ComputedFieldProperty: AnyDatabaseProperty {
    public var keys: [FieldKey] {
        [self.key]
    }

    public func input(to input: DatabaseInput) {
//        if let inputValue = self.inputValue {
//            input.set(inputValue, at: self.key)
//        }
    }

    public func output(from output: DatabaseOutput) throws {
        if output.contains(self.key) {
            self.inputValue = nil
            do {
                self.outputValue = try output.decode(self.key, as: Value.self)
            } catch {
                throw FluentError.invalidField(
                    name: self.key.description,
                    valueType: Value.self,
                    error: error
                )
            }
        }
    }
}

// MARK: Codable

extension ComputedFieldProperty: AnyCodableProperty {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.wrappedValue)
    }

    public func decode(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let valueType = Value.self as? AnyOptionalType.Type {
            // Hacks for supporting optionals in @Field.
            // Using @OptionalField is preferred moving forward.
            if container.decodeNil() {
                self.wrappedValue = (valueType.nil as! Value)
            } else {
                self.wrappedValue = try container.decode(Value.self)
            }
        } else {
            self.wrappedValue = try container.decode(Value.self)
        }
    }
}
