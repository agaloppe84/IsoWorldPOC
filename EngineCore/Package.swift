// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EngineCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "EngineCore",
            targets: ["EngineCore"]
        )
    ],
    targets: [
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "EngineCore",
            dependencies: ["CSQLite"],
            path: "Sources/EngineCore"
        ),
        .testTarget(
            name: "EngineCoreTests",
            dependencies: ["EngineCore"]
        )
    ]
)
