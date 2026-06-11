import simd

public struct TerrainFieldSample: Equatable, Hashable, Codable, Sendable {
    public let height: Float
    public let normal: SIMD3<Float>
    public let slope: Float
    public let curvature: Float
    public let roughness: Float
    public let moisture: Float
    public let temperature: Float
    public let materialWeights: MaterialWeights
    public let waterDepth: Float
    public let featureMasks: TerrainFeatureMasks
    public let walkability: Float
    public let climbability: Float
}

public protocol TerrainFieldProvider: Sendable {
    func heightAt(worldX: Int, worldZ: Int, verticalChunk: Int) -> Float
    func sampleAt(worldX: Int, worldZ: Int, verticalChunk: Int) -> TerrainFieldSample
}

public struct DefaultTerrainFieldProvider: TerrainFieldProvider {
    public let seed: WorldSeed

    private let heightFunction: TerrainHeightFunction
    private let biomeSampler: BiomeSampler
    private let featureGraph: TerrainFeatureGraph

    public init(seed: WorldSeed) {
        self.seed = seed
        self.heightFunction = TerrainHeightFunction(seed: seed)
        self.biomeSampler = BiomeSampler(seed: seed)
        self.featureGraph = TerrainFeatureGraph.make(seed: seed)
    }

    public func heightAt(
        worldX: Int,
        worldZ: Int,
        verticalChunk: Int = 0
    ) -> Float {
        shapedHeightAt(worldX: worldX, worldZ: worldZ, verticalChunk: verticalChunk).height
    }

    public func sampleAt(
        worldX: Int,
        worldZ: Int,
        verticalChunk: Int = 0
    ) -> TerrainFieldSample {
        let shapedHeight = shapedHeightAt(worldX: worldX, worldZ: worldZ, verticalChunk: verticalChunk)
        let height = shapedHeight.height
        let left = heightAt(worldX: worldX - 1, worldZ: worldZ, verticalChunk: verticalChunk)
        let right = heightAt(worldX: worldX + 1, worldZ: worldZ, verticalChunk: verticalChunk)
        let back = heightAt(worldX: worldX, worldZ: worldZ - 1, verticalChunk: verticalChunk)
        let forward = heightAt(worldX: worldX, worldZ: worldZ + 1, verticalChunk: verticalChunk)
        let xGradient = (right - left) * 0.5
        let zGradient = (forward - back) * 0.5
        let slope = (xGradient * xGradient + zGradient * zGradient).squareRoot()
        let curvature = abs(left + right + back + forward - height * 4) * 0.25
        let roughness = clamped01((abs(left - height) + abs(right - height) + abs(back - height) + abs(forward - height)) * 0.125)
        let climate = biomeSampler.climate(at: WorldPosition(
            x: Float(worldX),
            y: height,
            z: Float(worldZ)
        ))
        let featureMasks = shapedHeight.contribution.masks
        let moisture = clamped01(
            normalizedClimateValue(climate.moisture) +
                featureMasks.water * 0.42 +
                featureMasks.shore * 0.24
        )
        let temperature = normalizedClimateValue(climate.temperature)
        let materialWeights = materialWeights(
            worldX: worldX,
            worldZ: worldZ,
            height: height,
            slope: slope,
            moisture: moisture,
            temperature: temperature,
            featureMasks: featureMasks
        )
        let baseWalkability = 1 - smoothStep(edge0: 0.45, edge1: 1.15, slope)
        let baseClimbability = smoothStep(edge0: 0.85, edge1: 1.8, slope) *
            (1 - smoothStep(edge0: 3.2, edge1: 5.0, slope))
        let waterPenalty = featureMasks.water * 0.85
        let cliffClimbBonus = featureMasks.cliff * 0.35

        return TerrainFieldSample(
            height: height,
            normal: normalized(SIMD3<Float>(-xGradient, 1, -zGradient)),
            slope: slope,
            curvature: curvature,
            roughness: roughness,
            moisture: moisture,
            temperature: temperature,
            materialWeights: materialWeights,
            waterDepth: shapedHeight.contribution.waterDepth,
            featureMasks: featureMasks,
            walkability: clamped01(baseWalkability * (1 - waterPenalty)),
            climbability: clamped01((baseClimbability + cliffClimbBonus) * (1 - featureMasks.water))
        )
    }

