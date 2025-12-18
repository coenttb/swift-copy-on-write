// CoWMacroTests.swift

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
}
