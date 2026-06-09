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
            name: "EngineCore",
            path: "Sources/EngineCore",
            sources: [
                "ChunkCoordinate.swift",
                "SeededRandom.swift",
                "WorldSeed.swift",
                "Terrain/TerrainMesh.swift",
                "Terrain/TerrainMeshBuilder.swift",
                "WorldGen/ChunkGenerator.swift",
                "WorldGen/ChunkHeightmap.swift",
                "WorldGen/TerrainSample.swift",
            ]
        ),
        .testTarget(
            name: "EngineCoreTests",
            dependencies: ["EngineCore"]
        )
    ]
)
