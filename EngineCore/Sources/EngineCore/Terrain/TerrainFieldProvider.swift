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

    public init(seed: WorldSeed) {
        self.seed = seed
        self.heightFunction = TerrainHeightFunction(seed: seed)
        self.biomeSampler = BiomeSampler(seed: seed)
    }

    public func heightAt(
        worldX: Int,
        worldZ: Int,
        verticalChunk: Int = 0
    ) -> Float {
        heightFunction.heightAt(worldX: worldX, worldZ: worldZ, verticalChunk: verticalChunk)
    }

    public func sampleAt(
        worldX: Int,
        worldZ: Int,
        verticalChunk: Int = 0
    ) -> TerrainFieldSample {
        let height = heightAt(worldX: worldX, worldZ: worldZ, verticalChunk: verticalChunk)
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
        let moisture = normalizedClimateValue(climate.moisture)
        let temperature = normalizedClimateValue(climate.temperature)
        let materialWeights = materialWeights(
            worldX: worldX,
            worldZ: worldZ,
            height: height,
            slope: slope,
            moisture: moisture,
            temperature: temperature
        )

        return TerrainFieldSample(
            height: height,
            normal: normalized(SIMD3<Float>(-xGradient, 1, -zGradient)),
            slope: slope,
            curvature: curvature,
            roughness: roughness,
            moisture: moisture,
            temperature: temperature,
            materialWeights: materialWeights,
            walkability: 1 - smoothStep(edge0: 0.45, edge1: 1.15, slope),
            climbability: smoothStep(edge0: 0.85, edge1: 1.8, slope) *
                (1 - smoothStep(edge0: 3.2, edge1: 5.0, slope))
        )
    }

    private func materialWeights(
        worldX: Int,
        worldZ: Int,
        height: Float,
        slope: Float,
        moisture: Float,
        temperature: Float
    ) -> MaterialWeights {
        let position = WorldPosition(x: Float(worldX), y: height, z: Float(worldZ))
        let primaryBiome = biomeSampler.biome(at: position)
        let baseSplat = biomeSampler.terrainMaterialSplat(at: position)
        let rockWeight = smoothStep(edge0: 0.18, edge1: 0.55, slope) * 0.55
        let snowWeight = smoothStep(edge0: 4.8, edge1: 6.8, height) *
            (1 - smoothStep(edge0: 0.55, edge1: 0.85, temperature)) * 0.50
        let wetWeight = smoothStep(edge0: 0.68, edge1: 0.92, moisture) *
            (1 - smoothStep(edge0: 1.5, edge1: 4.5, abs(height))) * 0.32
        let derivedWeight = min(rockWeight + snowWeight + wetWeight, 0.70)
        let baseWeight = max(1 - derivedWeight, 0.30)
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
            kind: .wetValley,
            weight: wetWeight,
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
