// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexUsageNano",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexUsageNano", targets: ["CodexUsageNano"])
    ],
    targets: [
        .executableTarget(
            name: "CodexUsageNano"
        ),
        .testTarget(
            name: "CodexUsageNanoTests",
            dependencies: ["CodexUsageNano"]
        )
    ]
)