    public func featureGraphSnapshot() -> TerrainFeatureGraph {
        featureGraph
    }

    private func shapedHeightAt(
        worldX: Int,
        worldZ: Int,
        verticalChunk: Int
    ) -> (height: Float, contribution: TerrainFeatureContribution) {
        let baseHeight = heightFunction.heightAt(
            worldX: worldX,
            worldZ: worldZ,
            verticalChunk: verticalChunk
        )
        let contribution = featureGraph.contribution(at: TerrainFeaturePoint(
            worldX: Float(worldX),
            worldZ: Float(worldZ),
            baseHeight: baseHeight
        ))

        return (baseHeight + contribution.heightOffset, contribution)
    }

    private func materialWeights(
        worldX: Int,
        worldZ: Int,
        height: Float,
        slope: Float,
        moisture: Float,
        temperature: Float,
        featureMasks: TerrainFeatureMasks
    ) -> MaterialWeights {
        let position = WorldPosition(x: Float(worldX), y: height, z: Float(worldZ))
        let primaryBiome = biomeSampler.biome(at: position)
        let baseSplat = biomeSampler.terrainMaterialSplat(at: position)
        let rockWeight = min(
            smoothStep(edge0: 0.18, edge1: 0.55, slope) * 0.55 +
                featureMasks.mountain * 0.24 +
                featureMasks.cliff * 0.55,
            0.82
        )
        let snowWeight = smoothStep(edge0: 4.8, edge1: 6.8, height) *
            (1 - smoothStep(edge0: 0.55, edge1: 0.85, temperature)) * 0.50
        let wetWeight = smoothStep(edge0: 0.68, edge1: 0.92, moisture) *
            (1 - smoothStep(edge0: 1.5, edge1: 4.5, abs(height))) * 0.32
        let shoreWeight = featureMasks.shore * 0.46
        let waterMudWeight = featureMasks.water * 0.62
        let derivedWeight = min(rockWeight + snowWeight + wetWeight + shoreWeight + waterMudWeight, 0.82)
        let baseWeight = max(1 - derivedWeight, 0.18)
        var layers = baseSplat.layers.map { layer in
            layer.withWeight(layer.weight * baseWeight)
        }

        appendDerivedLayer(
            kind: .rock,
            weight: rockWeight,
            biome: primaryBiome,
            layers: &layers
        )
        appendDerivedLayer(
            kind: .snow,
            weight: snowWeight,
            biome: primaryBiome,
            layers: &layers
        )
        appendDerivedLayer(
            kind: .mud,
            weight: wetWeight,
            biome: primaryBiome,
            layers: &layers
        )
        appendDerivedLayer(
            kind: .sand,
            weight: shoreWeight,
            biome: primaryBiome,
            layers: &layers
        )
        appendDerivedLayer(
            kind: .mud,
            weight: waterMudWeight,
            biome: primaryBiome,
            layers: &layers
        )

        return MaterialWeights(
            primaryBiome: primaryBiome,
            splat: TerrainMaterialSplat(layers: layers)
        )
    }

    private func appendDerivedLayer(
        kind: TerrainMaterialKind,
        weight: Float,
        biome: Biome,
        layers: inout [TerrainMaterialSplatLayer]
    ) {
        guard weight > 0.0001 else {
            return
        }

        let descriptor = TerrainMaterialDescriptor.definition(for: kind)
        layers.append(TerrainMaterialSplatLayer(
            biomeType: biome.type,
            materialKind: descriptor.kind,
            materialIdentifier: descriptor.identifier,
            baseColor: descriptor.baseColor,
            roughness: descriptor.roughness,
            weight: weight
        ))
    }

    private func normalizedClimateValue(_ value: Float) -> Float {
        clamped01(value * 0.5 + 0.5)
    }

    private func normalized(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)

        guard length > 0.0001 else {
            return SIMD3<Float>(0, 1, 0)
        }

        return vector / length
    }

    private func smoothStep(edge0: Float, edge1: Float, _ value: Float) -> Float {
        guard edge0 != edge1 else {
            return value < edge0 ? 0 : 1
        }

        let amount = clamped01((value - edge0) / (edge1 - edge0))
        return amount * amount * (3 - 2 * amount)
    }

    private func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
