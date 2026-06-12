import Foundation

public struct FootprintVertex: Equatable, Hashable, Codable, Sendable {
    public let localX: Float
    public let localZ: Float
    public let worldX: Float
    public let worldZ: Float
    public let terrainHeight: Float

    public init(
        localX: Float,
        localZ: Float,
        worldX: Float,
        worldZ: Float,
        terrainHeight: Float
    ) {
        self.localX = localX
        self.localZ = localZ
        self.worldX = worldX
        self.worldZ = worldZ
        self.terrainHeight = terrainHeight
    }
}

public struct FoundationAdjustment: Equatable, Hashable, Codable, Sendable {
    public let vertexIndex: Int
    public let terrainHeight: Float
    public let targetHeight: Float
    public let verticalOffset: Float

    public init(
        vertexIndex: Int,
        terrainHeight: Float,
        targetHeight: Float
    ) {
        precondition(vertexIndex >= 0, "FoundationAdjustment vertexIndex must be non-negative.")

        self.vertexIndex = vertexIndex
        self.terrainHeight = terrainHeight
        self.targetHeight = targetHeight
        verticalOffset = targetHeight - terrainHeight
    }
}

public struct BuildingFootprint: Equatable, Codable, Sendable {
    public let id: StableID
    public let intentID: StableID
    public let structureRecipeID: String
    public let centerLocalX: Float
    public let centerLocalZ: Float
    public let centerWorld: WorldPosition
    public let width: Float
    public let depth: Float
    public let rotationRadians: Float
    public let vertices: [FootprintVertex]
    public let supportSolution: TerrainSupportSolution
    public let slopeClass: SettlementSlopeClass
    public let buildableScore: Float
    public let terrainHeightRange: Float
    public let foundationAdjustments: [FoundationAdjustment]

    public init(
        id: StableID,
        intentID: StableID,
        structureRecipeID: String,
        centerLocalX: Float,
        centerLocalZ: Float,
        centerWorld: WorldPosition,
        width: Float,
        depth: Float,
        rotationRadians: Float,
        vertices: [FootprintVertex],
        supportSolution: TerrainSupportSolution,
        slopeClass: SettlementSlopeClass,
        buildableScore: Float,
        terrainHeightRange: Float,
        foundationAdjustments: [FoundationAdjustment]
    ) {
        precondition(!structureRecipeID.isEmpty, "BuildingFootprint needs a structure recipe id.")
        precondition(width > 0 && depth > 0, "BuildingFootprint dimensions must be positive.")
        precondition(vertices.count == 4, "BuildingFootprint expects four corner vertices.")

        self.id = id
        self.intentID = intentID
        self.structureRecipeID = structureRecipeID
        self.centerLocalX = centerLocalX
        self.centerLocalZ = centerLocalZ
        self.centerWorld = centerWorld
        self.width = width
        self.depth = depth
        self.rotationRadians = rotationRadians
        self.vertices = vertices
        self.supportSolution = supportSolution
        self.slopeClass = slopeClass
        self.buildableScore = clamped01(buildableScore)
        self.terrainHeightRange = max(terrainHeightRange, 0)
        self.foundationAdjustments = foundationAdjustments
    }

    public var foundationMaxOffset: Float {
        foundationAdjustments
            .map { abs($0.verticalOffset) }
            .max() ?? 0
    }
}

public struct FootprintGenerator: Sendable {
    public let worldSeed: WorldSeed
    public let generatorVersions: GeneratorVersionTable

    public init(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) {
        self.worldSeed = worldSeed
        self.generatorVersions = generatorVersions
    }

