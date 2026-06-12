public struct StructureRenderInstance: Equatable, Codable, Sendable {
    public let id: StableID
    public let prototypeKey: String
    public let function: BuildingFunction
    public let worldPosition: WorldPosition
    public let rotationRadians: Float
    public let geometry: PropGeometryDescriptor
    public let primaryMaterial: PropMaterialDescriptor
    public let secondaryMaterial: PropMaterialDescriptor
    public let accentMaterial: PropMaterialDescriptor
    public let collisionSize: PropVector3
    public let isVisible: Bool

    public init(
        id: StableID,
        prototypeKey: String,
        function: BuildingFunction,
        worldPosition: WorldPosition,
        rotationRadians: Float,
        geometry: PropGeometryDescriptor,
        primaryMaterial: PropMaterialDescriptor,
        secondaryMaterial: PropMaterialDescriptor,
        accentMaterial: PropMaterialDescriptor,
        collisionSize: PropVector3,
        isVisible: Bool = true
    ) {
        precondition(!prototypeKey.isEmpty, "StructureRenderInstance prototypeKey cannot be empty.")

        self.id = id
        self.prototypeKey = prototypeKey
        self.function = function
        self.worldPosition = worldPosition
        self.rotationRadians = rotationRadians
        self.geometry = geometry
        self.primaryMaterial = primaryMaterial
        self.secondaryMaterial = secondaryMaterial
        self.accentMaterial = accentMaterial
        self.collisionSize = collisionSize
        self.isVisible = isVisible
    }
}

public struct BuildingMassing: Equatable, Codable, Sendable {
    public let id: StableID
    public let intentID: StableID
    public let footprintID: StableID
    public let structureRecipeID: String
    public let storeys: Int
    public let floorHeight: Float
    public let bodySize: PropVector3
    public let roofHeight: Float
    public let supportSolution: TerrainSupportSolution
    public let geometry: PropGeometryDescriptor
    public let renderInstance: StructureRenderInstance

    public init(
        id: StableID,
        intentID: StableID,
        footprintID: StableID,
        structureRecipeID: String,
        storeys: Int,
        floorHeight: Float,
        bodySize: PropVector3,
        roofHeight: Float,
        supportSolution: TerrainSupportSolution,
        geometry: PropGeometryDescriptor,
        renderInstance: StructureRenderInstance
    ) {
        precondition(!structureRecipeID.isEmpty, "BuildingMassing needs a structure recipe id.")
        precondition(storeys > 0, "BuildingMassing needs at least one storey.")
        precondition(floorHeight > 0, "BuildingMassing floorHeight must be positive.")
        precondition(roofHeight >= 0, "BuildingMassing roofHeight must be non-negative.")

        self.id = id
        self.intentID = intentID
        self.footprintID = footprintID
        self.structureRecipeID = structureRecipeID
        self.storeys = storeys
        self.floorHeight = floorHeight
        self.bodySize = bodySize
        self.roofHeight = roofHeight
        self.supportSolution = supportSolution
        self.geometry = geometry
        self.renderInstance = renderInstance
    }
}

public struct MassingGenerator: Sendable {
    public let worldSeed: WorldSeed
    public let generatorVersions: GeneratorVersionTable

    public init(
        worldSeed: WorldSeed,
        generatorVersions: GeneratorVersionTable = .current
    ) {
        self.worldSeed = worldSeed
        self.generatorVersions = generatorVersions
    }

