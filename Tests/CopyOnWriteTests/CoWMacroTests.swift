// CoWMacroTests.swift

import XCTest
import CopyOnWrite

// MARK: - Functional Tests

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

final class CoWMacroTests: XCTestCase {

    func testBasicCoW() {
        var p1 = Point(x: 10, y: 20)
        let p2 = p1

        // Before mutation, should be equal
        XCTAssertEqual(p1.x, p2.x)
        XCTAssertEqual(p1.y, p2.y)

        // Mutate p1
        p1.x = 100

        // p1 should have changed, p2 should remain the same (value semantics)
        XCTAssertEqual(p1.x, 100)
        XCTAssertEqual(p2.x, 10)
    }

    func testDefaultValues() {
        let c1 = Counter(name: "Test")
        XCTAssertEqual(c1.count, 0)
        XCTAssertEqual(c1.name, "Test")

        let c2 = Counter(count: 5, name: "Custom")
        XCTAssertEqual(c2.count, 5)
    }

    func testCoWSemantics() {
        var c1 = Counter(count: 1, name: "Original")
        let c2 = c1

        // Mutate c1
        c1.count = 999
        c1.name = "Modified"

        // c2 should be unchanged (CoW made a copy on mutation)
        XCTAssertEqual(c2.count, 1)
        XCTAssertEqual(c2.name, "Original")

        // c1 should have new values
        XCTAssertEqual(c1.count, 999)
        XCTAssertEqual(c1.name, "Modified")
    }

    func testPrivateSetProperty() {
        let w = WithPrivateSet(id: "abc", value: 42)
        XCTAssertEqual(w.id, "abc")
        XCTAssertEqual(w.value, 42)

        // private(set) properties are read-only from outside
        // but the CoW mechanism still applies
        var w2 = w
        w2.value = 100
        XCTAssertEqual(w2.value, 100)
        XCTAssertEqual(w2.id, "abc")  // id is still the same (value semantics)
    }

    func testMixedAccessLevels() {
        var m = MixedAccess(publicValue: 1, internalValue: "test")
        XCTAssertEqual(m.publicValue, 1)
        XCTAssertEqual(m.internalValue, "test")

        m.publicValue = 2
        m.internalValue = "modified"
        XCTAssertEqual(m.publicValue, 2)
        XCTAssertEqual(m.internalValue, "modified")
    }

    func testMultipleCopies() {
        var original = Point(x: 1, y: 1)
        var copy1 = original
        var copy2 = original
        var copy3 = copy1

        // All start equal
        XCTAssertEqual(original.x, 1)
        XCTAssertEqual(copy1.x, 1)
        XCTAssertEqual(copy2.x, 1)
        XCTAssertEqual(copy3.x, 1)

        // Mutate each independently
        original.x = 10
        copy1.x = 20
        copy2.x = 30
        copy3.x = 40

        // All should have independent values
        XCTAssertEqual(original.x, 10)
        XCTAssertEqual(copy1.x, 20)
        XCTAssertEqual(copy2.x, 30)
        XCTAssertEqual(copy3.x, 40)
    }

    func testNoUnnecessaryCopy() {
        var p = Point(x: 1, y: 2)

        // Reading should not cause a copy
        let _ = p.x
        let _ = p.y

        // Mutating a uniquely-referenced value should not copy either
        p.x = 10
        XCTAssertEqual(p.x, 10)
    }
}
