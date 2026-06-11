public struct PropVariantGenome: Equatable, Hashable, Codable, Sendable {
    public let stableID: StableID
    public let seed: UInt64
    public let age: Float
    public let widthBias: Float
    public let heightBias: Float
    public let materialJitter: Float

    public init(
        stableID: StableID,
        seed: UInt64,
        age: Float,
        widthBias: Float,
        heightBias: Float,
        materialJitter: Float
    ) {
        self.stableID = stableID
        self.seed = seed
        self.age = Self.clamped01(age)
        self.widthBias = Self.clampedSigned(widthBias)
        self.heightBias = Self.clampedSigned(heightBias)
        self.materialJitter = Self.clamped01(materialJitter)
    }

    public static func make(
        stableID: StableID,
        worldSeed: WorldSeed,
        coordinate: ChunkCoordinate,
        placement: PropPlacement
    ) -> PropVariantGenome {
        let seed = StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.props)
            builder.combine(coordinate)
            builder.combine(placement.placementIndex)
            builder.combine(placement.type.rawValue)
            builder.combine(stableID.rawValue)
        }.value
        var random = StableRNG(seedValue: seed)

        return PropVariantGenome(
            stableID: stableID,
            seed: seed,
            age: random.nextUnitFloat(),
            widthBias: random.nextUnitFloat() * 2 - 1,
            heightBias: random.nextUnitFloat() * 2 - 1,
            materialJitter: random.nextUnitFloat()
        )
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private static func clampedSigned(_ value: Float) -> Float {
        min(max(value, -1), 1)
    }
}
