public typealias StableRNG = SeededRandom

public extension SeededRandom {
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
