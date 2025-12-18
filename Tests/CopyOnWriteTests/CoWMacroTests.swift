// CoWMacroTests.swift

import Foundation
import Testing
import CopyOnWrite

// MARK: - Test Types

@CoW
struct Point {
    var x: Int
    var y: Int
}

@CoW
struct Counter {
    var count: Int = 0
    var name: String
}

@CoW
struct MixedAccess {
    public var publicValue: Int
    internal var internalValue: String
}

@CoW
struct WithPrivateSet {
    private(set) var id: String
    var value: Int
}

@`Copy on Write`
struct FullNamedMacro {
    var name: String
    var count: Int = 0
}

// Test types with protocol conformances
@CoW
struct EquatablePoint: Equatable {
    var x: Int
    var y: Int
}

@CoW
struct HashablePoint: Hashable {
    var x: Int
    var y: Int
}

@CoW
struct CodablePerson: Codable {
    var name: String
    var age: Int
}

// Test type with CustomStringConvertible
@CoW
struct DescribablePoint: CustomStringConvertible {
    var x: Int
    var y: Int
}

// Test type with optional properties
@CoW
struct WithOptional {
    var name: String
    var nickname: String?
    var age: Int = 0
}

// Test nested CoW structs
@CoW
struct Inner {
    var value: Int
}

@CoW
struct Outer {
    var inner: Inner
    var label: String
}

// Test struct with computed property (should be preserved)
@CoW
struct WithComputed {
    var width: Int
    var height: Int

    var area: Int {
        width * height
    }
}

// MARK: - Complex Type Tests

// Test labeled tuple array
@CoW
struct WithLabeledTupleArray {
    var items: [(name: String, value: Int)]
}

// Test optional labeled tuple
@CoW
struct WithOptionalTuple {
    var pair: (first: String, second: Int)?
}

// Test nested dictionary
@CoW
struct WithNestedGeneric {
    var data: [String: [Int]]
}

// Test function type
@CoW
struct WithFunctionType {
    var handler: ((Int) -> Void)?
}

// Test dictionary type
@CoW
struct WithDictionary {
    var mapping: [String: Int]
}

// MARK: - Tests

@Suite("Copy on Write Macro Tests")
struct CopyOnWriteTests {

    @Test("Basic CoW value semantics")
    func basicCoW() {
        var p1 = Point(x: 10, y: 20)
        let p2 = p1

        // Before mutation, should be equal
        #expect(p1.x == p2.x)
        #expect(p1.y == p2.y)

        // Mutate p1
        p1.x = 100

        // p1 should have changed, p2 should remain the same (value semantics)
        #expect(p1.x == 100)
        #expect(p2.x == 10)
    }

    @Test("Default values are preserved")
    func defaultValues() {
        let c1 = Counter(name: "Test")
        #expect(c1.count == 0)
        #expect(c1.name == "Test")

        let c2 = Counter(count: 5, name: "Custom")
        #expect(c2.count == 5)
    }

    @Test("CoW semantics - copy on mutation")
    func coWSemantics() {
        var c1 = Counter(count: 1, name: "Original")
        let c2 = c1

        // Mutate c1
        c1.count = 999
        c1.name = "Modified"

        // c2 should be unchanged (CoW made a copy on mutation)
        #expect(c2.count == 1)
        #expect(c2.name == "Original")

        // c1 should have new values
        #expect(c1.count == 999)
        #expect(c1.name == "Modified")
    }

    @Test("private(set) properties work with CoW")
    func privateSetProperty() {
        let w = WithPrivateSet(id: "abc", value: 42)
        #expect(w.id == "abc")
        #expect(w.value == 42)

        // private(set) properties are read-only from outside
        // but the CoW mechanism still applies
        var w2 = w
        w2.value = 100
        #expect(w2.value == 100)
        #expect(w2.id == "abc")  // id is still the same (value semantics)
    }

    @Test("Mixed access levels")
    func mixedAccessLevels() {
        var m = MixedAccess(publicValue: 1, internalValue: "test")
        #expect(m.publicValue == 1)
        #expect(m.internalValue == "test")

        m.publicValue = 2
        m.internalValue = "modified"
        #expect(m.publicValue == 2)
        #expect(m.internalValue == "modified")
    }

    @Test("Multiple copies maintain independence")
    func multipleCopies() {
        var original = Point(x: 1, y: 1)
        var copy1 = original
        var copy2 = original
        var copy3 = copy1

        // All start equal
        #expect(original.x == 1)
        #expect(copy1.x == 1)
        #expect(copy2.x == 1)
        #expect(copy3.x == 1)

        // Mutate each independently
        original.x = 10
        copy1.x = 20
        copy2.x = 30
        copy3.x = 40

        // All should have independent values
        #expect(original.x == 10)
        #expect(copy1.x == 20)
        #expect(copy2.x == 30)
        #expect(copy3.x == 40)
    }

