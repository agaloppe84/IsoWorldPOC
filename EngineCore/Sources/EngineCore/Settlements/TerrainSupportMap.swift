public enum TerrainSupportSolution: String, CaseIterable, Codable, Sendable {
    case flatFoundation
    case steppedFoundation
    case terrace
    case stilts
    case retainingWalls
    case rockAnchors
}

public enum SettlementSlopeClass: String, Codable, Sendable {
    case flat
    case gentle
    case moderate
    case steep
    case unbuildable
}

public struct TerrainSupportSample: Equatable, Hashable, Codable, Sendable {
    public let localX: Int
    public let localZ: Int
    public let worldX: Int
    public let worldZ: Int
    public let height: Float
    public let slope: Float
    public let roughness: Float
    public let moisture: Float
    public let waterDepth: Float
    public let walkability: Float
    public let biomeType: BiomeType
    public let slopeClass: SettlementSlopeClass
    public let supportSolution: TerrainSupportSolution
    public let buildableScore: Float

    public init(sample: TerrainSample) {
        localX = sample.localX
        localZ = sample.localZ
        worldX = sample.worldX
        worldZ = sample.worldZ
        height = sample.height
        slope = sample.slope
        roughness = sample.roughness
        moisture = sample.moisture
        waterDepth = sample.waterDepth
        walkability = sample.walkability
        biomeType = sample.materialWeights.primaryBiomeType
        slopeClass = Self.slopeClass(for: sample.slope, waterDepth: sample.waterDepth)
        supportSolution = Self.supportSolution(for: sample)
        buildableScore = Self.buildableScore(for: sample)
    }

    public var isBuildable: Bool {
        buildableScore >= 0.42
    }

    private static func slopeClass(for slope: Float, waterDepth: Float) -> SettlementSlopeClass {
        if waterDepth > 0.70 || slope > 0.62 {
            return .unbuildable
        }

        if slope <= 0.08 {
            return .flat
        }

        if slope <= 0.18 {
            return .gentle
        }

        if slope <= 0.34 {
            return .moderate
        }

        return .steep
    }

    private static func supportSolution(for sample: TerrainSample) -> TerrainSupportSolution {
        if sample.waterDepth > 0.06 || sample.featureMasks.water > 0.25 {
            return .stilts
        }

        if sample.featureMasks.cliff > 0.45 || sample.climbability > 0.55 {
            return .rockAnchors
        }

        if sample.slope <= 0.08 {
            return .flatFoundation
        }

        if sample.slope <= 0.24 {
            return .steppedFoundation
        }

        if sample.slope <= 0.40 {
            return .retainingWalls
        }

        return .terrace
    }

    private static func buildableScore(for sample: TerrainSample) -> Float {
        let slopeScore = 1 - min(sample.slope / 0.62, 1)
        let roughnessScore = 1 - sample.roughness
        let waterPenalty = min(sample.waterDepth * 1.25 + sample.featureMasks.water * 0.35, 0.65)
        let cliffPenalty = min(sample.featureMasks.cliff * 0.45, 0.45)
        let score = sample.walkability * 0.44 +
            slopeScore * 0.30 +
            roughnessScore * 0.16 +
            sample.moisture * 0.05 -
            waterPenalty -
            cliffPenalty

        return clamped01(score)
    }
}

public struct TerrainSupportMap: Equatable, Codable, Sendable {
    public let seed: WorldSeed
    public let coordinate: ChunkCoordinate
    public let resolution: Int
    public let samples: [TerrainSupportSample]
    public let averageSlope: Float
    public let averageRoughness: Float
    public let buildableRatio: Float
    public let waterAccessScore: Float
    public let dominantBiomeType: BiomeType

