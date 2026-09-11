// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HerdPet",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HerdPetCore", path: "Sources/HerdPetCore"),
        .executableTarget(name: "herdpet", dependencies: ["HerdPetCore"], path: "Sources/App"),
        .testTarget(name: "HerdPetCoreTests", dependencies: ["HerdPetCore"], path: "Tests/HerdPetCoreTests"),
    ]
)
