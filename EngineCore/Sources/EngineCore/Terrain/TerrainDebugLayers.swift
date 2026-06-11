public enum TerrainDebugLayer: String, CaseIterable, Codable, Sendable {
    case altitude
    case slope
    case curvature
    case roughness
    case moisture
    case temperature
    case primaryMaterialWeight
    case walkability
    case climbability
}

public struct TerrainDebugLayers: Sendable {
    public let grid: TerrainSampleGrid

    public init(grid: TerrainSampleGrid) {
        self.grid = grid
    }

    public func value(
        for layer: TerrainDebugLayer,
        localX: Int,
        localZ: Int
    ) -> Float {
        value(for: layer, sample: grid.sample(localX: localX, localZ: localZ))
    }

    public func values(for layer: TerrainDebugLayer) -> [Float] {
        grid.samples.map { sample in
            value(for: layer, sample: sample)
        }
    }

    private func value(
        for layer: TerrainDebugLayer,
        sample: TerrainSample
    ) -> Float {
        switch layer {
        case .altitude:
            return sample.height
        case .slope:
            return sample.slope
        case .curvature:
            return sample.curvature
        case .roughness:
            return sample.roughness
        case .moisture:
            return sample.moisture
        case .temperature:
            return sample.temperature
        case .primaryMaterialWeight:
            return sample.materialWeights.primaryLayer.weight
        case .walkability:
            return sample.walkability
        case .climbability:
            return sample.climbability
        }
    }
}
