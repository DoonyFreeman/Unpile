// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Unpile",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Unpile", targets: ["Unpile"]),
        .executable(name: "UnpileChecks", targets: ["UnpileChecks"])
    ],
    targets: [
        .target(name: "UnpileCore", resources: [.process("Resources")]),
        .target(name: "UnpileFilesystem", dependencies: ["UnpileCore"]),
        .executableTarget(name: "Unpile", dependencies: ["UnpileCore", "UnpileFilesystem"]),
        .executableTarget(name: "UnpileChecks", dependencies: ["UnpileCore", "UnpileFilesystem"], path: "Tests/UnpileCoreTests")
    ]
)
