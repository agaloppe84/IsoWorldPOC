public struct BuildingIntent: Equatable, Hashable, Codable, Sendable {
    public let id: StableID
    public let settlementID: StableID
    public let index: Int
    public let function: BuildingFunction
    public let structureRecipeID: String
    public let localAnchorX: Float
    public let localAnchorZ: Float
    public let rotationRadians: Float
    public let importance: Float
    public let preferredStoreys: Int
    public let footprintScale: Float
    public let tags: [GameplayTag]

    public init(
        id: StableID,
        settlementID: StableID,
        index: Int,
        function: BuildingFunction,
        structureRecipeID: String,
        localAnchorX: Float,
        localAnchorZ: Float,
        rotationRadians: Float,
        importance: Float,
        preferredStoreys: Int,
        footprintScale: Float,
        tags: [GameplayTag]
    ) {
        precondition(index >= 0, "BuildingIntent index must be non-negative.")
        precondition(!structureRecipeID.isEmpty, "BuildingIntent needs a structure recipe id.")
        precondition(preferredStoreys > 0, "BuildingIntent needs at least one preferred storey.")
        precondition(footprintScale > 0, "BuildingIntent footprintScale must be positive.")

        self.id = id
        self.settlementID = settlementID
        self.index = index
        self.function = function
        self.structureRecipeID = structureRecipeID
        self.localAnchorX = localAnchorX
        self.localAnchorZ = localAnchorZ
        self.rotationRadians = rotationRadians
        self.importance = Self.clamped01(importance)
        self.preferredStoreys = preferredStoreys
        self.footprintScale = footprintScale
        self.tags = tags.uniquedStable()
    }

    public static func makeV1(
        worldSeed: WorldSeed,
        settlementID: StableID,
        index: Int,
        structureRecipe: StructureRecipe,
        localAnchorX: Float,
        localAnchorZ: Float,
        rotationRadians: Float,
        generatorVersions: GeneratorVersionTable = .current,
        rng: inout StableRNG
    ) -> BuildingIntent {
        let preferredStoreys = structureRecipe.minStoreys +
            rng.nextInt(upperBound: structureRecipe.maxStoreys - structureRecipe.minStoreys + 1)
        let id = StableID.make(
            worldSeed: worldSeed,
            domain: .buildingIntents,
            values: [
                versionValue(generatorVersions, domain: .buildingIntents),
                settlementID.rawValue,
                UInt64(bitPattern: Int64(index)),
                StableHash.make { builder in
                    builder.combine(structureRecipe.id)
                }.value,
            ]
        )

        return BuildingIntent(
            id: id,
            settlementID: settlementID,
            index: index,
            function: structureRecipe.function,
            structureRecipeID: structureRecipe.id,
            localAnchorX: localAnchorX,
            localAnchorZ: localAnchorZ,
            rotationRadians: rotationRadians,
            importance: importance(for: structureRecipe.function),
            preferredStoreys: preferredStoreys,
            footprintScale: rng.nextFloat(in: 0.88...1.16),
            tags: tags(for: structureRecipe)
        )
    }

    private static func tags(for recipe: StructureRecipe) -> [GameplayTag] {
        var tags = recipe.tags

        switch recipe.function {
        case .dwelling:
            tags.append(.settlement)
        case .storage, .workshop, .farm:
            tags.append(.crafting)
        case .market:
            tags.append(.trade)
        case .shrine:
            tags.append(.myth)
        case .watchtower:
            tags.append(.threat)
        case .hall:
            tags.append(.social)
        }

        return tags.uniquedStable()
    }

    private static func importance(for function: BuildingFunction) -> Float {
        switch function {
        case .hall, .shrine, .market, .watchtower:
            return 0.82
        case .workshop, .farm:
            return 0.62
        case .dwelling:
            return 0.48
        case .storage:
            return 0.36
        }
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

private func versionValue(
    _ generatorVersions: GeneratorVersionTable,
    domain: SeedDomain
) -> UInt64 {
    StableHash.make { builder in
        builder.combine(domain)
        builder.combine(generatorVersions.version(for: domain))
    }.value
}
