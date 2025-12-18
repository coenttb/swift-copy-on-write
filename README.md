# swift-copy-on-write

A Swift macro that automatically implements Copy-on-Write (CoW) semantics for structs.

## Overview

Copy-on-Write is a powerful optimization technique that provides value semantics with efficient copying. The underlying storage is only copied when a mutation occurs on a shared instance.

This is ideal for:
- Large structs that are frequently passed around but infrequently mutated
- Preventing stack overflow during deep recursive operations
- Maintaining value semantics while keeping stack frame size minimal (8 bytes)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-copy-on-write.git", from: "0.1.0")
]
```

And add `"CopyOnWrite"` to your target's dependencies.

## Usage

Simply annotate your struct with `@Copy on Write` (or the shorter alias `@CoW`):

```swift
import CopyOnWrite

@`Copy on Write`
public struct Context {
    public var layoutBox: Rectangle
    public var style: Style
    internal var counter: Int = 0
}

// Or using the shorter alias:
@CoW
public struct AnotherContext {
    public var value: Int
}
```

The macro transforms your struct to use Copy-on-Write semantics automatically.

## What It Generates

The `@Copy on Write` macro expands your struct to include:

1. **Private Storage class** - Holds all properties on the heap
2. **Computed properties** - Delegate to storage with CoW checks
3. **`ensureUnique()` method** - Copies storage if shared
4. **Memberwise initializer** - Preserves your default values

```swift
// Expanded form:
public struct Context {
    private final class Storage: @unchecked Sendable {
        var layoutBox: Rectangle
        var style: Style
        var counter: Int

        init(layoutBox: Rectangle, style: Style, counter: Int = 0) { ... }
        init(copying other: Storage) { ... }
    }

    private var storage: Storage

    private mutating func ensureUnique() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(copying: storage)
        }
    }

    public var layoutBox: Rectangle {
        get { storage.layoutBox }
        set { ensureUnique(); storage.layoutBox = newValue }
    }

    // ... other properties

    public init(layoutBox: Rectangle, style: Style, counter: Int = 0) {
        self.storage = Storage(layoutBox: layoutBox, style: style, counter: counter)
    }
}
```

## Features

- **Preserves access control** - `public`, `internal`, `private` properties maintain their visibility
- **Handles default values** - Default values are preserved in the generated initializer
- **Supports `private(set) var`** - Use `private(set) var` for read-only properties with CoW
- **Sendable by default** - Generated Storage is `@unchecked Sendable`
- **Minimal stack footprint** - Only 8 bytes on the stack (single reference)
- **Protocol synthesis** - Automatically implements `Equatable`, `Hashable`, and `Codable` when declared
- **Storage identity checking** - `isIdentical(to:)` method to check if two values share storage

## Protocol Conformances

When your struct declares conformance to `Equatable`, `Hashable`, or `Codable`, the macro automatically generates the required implementations:

```swift
@CoW
struct Person: Hashable, Codable {
    var name: String
    var age: Int
}

// Now you can:
let p1 = Person(name: "Alice", age: 30)
let p2 = Person(name: "Alice", age: 30)

p1 == p2           // true (Equatable)
p1.hashValue       // works (Hashable)

let data = try JSONEncoder().encode(p1)  // works (Encodable)
let decoded = try JSONDecoder().decode(Person.self, from: data)  // works (Decodable)
```

## Checking Storage Identity

The `isIdentical(to:)` method lets you check if two values share the same underlying storage (useful for debugging or testing CoW behavior):

```swift
var a = Point(x: 1, y: 2)
let b = a

a.isIdentical(to: b)  // true - same storage

a.x = 10              // triggers copy

a.isIdentical(to: b)  // false - different storage now
```

## Limitations

- **`let` properties are not supported** - Use `private(set) var` instead of `let` for immutable properties:

```swift
// ❌ Don't do this
@CoW
struct Bad {
    let id: String  // Won't work
}

// ✅ Do this instead
@CoW
struct Good {
    private(set) var id: String  // Works with CoW
}
```

## Requirements

- Swift 5.10+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+

## License

MIT
