public struct TerrainValidationReport: Equatable, Codable, Sendable {
    public enum Issue: String, Hashable, Codable, Sendable {
        case emptyGrid
        case invalidSample
        case materialWeightsNotNormalized
        case noWalkableSurface
    }

    public let minHeight: Float
    public let maxHeight: Float
    public let maxSlope: Float
    public let averageRoughness: Float
    public let walkableRatio: Float
    public let climbableRatio: Float
    public let materialCoverage: [String: Float]
    public let issues: [Issue]

    public var isValid: Bool {
        issues.isEmpty
    }

    public init(grid: TerrainSampleGrid) {
        guard !grid.samples.isEmpty else {
            self.minHeight = 0
            self.maxHeight = 0
            self.maxSlope = 0
            self.averageRoughness = 0
            self.walkableRatio = 0
            self.climbableRatio = 0
            self.materialCoverage = [:]
            self.issues = [.emptyGrid]
            return
        }

        var minHeight = Float.greatestFiniteMagnitude
        var maxHeight = -Float.greatestFiniteMagnitude
        var maxSlope: Float = 0
        var roughnessTotal: Float = 0
        var walkableCount = 0
        var climbableCount = 0
        var coverage: [String: Float] = [:]
        var issues: [Issue] = []

        for sample in grid.samples {
            if !Self.isFinite(sample) {
                issues.append(.invalidSample)
            }

            if !sample.materialWeights.isNormalized {
                issues.append(.materialWeightsNotNormalized)
            }

            minHeight = min(minHeight, sample.height)
            maxHeight = max(maxHeight, sample.height)
            maxSlope = max(maxSlope, sample.slope)
            roughnessTotal += sample.roughness

            if sample.walkability > 0.5 {
                walkableCount += 1
            }

            if sample.climbability > 0.5 {
                climbableCount += 1
            }

            for layer in sample.materialWeights.splat.layers {
                coverage[layer.materialIdentifier, default: 0] += layer.weight
            }
        }

        let sampleCount = Float(grid.samples.count)
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.maxSlope = maxSlope
        self.averageRoughness = roughnessTotal / sampleCount
        self.walkableRatio = Float(walkableCount) / sampleCount
        self.climbableRatio = Float(climbableCount) / sampleCount
        self.materialCoverage = coverage.mapValues { $0 / sampleCount }

        if walkableCount == 0 {
            issues.append(.noWalkableSurface)
        }

        self.issues = Array(Set(issues)).sorted { $0.rawValue < $1.rawValue }
    }

    private static func isFinite(_ sample: TerrainSample) -> Bool {
        sample.height.isFinite &&
            sample.normal.x.isFinite &&
            sample.normal.y.isFinite &&
            sample.normal.z.isFinite &&
            sample.slope.isFinite &&
            sample.curvature.isFinite &&
            sample.roughness.isFinite &&
            sample.moisture.isFinite &&
            sample.temperature.isFinite &&
            sample.walkability.isFinite &&
            sample.climbability.isFinite
    }
}
