// swift-tools-version: 5.10

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-copy-on-write",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "CopyOnWrite",
            targets: ["CopyOnWrite"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        // Public API - the @CoW macro declaration
        .target(
            name: "CopyOnWrite",
            dependencies: ["CopyOnWriteMacros"]
        ),

        // Macro implementation - compiler plugin
        .macro(
            name: "CopyOnWriteMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // Tests
        .testTarget(
            name: "CopyOnWriteTests",
            dependencies: [
                "CopyOnWrite",
                "CopyOnWriteMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
