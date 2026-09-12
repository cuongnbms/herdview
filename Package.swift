// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Herdview",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HerdviewCore", path: "Sources/HerdviewCore"),
        .executableTarget(name: "herdview", dependencies: ["HerdviewCore"], path: "Sources/App"),
        .testTarget(name: "HerdviewCoreTests", dependencies: ["HerdviewCore"], path: "Tests/HerdviewCoreTests"),
    ]
)
