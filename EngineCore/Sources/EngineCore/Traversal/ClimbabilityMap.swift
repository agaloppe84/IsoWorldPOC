public struct ClimbabilityMap: Equatable, Codable, Sendable {
    public let seed: WorldSeed
    public let coordinate: ChunkCoordinate
    public let resolution: Int
    public let values: [Float]
    public let ledgeScores: [Float]
    public let surfaceClasses: [TraversalSurfaceClass]

    public init(
        seed: WorldSeed,
        coordinate: ChunkCoordinate,
        resolution: Int,
        values: [Float],
        ledgeScores: [Float],
        surfaceClasses: [TraversalSurfaceClass]
    ) {
        precondition(resolution > 1, "ClimbabilityMap requires at least two samples per axis.")
        precondition(values.count == resolution * resolution, "ClimbabilityMap values must match resolution.")
        precondition(ledgeScores.count == values.count, "ClimbabilityMap ledge scores must match values.")
        precondition(surfaceClasses.count == values.count, "ClimbabilityMap surface classes must match values.")

        self.seed = seed
        self.coordinate = coordinate
        self.resolution = resolution
        self.values = values.map(Self.clamped01)
        self.ledgeScores = ledgeScores.map(Self.clamped01)
        self.surfaceClasses = surfaceClasses
    }

    public init(sampleGrid: TerrainSampleGrid) {
        let surfaceClasses = sampleGrid.samples.map(TraversalSurfaceClass.classify)
        let ledgeScores = Self.makeLedgeScores(sampleGrid: sampleGrid, surfaceClasses: surfaceClasses)

        self.init(
            seed: sampleGrid.seed,
            coordinate: sampleGrid.coordinate,
            resolution: sampleGrid.resolution,
            values: sampleGrid.samples.map(\.climbability),
            ledgeScores: ledgeScores,
            surfaceClasses: surfaceClasses
        )
    }

    public func value(localX: Int, localZ: Int) -> Float {
        values[index(localX: localX, localZ: localZ)]
    }

    public func ledgeScore(localX: Int, localZ: Int) -> Float {
        ledgeScores[index(localX: localX, localZ: localZ)]
    }

    public func surfaceClass(localX: Int, localZ: Int) -> TraversalSurfaceClass {
        surfaceClasses[index(localX: localX, localZ: localZ)]
    }

    public func surfaceClass(nearestLocalX: Float, nearestLocalZ: Float) -> TraversalSurfaceClass {
        surfaceClass(
            localX: nearestIndex(nearestLocalX),
            localZ: nearestIndex(nearestLocalZ)
        )
    }

    public func ratio(of surfaceClass: TraversalSurfaceClass) -> Float {
        guard !surfaceClasses.isEmpty else {
            return 0
        }

        let count = surfaceClasses.filter { $0 == surfaceClass }.count
        return Float(count) / Float(surfaceClasses.count)
    }

    public var walkableRatio: Float {
        ratio(of: .walkable)
    }

    public var climbableRatio: Float {
        ratio(of: .climbable)
    }

    public var blockedRatio: Float {
        ratio(of: .blocked)
    }

    private static func makeLedgeScores(
        sampleGrid: TerrainSampleGrid,
        surfaceClasses: [TraversalSurfaceClass]
    ) -> [Float] {
        var scores = Array(repeating: Float(0), count: sampleGrid.samples.count)

        for localZ in 0..<sampleGrid.resolution {
            for localX in 0..<sampleGrid.resolution {
                let sample = sampleGrid[localX, localZ]
                let index = localZ * sampleGrid.resolution + localX
                let surfaceClass = surfaceClasses[index]
                let neighbors = neighborSamples(localX: localX, localZ: localZ, in: sampleGrid)
                let heightSpread = neighbors.reduce(Float(0)) { spread, neighbor in
                    max(spread, abs(neighbor.height - sample.height))
                }
                let hasWalkableNeighbor = neighbors.contains { neighbor in
                    TraversalSurfaceClass.classify(neighbor) == .walkable
                }
                let accessBonus: Float = hasWalkableNeighbor ? 0.16 : 0
                let surfaceBonus: Float = surfaceClass.supportsVerticalTraversal ? 0.22 : 0
                let score =
                    sample.featureMasks.cliff * 0.30 +
                    sample.climbability * 0.28 +
                    smoothStep(edge0: 0.16, edge1: 1.10, sample.curvature) * 0.18 +
                    smoothStep(edge0: 0.28, edge1: 1.65, heightSpread) * 0.16 +
                    surfaceBonus +
                    accessBonus

                scores[index] = clamped01(score)
            }
        }

        return scores
    }

    private static func neighborSamples(
        localX: Int,
        localZ: Int,
        in grid: TerrainSampleGrid
    ) -> [TerrainSample] {
        [
            (localX - 1, localZ),
            (localX + 1, localZ),
            (localX, localZ - 1),
            (localX, localZ + 1),
        ].compactMap { x, z in
            grid.contains(localX: x, localZ: z) ? grid[x, z] : nil
        }
    }

    private func index(localX: Int, localZ: Int) -> Int {
        precondition((0..<resolution).contains(localX), "ClimbabilityMap localX out of bounds.")
        precondition((0..<resolution).contains(localZ), "ClimbabilityMap localZ out of bounds.")

        return localZ * resolution + localX
    }

    private func nearestIndex(_ value: Float) -> Int {
        min(max(Int(value.rounded()), 0), resolution - 1)
    }

    private static func smoothStep(edge0: Float, edge1: Float, _ value: Float) -> Float {
        guard edge0 != edge1 else {
            return value < edge0 ? 0 : 1
        }

        let amount = clamped01((value - edge0) / (edge1 - edge0))
        return amount * amount * (3 - 2 * amount)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
