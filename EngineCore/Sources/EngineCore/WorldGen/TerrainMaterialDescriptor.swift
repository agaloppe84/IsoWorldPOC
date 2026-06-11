public enum TerrainMaterialKind: String, CaseIterable, Codable, Sendable {
    case grass
    case rock
    case dirt
    case sand
    case mud
    case snow
}

public struct TerrainMaterialDescriptor: Equatable, Hashable, Codable, Sendable {
    public let kind: TerrainMaterialKind
    public let identifier: String
    public let baseColor: BiomeColor
    public let roughness: Float

    public init(
        kind: TerrainMaterialKind,
        identifier: String,
        baseColor: BiomeColor,
        roughness: Float
    ) {
        self.kind = kind
        self.identifier = identifier
        self.baseColor = baseColor
        self.roughness = roughness
    }

    public static func definition(for kind: TerrainMaterialKind) -> TerrainMaterialDescriptor {
        switch kind {
        case .grass:
            TerrainMaterialDescriptor(
                kind: .grass,
                identifier: "terrain.material.grass",
                baseColor: BiomeColor(red: 0.34, green: 0.62, blue: 0.24),
                roughness: 0.82
            )
        case .rock:
            TerrainMaterialDescriptor(
                kind: .rock,
                identifier: "terrain.material.rock",
                baseColor: BiomeColor(red: 0.44, green: 0.44, blue: 0.40),
                roughness: 0.90
            )
        case .dirt:
            TerrainMaterialDescriptor(
                kind: .dirt,
                identifier: "terrain.material.dirt",
                baseColor: BiomeColor(red: 0.38, green: 0.28, blue: 0.16),
                roughness: 0.88
            )
        case .sand:
            TerrainMaterialDescriptor(
                kind: .sand,
                identifier: "terrain.material.sand",
                baseColor: BiomeColor(red: 0.64, green: 0.52, blue: 0.28),
                roughness: 0.84
            )
        case .mud:
            TerrainMaterialDescriptor(
                kind: .mud,
                identifier: "terrain.material.mud",
                baseColor: BiomeColor(red: 0.18, green: 0.42, blue: 0.32),
                roughness: 0.96
            )
        case .snow:
            TerrainMaterialDescriptor(
                kind: .snow,
                identifier: "terrain.material.snow",
                baseColor: BiomeColor(red: 0.88, green: 0.92, blue: 0.90),
                roughness: 0.72
            )
        }
    }
}
