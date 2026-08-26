// swift-tools-version: 6.0
import PackageDescription

// Language mode v5: AX/CG C APIs are not Sendable-annotated; strict Swift 6
// concurrency checking would force unsafe casts everywhere. Revisit later.
let swiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "ancre",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
    ],
    targets: [
        .target(name: "WMCore", swiftSettings: swiftSettings),
        .executableTarget(name: "ancrectl", swiftSettings: swiftSettings),
        .target(name: "LayoutEngine", dependencies: ["WMCore"], swiftSettings: swiftSettings),
        .target(name: "AXBridge", dependencies: ["WMCore"], swiftSettings: swiftSettings),
        .target(name: "InputSystem", dependencies: ["WMCore"], swiftSettings: swiftSettings),
        .target(
            name: "Config",
            dependencies: ["WMCore", .product(name: "TOMLKit", package: "TOMLKit")],
            resources: [.copy("default.toml")],
            swiftSettings: swiftSettings
        ),
        .target(name: "Animator", dependencies: ["WMCore", "AXBridge"], swiftSettings: swiftSettings),
        .target(name: "Bar", dependencies: ["WMCore"], swiftSettings: swiftSettings),
        .executableTarget(
            name: "ancre",
            dependencies: ["WMCore", "LayoutEngine", "AXBridge", "InputSystem", "Config", "Animator", "Bar"],
            path: "App",
            swiftSettings: swiftSettings
        ),
        .testTarget(name: "WMCoreTests", dependencies: ["WMCore", "LayoutEngine"]),
        .testTarget(name: "LayoutEngineTests", dependencies: ["LayoutEngine", "WMCore"]),
        .testTarget(name: "ConfigTests", dependencies: ["Config", "TOMLKit"]),
    ]
)