    public func footprint(
        for intent: BuildingIntent,
        structureRecipe: StructureRecipe,
        supportMap: TerrainSupportMap
    ) -> BuildingFootprint {
        var rng = StableRNG(seedValue: StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.buildingFootprints)
            builder.combine(generatorVersions.version(for: .buildingFootprints))
            builder.combine(intent.id.rawValue)
            builder.combine(structureRecipe.id)
        }.value)
        let sampledDimensions = structureRecipe.dimensions.sample(using: &rng)
        let width = sampledDimensions.x * intent.footprintScale
        let depth = sampledDimensions.z * intent.footprintScale
        let halfDiagonal = (width * width + depth * depth).squareRoot() * 0.5
        let margin = max(halfDiagonal + 1, 2)
        let maxLocal = Float(supportMap.resolution - 1)
        let centerLocalX = clamped(
            intent.localAnchorX,
            lowerBound: margin,
            upperBound: maxLocal - margin
        )
        let centerLocalZ = clamped(
            intent.localAnchorZ,
            lowerBound: margin,
            upperBound: maxLocal - margin
        )
        let vertices = footprintVertices(
            centerLocalX: centerLocalX,
            centerLocalZ: centerLocalZ,
            width: width,
            depth: depth,
            rotationRadians: intent.rotationRadians,
            supportMap: supportMap
        )
        let supportSamples = vertices.map {
            supportMap.nearestSample(localX: $0.localX, localZ: $0.localZ)
        }
        let centerSample = supportMap.nearestSample(
            localX: centerLocalX,
            localZ: centerLocalZ
        )
        let heights = vertices.map(\.terrainHeight)
        let minHeight = heights.min() ?? centerSample.height
        let maxHeight = heights.max() ?? centerSample.height
        let terrainHeightRange = maxHeight - minHeight
        let supportSolution = supportSolution(
            recipe: structureRecipe,
            centerSample: centerSample,
            supportSamples: supportSamples,
            terrainHeightRange: terrainHeightRange
        )
        let targetHeight = foundationTargetHeight(
            solution: supportSolution,
            minHeight: minHeight,
            maxHeight: maxHeight,
            averageHeight: heights.reduce(Float(0), +) / Float(max(heights.count, 1))
        )
        let adjustments = vertices.enumerated().map { index, vertex in
            FoundationAdjustment(
                vertexIndex: index,
                terrainHeight: vertex.terrainHeight,
                targetHeight: targetHeight
            )
        }
        let footprintID = StableID.make(
            worldSeed: worldSeed,
            domain: .buildingFootprints,
            coordinate: supportMap.coordinate,
            values: [
                versionValue(for: .buildingFootprints),
                intent.id.rawValue,
            ]
        )

        return BuildingFootprint(
            id: footprintID,
            intentID: intent.id,
            structureRecipeID: structureRecipe.id,
            centerLocalX: centerLocalX,
            centerLocalZ: centerLocalZ,
            centerWorld: WorldPosition(
                x: Float(centerSample.worldX),
                y: targetHeight,
                z: Float(centerSample.worldZ)
            ),
            width: width,
            depth: depth,
            rotationRadians: intent.rotationRadians,
            vertices: vertices,
            supportSolution: supportSolution,
            slopeClass: centerSample.slopeClass,
            buildableScore: supportSamples.reduce(Float(0)) { $0 + $1.buildableScore } /
                Float(max(supportSamples.count, 1)),
            terrainHeightRange: terrainHeightRange,
            foundationAdjustments: adjustments
        )
    }

    private func footprintVertices(
        centerLocalX: Float,
        centerLocalZ: Float,
        width: Float,
        depth: Float,
        rotationRadians: Float,
        supportMap: TerrainSupportMap
    ) -> [FootprintVertex] {
        let halfWidth = width * 0.5
        let halfDepth = depth * 0.5
        let cosA = cos(rotationRadians)
        let sinA = sin(rotationRadians)
        let localCorners: [(Float, Float)] = [
            (-halfWidth, -halfDepth),
            (halfWidth, -halfDepth),
            (halfWidth, halfDepth),
            (-halfWidth, halfDepth),
        ]

        return localCorners.map { localCorner in
            let rotatedX = localCorner.0 * cosA - localCorner.1 * sinA
            let rotatedZ = localCorner.0 * sinA + localCorner.1 * cosA
            let localX = centerLocalX + rotatedX
            let localZ = centerLocalZ + rotatedZ
            let sample = supportMap.nearestSample(localX: localX, localZ: localZ)

            return FootprintVertex(
                localX: localX,
                localZ: localZ,
                worldX: Float(sample.worldX),
                worldZ: Float(sample.worldZ),
                terrainHeight: sample.height
            )
        }
    }

    private func supportSolution(
        recipe: StructureRecipe,
        centerSample: TerrainSupportSample,
        supportSamples: [TerrainSupportSample],
        terrainHeightRange: Float
    ) -> TerrainSupportSolution {
        let candidate: TerrainSupportSolution

        if supportSamples.contains(where: { $0.waterDepth > 0.04 }) {
            candidate = .stilts
        } else if terrainHeightRange <= 0.18 && centerSample.slopeClass == .flat {
            candidate = .flatFoundation
        } else if terrainHeightRange <= 0.85 && centerSample.slopeClass != .steep {
            candidate = .steppedFoundation
        } else if centerSample.supportSolution == .rockAnchors {
            candidate = .rockAnchors
        } else if terrainHeightRange <= 1.8 {
            candidate = .retainingWalls
        } else {
            candidate = .terrace
        }

        if recipe.allowedSupportSolutions.contains(candidate) {
            return candidate
        }

        return recipe.allowedSupportSolutions.first ?? centerSample.supportSolution
    }

    private func foundationTargetHeight(
        solution: TerrainSupportSolution,
        minHeight: Float,
        maxHeight: Float,
        averageHeight: Float
    ) -> Float {
        switch solution {
        case .flatFoundation:
            return averageHeight
        case .steppedFoundation:
            return (averageHeight * 2).rounded() / 2
        case .stilts:
            return maxHeight + 0.85
        case .retainingWalls, .terrace:
            return maxHeight + 0.18
        case .rockAnchors:
            return max(minHeight, averageHeight)
        }
    }

    private func versionValue(for domain: SeedDomain) -> UInt64 {
        StableHash.make { builder in
            builder.combine(domain)
            builder.combine(generatorVersions.version(for: domain))
        }.value
    }
}

private func clamped01(_ value: Float) -> Float {
    min(max(value, 0), 1)
}

private func clamped(_ value: Float, lowerBound: Float, upperBound: Float) -> Float {
    min(max(value, lowerBound), upperBound)
}
