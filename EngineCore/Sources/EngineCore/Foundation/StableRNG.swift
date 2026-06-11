public struct StableRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: WorldSeed) {
        state = seed.value
    }

    public init(seedValue: UInt64) {
        self.init(seed: WorldSeed(seedValue))
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15

        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

public extension StableRNG {
    init(
        seed: WorldSeed,
        domain: SeedDomain,
        coordinate: ChunkCoordinate? = nil,
        values: [UInt64] = []
    ) {
        self.init(seed: seed.derived(domain: domain, coordinate: coordinate, values: values))
    }

    mutating func nextUnitFloat() -> Float {
        let value = next() >> 40
        return Float(value) / Float(0x00ff_ffff)
    }

    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        precondition(range.lowerBound <= range.upperBound, "Range lowerBound must be <= upperBound.")
        return range.lowerBound + nextUnitFloat() * (range.upperBound - range.lowerBound)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        precondition(upperBound > 0, "upperBound must be positive.")
        return Int(next() % UInt64(upperBound))
    }

    mutating func nextBool(probability: Float = 0.5) -> Bool {
        precondition(probability >= 0 && probability <= 1, "probability must be between 0 and 1.")
        return nextUnitFloat() <= probability
    }
}
