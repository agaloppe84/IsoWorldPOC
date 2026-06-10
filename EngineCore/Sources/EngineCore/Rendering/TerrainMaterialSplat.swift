public struct TerrainMaterialSplatLayer: Equatable, Hashable, Codable, Sendable {
    public let biomeType: BiomeType
    public let materialKind: TerrainMaterialKind
    public let materialIdentifier: String
    public let baseColor: BiomeColor
    public let roughness: Float
    public let renderMaterial: RenderMaterial
    public let weight: Float

    public var textureSlot: TerrainTextureSlot {
        renderMaterial.terrainTextureSlot ?? TerrainTextureSlot.slot(for: materialKind)
    }

    public var pbrTextureSlots: TerrainPBRTextureSlots {
        renderMaterial.terrainPBRTextureSlots ?? TerrainTextureSlot.pbrSlots(for: materialKind)
    }

    public init(
        biomeType: BiomeType,
        materialKind: TerrainMaterialKind,
        materialIdentifier: String,
        baseColor: BiomeColor,
        roughness: Float,
        weight: Float
    ) {
        self.biomeType = biomeType
        self.materialKind = materialKind
        self.materialIdentifier = materialIdentifier
        self.baseColor = baseColor
        self.roughness = roughness
        self.renderMaterial = RenderMaterial.terrain(
            kind: materialKind,
            identifier: materialIdentifier,
            baseColor: baseColor,
            roughness: roughness
        )
        self.weight = Self.clampedWeight(weight)
    }

    public init(biome: Biome, weight: Float) {
        self.init(
            biomeType: biome.type,
            materialKind: biome.terrainMaterial.kind,
            materialIdentifier: biome.terrainMaterial.identifier,
            baseColor: biome.terrainMaterial.baseColor,
            roughness: biome.terrainMaterial.roughness,
            weight: weight
        )
    }

    public func withWeight(_ weight: Float) -> TerrainMaterialSplatLayer {
        TerrainMaterialSplatLayer(
            biomeType: biomeType,
            materialKind: materialKind,
            materialIdentifier: materialIdentifier,
            baseColor: baseColor,
            roughness: roughness,
            weight: weight
        )
    }

    private static func clampedWeight(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct TerrainMaterialSplat: Equatable, Hashable, Codable, Sendable {
    public static let maxLayerCount = 4

    public let layers: [TerrainMaterialSplatLayer]

    public var primaryLayer: TerrainMaterialSplatLayer {
        layers[0]
    }

    public var secondaryLayer: TerrainMaterialSplatLayer? {
        layers.dropFirst().first
    }

    public var totalWeight: Float {
        layers.reduce(0) { $0 + $1.weight }
    }

    public var secondaryWeight: Float {
        max(0, 1 - primaryLayer.weight)
    }

    public var isNormalized: Bool {
        abs(totalWeight - 1) <= 0.0001
    }

    public init(layers: [TerrainMaterialSplatLayer]) {
        precondition(!layers.isEmpty, "TerrainMaterialSplat requires at least one layer.")
        self.layers = Self.normalizedTopLayers(layers)
    }

    public init(biome: Biome) {
        self.init(layers: [TerrainMaterialSplatLayer(biome: biome, weight: 1)])
    }

    private static func normalizedTopLayers(
        _ layers: [TerrainMaterialSplatLayer]
    ) -> [TerrainMaterialSplatLayer] {
        var mergedLayersByIdentifier: [String: TerrainMaterialSplatLayer] = [:]

        for layer in layers where layer.weight > 0 {
            if let existingLayer = mergedLayersByIdentifier[layer.materialIdentifier] {
                mergedLayersByIdentifier[layer.materialIdentifier] = existingLayer.withWeight(
                    existingLayer.weight + layer.weight
                )
            } else {
                mergedLayersByIdentifier[layer.materialIdentifier] = layer
            }
        }

        let sortedLayers = mergedLayersByIdentifier.values.sorted { lhs, rhs in
            if abs(lhs.weight - rhs.weight) <= 0.0001 {
                return lhs.materialIdentifier < rhs.materialIdentifier
            }

            return lhs.weight > rhs.weight
        }
        let topLayers = Array(sortedLayers.prefix(maxLayerCount))
        let totalWeight = topLayers.reduce(0) { $0 + $1.weight }

        guard totalWeight > 0 else {
            let fallback = layers[0]

            return [fallback.withWeight(1)]
        }

        return topLayers.map { layer in
            layer.withWeight(layer.weight / totalWeight)
        }
    }
}