    public func massing(
        for intent: BuildingIntent,
        structureRecipe: StructureRecipe,
        footprint: BuildingFootprint,
        biome: Biome,
        ruleset: WorldRuleset
    ) -> BuildingMassing {
        var rng = StableRNG(seedValue: StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.buildingMassing)
            builder.combine(generatorVersions.version(for: .buildingMassing))
            builder.combine(intent.id.rawValue)
            builder.combine(footprint.id.rawValue)
        }.value)
        let storeys = clamped(
            intent.preferredStoreys,
            lowerBound: structureRecipe.minStoreys,
            upperBound: structureRecipe.maxStoreys
        )
        let floorHeight = floorHeight(for: ruleset.dna.techLevel, rng: &rng)
        let bodyHeight = floorHeight * Float(storeys)
        let roofHeight = roofHeight(
            recipe: structureRecipe,
            footprint: footprint,
            rng: &rng
        )
        let supportHeight = supportHeight(for: footprint)
        let bodySize = PropVector3(
            x: footprint.width,
            y: bodyHeight,
            z: footprint.depth
        )
        let materials = materialSet(
            recipe: structureRecipe,
            biome: biome,
            ruleset: ruleset,
            rng: &rng
        )
        let geometry = geometry(
            recipe: structureRecipe,
            bodySize: bodySize,
            roofHeight: roofHeight,
            supportHeight: supportHeight,
            supportSolution: footprint.supportSolution
        )
        let id = StableID.make(
            worldSeed: worldSeed,
            domain: .buildingMassing,
            values: [
                versionValue(for: .buildingMassing),
                intent.id.rawValue,
                footprint.id.rawValue,
            ]
        )
        let collisionSize = PropVector3(
            x: footprint.width,
            y: bodyHeight + roofHeight + supportHeight,
            z: footprint.depth
        )
        let renderInstance = StructureRenderInstance(
            id: id,
            prototypeKey: "\(structureRecipe.id).\(materials.primary.identifier)",
            function: intent.function,
            worldPosition: WorldPosition(
                x: footprint.centerWorld.x,
                y: footprint.centerWorld.y,
                z: footprint.centerWorld.z
            ),
            rotationRadians: footprint.rotationRadians,
            geometry: geometry,
            primaryMaterial: materials.primary,
            secondaryMaterial: materials.secondary,
            accentMaterial: materials.accent,
            collisionSize: collisionSize
        )

        return BuildingMassing(
            id: id,
            intentID: intent.id,
            footprintID: footprint.id,
            structureRecipeID: structureRecipe.id,
            storeys: storeys,
            floorHeight: floorHeight,
            bodySize: bodySize,
            roofHeight: roofHeight,
            supportSolution: footprint.supportSolution,
            geometry: geometry,
            renderInstance: renderInstance
        )
    }

    private func geometry(
        recipe: StructureRecipe,
        bodySize: PropVector3,
        roofHeight: Float,
        supportHeight: Float,
        supportSolution: TerrainSupportSolution
    ) -> PropGeometryDescriptor {
        var parts: [PropGeometryPart] = [
            PropGeometryPart(
                shape: .box,
                size: bodySize,
                cornerRadius: min(bodySize.x, bodySize.z) * 0.035,
                position: PropVector3(
                    x: 0,
                    y: supportHeight + bodySize.y * 0.5,
                    z: 0
                ),
                materialSlot: .primary
            ),
        ]

        if roofHeight > 0 {
            parts.append(PropGeometryPart(
                shape: roofShape(for: recipe.roofProfile),
                size: PropVector3(
                    x: bodySize.x * 1.08,
                    y: roofHeight,
                    z: bodySize.z * 1.08
                ),
                cornerRadius: min(bodySize.x, bodySize.z) * 0.025,
                position: PropVector3(
                    x: 0,
                    y: supportHeight + bodySize.y + roofHeight * 0.48,
                    z: 0
                ),
                rotationRadians: roofRotation(for: recipe.roofProfile),
                materialSlot: .secondary
            ))
        }

        parts.append(contentsOf: supportParts(
            bodySize: bodySize,
            supportHeight: supportHeight,
            supportSolution: supportSolution
        ))

        return PropGeometryDescriptor(parts: parts)
    }

    private func supportParts(
        bodySize: PropVector3,
        supportHeight: Float,
        supportSolution: TerrainSupportSolution
    ) -> [PropGeometryPart] {
        guard supportHeight > 0.05 else {
            return []
        }

        switch supportSolution {
        case .stilts:
            let postWidth = max(min(bodySize.x, bodySize.z) * 0.055, 0.12)
            let x = bodySize.x * 0.42
            let z = bodySize.z * 0.42
            return [
                PropVector3(x: -x, y: supportHeight * 0.5, z: -z),
                PropVector3(x: x, y: supportHeight * 0.5, z: -z),
                PropVector3(x: x, y: supportHeight * 0.5, z: z),
                PropVector3(x: -x, y: supportHeight * 0.5, z: z),
            ].map { position in
                PropGeometryPart(
                    shape: .capsule,
                    size: PropVector3(x: postWidth, y: supportHeight, z: postWidth),
                    cornerRadius: postWidth * 0.18,
                    position: position,
                    materialSlot: .accent
                )
            }
        case .retainingWalls, .terrace:
            return [
                PropGeometryPart(
                    shape: .box,
                    size: PropVector3(x: bodySize.x * 1.08, y: supportHeight, z: 0.24),
                    position: PropVector3(x: 0, y: supportHeight * 0.5, z: -bodySize.z * 0.52),
                    materialSlot: .accent
                ),
                PropGeometryPart(
                    shape: .box,
                    size: PropVector3(x: bodySize.x * 1.08, y: supportHeight, z: 0.24),
                    position: PropVector3(x: 0, y: supportHeight * 0.5, z: bodySize.z * 0.52),
                    materialSlot: .accent
                ),
            ]
        case .steppedFoundation, .flatFoundation, .rockAnchors:
            return [
                PropGeometryPart(
                    shape: .box,
                    size: PropVector3(x: bodySize.x * 1.03, y: supportHeight, z: bodySize.z * 1.03),
                    position: PropVector3(x: 0, y: supportHeight * 0.5, z: 0),
                    materialSlot: .accent
                ),
            ]
        }
    }

    private func supportHeight(for footprint: BuildingFootprint) -> Float {
        switch footprint.supportSolution {
        case .flatFoundation:
            return min(footprint.foundationMaxOffset, 0.18)
        case .steppedFoundation:
            return min(max(footprint.foundationMaxOffset, 0.18), 0.75)
        case .stilts:
            return min(max(footprint.foundationMaxOffset, 0.90), 2.2)
        case .retainingWalls, .terrace:
            return min(max(footprint.foundationMaxOffset, 0.45), 1.8)
        case .rockAnchors:
            return min(max(footprint.foundationMaxOffset, 0.25), 1.2)
        }
    }

    private func floorHeight(
        for techLevel: RPGTechLevel,
        rng: inout StableRNG
    ) -> Float {
        let base: ClosedRange<Float>

        switch techLevel {
        case .naturalTools, .primitiveMetal:
            base = 2.35...2.75
        case .feudalCraft, .clockwork:
            base = 2.55...3.05
        case .industrial, .electric, .digital:
            base = 2.75...3.25
        case .cybernetic, .transhuman, .anomalousRelics:
            base = 2.90...3.55
        }

        return rng.nextFloat(in: base)
    }

    private func roofHeight(
        recipe: StructureRecipe,
        footprint: BuildingFootprint,
        rng: inout StableRNG
    ) -> Float {
        switch recipe.roofProfile {
        case .flat:
            return rng.nextFloat(in: 0.18...0.45)
        case .shed:
            return min(footprint.width, footprint.depth) * rng.nextFloat(in: 0.12...0.20)
        case .gable:
            return min(footprint.width, footprint.depth) * rng.nextFloat(in: 0.18...0.28)
        case .pyramidal:
            return min(footprint.width, footprint.depth) * rng.nextFloat(in: 0.24...0.36)
        }
    }

    private func roofShape(for profile: RoofProfile) -> PropGeometryShape {
        switch profile {
        case .flat, .shed, .gable:
            return .box
        case .pyramidal:
            return .cone
        }
    }

    private func roofRotation(for profile: RoofProfile) -> PropVector3 {
        switch profile {
        case .shed:
            return PropVector3(x: 0, y: 0, z: 0.08)
        case .flat, .gable, .pyramidal:
            return PropVector3(x: 0, y: 0, z: 0)
        }
    }

    private func materialSet(
        recipe: StructureRecipe,
        biome: Biome,
        ruleset: WorldRuleset,
        rng: inout StableRNG
    ) -> (
        primary: PropMaterialDescriptor,
        secondary: PropMaterialDescriptor,
        accent: PropMaterialDescriptor
    ) {
        let family = recipe.materialFamilies[rng.nextInt(upperBound: recipe.materialFamilies.count)]
        let primary = PropMaterialDescriptor(
            identifier: "building.material.\(family.rawValue).\(biome.type.rawValue)",
            color: varied(color(for: family, biome: biome, ruleset: ruleset), amount: 0.08, rng: &rng),
            roughness: roughness(for: family)
        )
        let roof = PropMaterialDescriptor(
            identifier: "building.material.roof.\(family.rawValue).\(biome.type.rawValue)",
            color: varied(roofColor(for: family, biome: biome), amount: 0.06, rng: &rng),
            roughness: min(roughness(for: family) + 0.04, 1)
        )
        let accent = PropMaterialDescriptor(
            identifier: "building.material.support.\(biome.type.rawValue)",
            color: varied(supportColor(for: biome), amount: 0.05, rng: &rng),
            roughness: 0.88
        )

        return (primary, roof, accent)
    }

    private func color(
        for family: SettlementMaterialFamily,
        biome: Biome,
        ruleset: WorldRuleset
    ) -> BiomeColor {
        switch family {
        case .timber:
            return BiomeColor(red: 0.34, green: 0.23, blue: 0.14)
        case .stone:
            return supportColor(for: biome)
        case .clay:
            return BiomeColor(red: 0.52, green: 0.36, blue: 0.22)
        case .reed:
            return BiomeColor(red: 0.48, green: 0.43, blue: 0.22)
        case .metal:
            return ruleset.dna.techLevel == .anomalousRelics
                ? BiomeColor(red: 0.38, green: 0.44, blue: 0.52)
                : BiomeColor(red: 0.30, green: 0.31, blue: 0.31)
        case .salvage:
            return BiomeColor(red: 0.40, green: 0.32, blue: 0.27)
        }
    }

    private func roofColor(
        for family: SettlementMaterialFamily,
        biome: Biome
    ) -> BiomeColor {
        switch family {
        case .reed:
            return BiomeColor(red: 0.56, green: 0.48, blue: 0.24)
        case .clay:
            return BiomeColor(red: 0.48, green: 0.24, blue: 0.17)
        case .stone:
            return supportColor(for: biome)
        case .metal:
            return BiomeColor(red: 0.26, green: 0.28, blue: 0.30)
        case .timber, .salvage:
            return BiomeColor(red: 0.25, green: 0.18, blue: 0.12)
        }
    }

    private func supportColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .desert, .coast:
            return BiomeColor(red: 0.58, green: 0.51, blue: 0.36)
        case .mountain, .taiga:
            return BiomeColor(red: 0.39, green: 0.40, blue: 0.38)
        case .marsh, .freshwater:
            return BiomeColor(red: 0.29, green: 0.34, blue: 0.31)
        case .temperateForest:
            return BiomeColor(red: 0.34, green: 0.38, blue: 0.28)
        case .grassland:
            return BiomeColor(red: 0.42, green: 0.41, blue: 0.28)
        }
    }

    private func roughness(for family: SettlementMaterialFamily) -> Float {
        switch family {
        case .metal:
            return 0.58
        case .stone:
            return 0.90
        case .reed, .timber, .clay, .salvage:
            return 0.84
        }
    }

    private func varied(
        _ color: BiomeColor,
        amount: Float,
        rng: inout StableRNG
    ) -> BiomeColor {
        BiomeColor(
            red: clamped01(color.red + rng.nextFloat(in: (-amount)...amount)),
            green: clamped01(color.green + rng.nextFloat(in: (-amount)...amount)),
            blue: clamped01(color.blue + rng.nextFloat(in: (-amount)...amount))
        )
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

private func clamped(_ value: Int, lowerBound: Int, upperBound: Int) -> Int {
    min(max(value, lowerBound), upperBound)
}
