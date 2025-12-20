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

And add `"Copy on Write"` to your target's dependencies.

## Usage

Annotate your struct with `@Copy on Write` (or the abbreviation `@CoW`):

```swift
import Copy_on_Write

@CoW
struct Context {
    var layoutBox: Rectangle
    var style: Style
    var counter: Int = 0
}
```

The macro transforms your struct to use Copy-on-Write semantics automatically.

> **Note:** `@Copy on Write` is the full name of the macro. `@CoW` is the commonly-used abbreviation. Both are functionally identical. Examples in this README use `@CoW` for brevity.

## What It Generates

The `@CoW` macro expands your struct to include:

1. **Private Storage class** - Holds all properties on the heap
2. **Computed properties** - Delegate to storage with CoW checks
3. **`ensureUnique()` method** - Copies storage if shared
4. **Memberwise initializer** - Preserves your default values

```swift
// Expanded form:
struct Context {
    // MARK: - CoW Generated Storage
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

    var layoutBox: Rectangle {
        get { storage.layoutBox }
        set { ensureUnique(); storage.layoutBox = newValue }
    }

    // ... other properties

    init(layoutBox: Rectangle, style: Style, counter: Int = 0) {
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
- **Protocol synthesis** - Automatically implements `Equatable`, `Hashable`, `Codable`, and `CustomStringConvertible` when declared
- **Storage identity checking** - `isIdentical(to:)` method to check if two values share storage

## Protocol Conformances

When your struct declares conformance to `Equatable`, `Hashable`, `Codable`, or `CustomStringConvertible`, the macro automatically generates the required implementations:

```swift
@CoW
struct Person: Hashable, Codable, CustomStringConvertible {
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

print(p1)          // Person(name: Alice, age: 30) (CustomStringConvertible)
```

## Checking Storage Identity

The `isIdentical(to:)` method lets you check if two values share the same underlying storage (useful for debugging or testing CoW behavior):

```swift
@CoW
struct Point {
    var x: Int
    var y: Int
}

var a = Point(x: 1, y: 2)
let b = a

a.isIdentical(to: b)  // true - same storage

a.x = 10              // triggers copy

a.isIdentical(to: b)  // false - different storage now
```

## Property Handling

### Stored Properties (`var`)

All `var` properties are transformed into computed properties that delegate to the internal Storage class:

```swift
@CoW
struct Example {
    var value: Int      // Transformed to computed property
    var name: String    // Transformed to computed property
}
```

### Read-Only Properties (`let`)

`let` properties are transformed into read-only computed properties:

```swift
@CoW
struct Example {
    let id: String      // Read-only (getter only)
    var value: Int      // Read-write (getter + setter)
}
```

> **Recommendation:** Use `private(set) var` instead of `let` for better clarity:
> ```swift
> @CoW
> struct Example {
>     private(set) var id: String  // Clearer intent, same behavior
>     var value: Int
> }
> ```

### Computed Properties

Existing computed properties in your struct are preserved as-is and not transformed:

```swift
@CoW
struct Rectangle {
    var width: Int
    var height: Int

    // This computed property is preserved, not transformed
    var area: Int {
        width * height
    }
}
```

### Static Properties

Static properties are filtered out and remain on the struct itself (not moved to Storage):

```swift
@CoW
struct Config {
    static let defaultTimeout = 30  // Remains as static property
    var timeout: Int                // Transformed to CoW property
}
```

## Thread Safety

The generated `Storage` class is marked `@unchecked Sendable`. This means:

1. **You are responsible** for ensuring all stored property types are safe for concurrent access
2. **Use thread-safe types** - Prefer value types (`Int`, `String`, `Array`, etc.) or explicitly `Sendable` types
3. **The CoW mechanism itself is not atomic** - If you need concurrent mutation, use external synchronization

```swift
@CoW
struct SafeConfig {
    var count: Int         // Safe - Int is Sendable
    var name: String       // Safe - String is Sendable
    var items: [String]    // Safe - Array of Sendable is Sendable
}

// Be careful with reference types:
@CoW
struct UnsafeConfig {
    var handler: SomeClass  // Only safe if SomeClass is Sendable
}
```

## Limitations

- **Generic structs** are not currently supported
- **Property wrappers** (`@State`, `@Published`, etc.) are not supported
- **Lazy properties** are not supported

## Requirements

- Swift 5.10+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+

## License

MIT