    @Test("No unnecessary copy on unique reference")
    func noUnnecessaryCopy() {
        var p = Point(x: 1, y: 2)

        // Reading should not cause a copy
        let _ = p.x
        let _ = p.y

        // Mutating a uniquely-referenced value should not copy either
        p.x = 10
        #expect(p.x == 10)
    }

    @Test("@`Copy on Write` full name works same as @CoW")
    func fullNamedMacro() {
        var f1 = FullNamedMacro(name: "Test")
        let f2 = f1

        #expect(f1.name == "Test")
        #expect(f1.count == 0)
        #expect(f2.name == "Test")

        f1.name = "Modified"
        f1.count = 5

        // Value semantics should apply
        #expect(f1.name == "Modified")
        #expect(f1.count == 5)
        #expect(f2.name == "Test")
        #expect(f2.count == 0)
    }

    // MARK: - isIdentical(to:) Tests

    @Test("isIdentical returns true for shared storage")
    func isIdenticalSharedStorage() {
        let p1 = Point(x: 10, y: 20)
        let p2 = p1

        // Before mutation, should share storage
        #expect(p1.isIdentical(to: p2))
    }

    @Test("isIdentical returns false after mutation")
    func isIdenticalAfterMutation() {
        var p1 = Point(x: 10, y: 20)
        let p2 = p1

        // Mutate p1, which triggers copy
        p1.x = 100

        // Should no longer share storage
        #expect(!p1.isIdentical(to: p2))
    }

    // MARK: - Equatable Tests

    @Test("Equatable conformance works")
    func equatableConformance() {
        let p1 = EquatablePoint(x: 10, y: 20)
        let p2 = EquatablePoint(x: 10, y: 20)
        let p3 = EquatablePoint(x: 10, y: 30)

        #expect(p1 == p2)
        #expect(p1 != p3)
    }

    @Test("Equatable works with copies")
    func equatableWithCopies() {
        var p1 = EquatablePoint(x: 10, y: 20)
        let p2 = p1

        // Should be equal (same values)
        #expect(p1 == p2)

        // Mutate p1
        p1.x = 100

        // Should not be equal (different values)
        #expect(p1 != p2)
    }

    // MARK: - Hashable Tests

    @Test("Hashable conformance works")
    func hashableConformance() {
        let p1 = HashablePoint(x: 10, y: 20)
        let p2 = HashablePoint(x: 10, y: 20)
        let p3 = HashablePoint(x: 10, y: 30)

        #expect(p1.hashValue == p2.hashValue)
        #expect(p1.hashValue != p3.hashValue)
    }

    @Test("Hashable works in Set")
    func hashableInSet() {
        let p1 = HashablePoint(x: 10, y: 20)
        let p2 = HashablePoint(x: 10, y: 20)
        let p3 = HashablePoint(x: 30, y: 40)

        var set: Set<HashablePoint> = [p1, p2, p3]
        #expect(set.count == 2)  // p1 and p2 are equal

        set.insert(HashablePoint(x: 50, y: 60))
        #expect(set.count == 3)
    }

    // MARK: - Codable Tests