    public init(grid: TerrainSampleGrid) {
        let supportSamples = grid.samples.map(TerrainSupportSample.init(sample:))
        let sampleCount = Float(max(supportSamples.count, 1))
        let buildableCount = Float(supportSamples.filter(\.isBuildable).count)
        var biomeCounts: [BiomeType: Int] = [:]

        for sample in supportSamples {
            biomeCounts[sample.biomeType, default: 0] += 1
        }

        seed = grid.seed
        coordinate = grid.coordinate
        resolution = grid.resolution
        samples = supportSamples
        averageSlope = supportSamples.reduce(Float(0)) { $0 + $1.slope } / sampleCount
        averageRoughness = supportSamples.reduce(Float(0)) { $0 + $1.roughness } / sampleCount
        buildableRatio = buildableCount / sampleCount
        waterAccessScore = Self.waterAccessScore(samples: supportSamples)
        dominantBiomeType = biomeCounts.max { lhs, rhs in
            lhs.value < rhs.value
        }?.key ?? .grassland
    }

    public subscript(localX: Int, localZ: Int) -> TerrainSupportSample {
        sample(localX: localX, localZ: localZ)
    }

    public func sample(localX: Int, localZ: Int) -> TerrainSupportSample {
        let x = clamped(localX, lowerBound: 0, upperBound: resolution - 1)
        let z = clamped(localZ, lowerBound: 0, upperBound: resolution - 1)
        return samples[z * resolution + x]
    }

    public func nearestSample(localX: Float, localZ: Float) -> TerrainSupportSample {
        sample(
            localX: Int(localX.rounded()),
            localZ: Int(localZ.rounded())
        )
    }

    public func supportSamples(
        centerLocalX: Float,
        centerLocalZ: Float,
        width: Float,
        depth: Float
    ) -> [TerrainSupportSample] {
        let halfWidth = max(width * 0.5, 0.5)
        let halfDepth = max(depth * 0.5, 0.5)

        return [
            nearestSample(localX: centerLocalX - halfWidth, localZ: centerLocalZ - halfDepth),
            nearestSample(localX: centerLocalX + halfWidth, localZ: centerLocalZ - halfDepth),
            nearestSample(localX: centerLocalX + halfWidth, localZ: centerLocalZ + halfDepth),
            nearestSample(localX: centerLocalX - halfWidth, localZ: centerLocalZ + halfDepth),
            nearestSample(localX: centerLocalX, localZ: centerLocalZ),
        ]
    }

    public func bestBuildableSamples(limit: Int, minimumSpacing: Int = 6) -> [TerrainSupportSample] {
        precondition(limit >= 0, "limit must be non-negative.")
        precondition(minimumSpacing >= 0, "minimumSpacing must be non-negative.")

        var result: [TerrainSupportSample] = []
        let sorted = samples
            .filter(\.isBuildable)
            .sorted { lhs, rhs in
                if lhs.buildableScore != rhs.buildableScore {
                    return lhs.buildableScore > rhs.buildableScore
                }

                if lhs.localZ != rhs.localZ {
                    return lhs.localZ < rhs.localZ
                }

                return lhs.localX < rhs.localX
            }

        for sample in sorted where result.count < limit {
            let farEnough = result.allSatisfy { accepted in
                abs(accepted.localX - sample.localX) >= minimumSpacing ||
                    abs(accepted.localZ - sample.localZ) >= minimumSpacing
            }

            if farEnough {
                result.append(sample)
            }
        }

        return result
    }

    private static func waterAccessScore(samples: [TerrainSupportSample]) -> Float {
        guard !samples.isEmpty else {
            return 0
        }

        let wetSamples = samples.filter { sample in
            sample.waterDepth > 0 ||
                sample.moisture > 0.62 ||
                sample.biomeType == .freshwater ||
                sample.biomeType == .coast ||
                sample.biomeType == .marsh
        }

        return clamped01(Float(wetSamples.count) / Float(samples.count))
    }
}

private func clamped01(_ value: Float) -> Float {
    min(max(value, 0), 1)
}

private func clamped(_ value: Int, lowerBound: Int, upperBound: Int) -> Int {
    min(max(value, lowerBound), upperBound)
}
