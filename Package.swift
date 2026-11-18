// swift-tools-version: 6.0
import PackageDescription

// The one Swift package of this repository (.claude/rules/swift-is-the-implementation-language.md).
// New mechanical checks go into PropositionsKit; skills call the `propositions` executable.
let package = Package(
    name: "Propositions",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PropositionsKit", targets: ["PropositionsKit"]),
        .executable(name: "propositions", targets: ["propositions"]),
        .executable(name: "tschema-check", targets: ["tschema-check"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(name: "PropositionsKit"),
        .executableTarget(name: "propositions", dependencies: [
            "PropositionsKit",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .executableTarget(name: "tschema-check", dependencies: ["PropositionsKit"]),
        // The path is spelled out: the repository already has a lower-case `tests/` (pytest), and
        // SwiftPM's default `Tests/` is another directory on a case-sensitive file system.
        .testTarget(name: "PropositionsKitTests", dependencies: ["PropositionsKit"],
                    path: "tests/PropositionsKitTests"),
    ]
)
