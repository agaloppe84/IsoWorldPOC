// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EngineCore",
    products: [
        .library(
            name: "EngineCore",
            targets: ["EngineCore"]
        )
    ],
    targets: [
        .target(
            name: "EngineCore"
        ),
        .testTarget(
            name: "EngineCoreTests",
            dependencies: ["EngineCore"]
        )
    ]
)

