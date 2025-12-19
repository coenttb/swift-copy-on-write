// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-copy-on-write",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "CopyOnWrite",
            targets: ["CopyOnWrite"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0"),
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
