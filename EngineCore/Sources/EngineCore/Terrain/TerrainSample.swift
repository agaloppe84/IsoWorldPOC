import simd

public struct MaterialWeights: Equatable, Hashable, Codable, Sendable {
    public let primaryBiomeType: BiomeType
    public let splat: TerrainMaterialSplat

    public var primaryBiome: Biome {
        Biome.definition(for: primaryBiomeType)
    }

    public var primaryLayer: TerrainMaterialSplatLayer {
        splat.primaryLayer
    }

    public var totalWeight: Float {
        splat.totalWeight
    }

    public var isNormalized: Bool {
        splat.isNormalized
    }

    public init(primaryBiome: Biome, splat: TerrainMaterialSplat? = nil) {
        self.primaryBiomeType = primaryBiome.type
        self.splat = splat ?? TerrainMaterialSplat(biome: primaryBiome)
    }

    public init(primaryBiomeType: BiomeType, splat: TerrainMaterialSplat) {
        self.primaryBiomeType = primaryBiomeType
        self.splat = splat
    }

    public static var grassland: MaterialWeights {
        MaterialWeights(primaryBiome: Biome.definition(for: .grassland))
    }

    public func terrainVertexMaterial() -> TerrainVertexMaterial {
        TerrainVertexMaterial(primaryBiome: primaryBiome, splat: splat)
    }

    public func stableHash(into hasher: inout StableHash.Builder) {
        hasher.combine(primaryBiomeType.rawValue)
        hasher.combine(splat.layers.count)

        for layer in splat.layers {
            hasher.combine(layer.biomeType.rawValue)
            hasher.combine(layer.materialKind.rawValue)
            hasher.combine(layer.materialIdentifier)
            hasher.combine(layer.weight)
        }
    }
}

public struct TerrainSample: Equatable, Hashable, Codable, Sendable {
    public let localX: Int
    public let localZ: Int
    public let worldX: Int
    public let worldZ: Int
    public let height: Float
    public let normal: SIMD3<Float>
    public let slope: Float
    public let curvature: Float
    public let roughness: Float
    public let moisture: Float
    public let temperature: Float
    public let materialWeights: MaterialWeights
    public let walkability: Float
    public let climbability: Float

    public init(
        localX: Int,
        localZ: Int,
        worldX: Int,
        worldZ: Int,
        height: Float,
        normal: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        slope: Float = 0,
        curvature: Float = 0,
        roughness: Float = 0,
        moisture: Float = 0,
        temperature: Float = 0,
        materialWeights: MaterialWeights = .grassland,
        walkability: Float = 1,
        climbability: Float = 0
    ) {
        self.localX = localX
        self.localZ = localZ
        self.worldX = worldX
        self.worldZ = worldZ
        self.height = height
        self.normal = Self.normalized(normal)
        self.slope = max(slope, 0)
        self.curvature = max(curvature, 0)
        self.roughness = Self.clamped01(roughness)
        self.moisture = Self.clamped01(moisture)
        self.temperature = Self.clamped01(temperature)
        self.materialWeights = materialWeights
        self.walkability = Self.clamped01(walkability)
        self.climbability = Self.clamped01(climbability)
    }

    public func stableHash(into hasher: inout StableHash.Builder) {
        hasher.combine(localX)
        hasher.combine(localZ)
        hasher.combine(worldX)
        hasher.combine(worldZ)
        hasher.combine(height)
        hasher.combine(normal.x)
        hasher.combine(normal.y)
        hasher.combine(normal.z)
        hasher.combine(slope)
        hasher.combine(curvature)
        hasher.combine(roughness)
        hasher.combine(moisture)
        hasher.combine(temperature)
        materialWeights.stableHash(into: &hasher)
        hasher.combine(walkability)
        hasher.combine(climbability)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return SIMD3<Float>(0, 1, 0)
        }

        return vector / length
    }
}