    @Test("Encodable conformance works")
    func encodableConformance() throws {
        let person = CodablePerson(name: "Alice", age: 30)
        let encoder = JSONEncoder()
        let data = try encoder.encode(person)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"name\":\"Alice\"") || json.contains("\"name\": \"Alice\""))
        #expect(json.contains("\"age\":30") || json.contains("\"age\": 30"))
    }

    @Test("Decodable conformance works")
    func decodableConformance() throws {
        let json = #"{"name":"Bob","age":25}"#
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let person = try decoder.decode(CodablePerson.self, from: data)

        #expect(person.name == "Bob")
        #expect(person.age == 25)
    }

    @Test("Codable round-trip works")
    func codableRoundTrip() throws {
        let original = CodablePerson(name: "Charlie", age: 35)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CodablePerson.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.age == original.age)
    }

    // MARK: - CustomStringConvertible Tests

    @Test("CustomStringConvertible conformance works")
    func customStringConvertible() {
        let p = DescribablePoint(x: 10, y: 20)
        let description = p.description

        #expect(description.contains("DescribablePoint"))
        #expect(description.contains("x: 10"))
        #expect(description.contains("y: 20"))
    }

    @Test("CustomStringConvertible works with String interpolation")
    func customStringConvertibleInterpolation() {
        let p = DescribablePoint(x: 5, y: 15)
        let str = "\(p)"

        #expect(str == "DescribablePoint(x: 5, y: 15)")
    }

    // MARK: - Optional Property Tests

    @Test("Optional properties work with CoW")
    func optionalProperties() {
        var w1 = WithOptional(name: "Test", nickname: nil)
        #expect(w1.name == "Test")
        #expect(w1.nickname == nil)
        #expect(w1.age == 0)

        w1.nickname = "Testy"
        #expect(w1.nickname == "Testy")

        let w2 = WithOptional(name: "Full", nickname: "Nick", age: 25)
        #expect(w2.nickname == "Nick")
        #expect(w2.age == 25)
    }

    @Test("Optional properties maintain value semantics")
    func optionalPropertiesValueSemantics() {
        var w1 = WithOptional(name: "Original", nickname: "Nick")
        let w2 = w1

        w1.nickname = "Changed"

        #expect(w1.nickname == "Changed")
        #expect(w2.nickname == "Nick")
    }

    // MARK: - Nested CoW Struct Tests

    @Test("Nested CoW structs work")
    func nestedCoWStructs() {
        let inner = Inner(value: 42)
        var outer = Outer(inner: inner, label: "Test")

        #expect(outer.inner.value == 42)
        #expect(outer.label == "Test")

        outer.inner = Inner(value: 100)
        #expect(outer.inner.value == 100)
    }

    @Test("Nested CoW structs maintain value semantics")
    func nestedCoWValueSemantics() {
        let inner = Inner(value: 42)
        var outer1 = Outer(inner: inner, label: "Original")
        let outer2 = outer1

        // Mutate outer1's inner
        outer1.inner = Inner(value: 999)

        // outer2 should be unchanged
        #expect(outer1.inner.value == 999)
        #expect(outer2.inner.value == 42)
    }

    // MARK: - Computed Property Tests

    @Test("Computed properties are preserved")
    func computedProperties() {
        let rect = WithComputed(width: 10, height: 5)
        #expect(rect.area == 50)
    }

    @Test("Computed properties work with mutations")
    func computedPropertiesWithMutation() {
        var rect = WithComputed(width: 10, height: 5)
        #expect(rect.area == 50)

        rect.width = 20
        #expect(rect.area == 100)
    }

    // MARK: - Complex Type Tests

    @Test("Labeled tuple array works")
    func labeledTupleArray() {
        var s = WithLabeledTupleArray(items: [(name: "a", value: 1), (name: "b", value: 2)])
        #expect(s.items.count == 2)
        #expect(s.items[0].name == "a")
        #expect(s.items[0].value == 1)

        s.items.append((name: "c", value: 3))
        #expect(s.items.count == 3)
    }

    @Test("Labeled tuple array maintains value semantics")
    func labeledTupleArrayValueSemantics() {
        var s1 = WithLabeledTupleArray(items: [(name: "a", value: 1)])
        let s2 = s1

        s1.items.append((name: "b", value: 2))

        #expect(s1.items.count == 2)
        #expect(s2.items.count == 1)
    }

    @Test("Optional labeled tuple works")
    func optionalLabeledTuple() {
        var s = WithOptionalTuple(pair: (first: "hello", second: 42))
        #expect(s.pair?.first == "hello")
        #expect(s.pair?.second == 42)

        s.pair = nil
        #expect(s.pair == nil)

        s.pair = (first: "world", second: 100)
        #expect(s.pair?.first == "world")
    }

    @Test("Nested generic dictionary works")
    func nestedGenericDictionary() {
        var s = WithNestedGeneric(data: ["a": [1, 2, 3], "b": [4, 5]])
        #expect(s.data["a"]?.count == 3)
        #expect(s.data["b"]?.count == 2)

        s.data["c"] = [6, 7, 8, 9]
        #expect(s.data["c"]?.count == 4)
    }

    @Test("Function type works")
    func functionType() {
        var callCount = 0
        var s = WithFunctionType(handler: { _ in callCount += 1 })

        s.handler?(42)
        #expect(callCount == 1)

        s.handler = nil
        s.handler?(42)
        #expect(callCount == 1)  // Still 1 because handler is nil
    }

    @Test("Dictionary type works")
    func dictionaryType() {
        var s = WithDictionary(mapping: ["a": 1, "b": 2])
        #expect(s.mapping["a"] == 1)
        #expect(s.mapping["b"] == 2)

        s.mapping["c"] = 3
        #expect(s.mapping["c"] == 3)
    }

    @Test("Dictionary type maintains value semantics")
    func dictionaryValueSemantics() {
        var s1 = WithDictionary(mapping: ["a": 1])
        let s2 = s1

        s1.mapping["b"] = 2

        #expect(s1.mapping.count == 2)
        #expect(s2.mapping.count == 1)
    }
}
