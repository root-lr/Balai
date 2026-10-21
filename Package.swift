// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Balai",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Balai",
            path: "Sources/Balai"
        ),
        .testTarget(
            name: "BalaiTests",
            dependencies: ["Balai"],
            path: "Tests/BalaiTests"
        ),
    ]
)
