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

Simply annotate your struct with `@CoW`:

```swift
import CopyOnWrite

@CoW
public struct Context {
    public var layoutBox: Rectangle
    public var style: Style
    internal var counter: Int = 0
}
```

The macro transforms your struct to use Copy-on-Write semantics automatically.

## What It Generates

The `@CoW` macro expands your struct to include:

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
