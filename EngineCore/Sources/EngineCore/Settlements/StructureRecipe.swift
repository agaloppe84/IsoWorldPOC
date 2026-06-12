public enum BuildingFunction: String, CaseIterable, Codable, Sendable {
    case dwelling
    case storage
    case workshop
    case market
    case shrine
    case watchtower
    case hall
    case farm
}

public enum SettlementMaterialFamily: String, CaseIterable, Codable, Sendable {
    case timber
    case stone
    case clay
    case reed
    case metal
    case salvage
}

public enum RoofProfile: String, CaseIterable, Codable, Sendable {
    case flat
    case shed
    case gable
    case pyramidal
}

public struct StructureDimensionRange: Hashable, Codable, Sendable {
    public let minWidth: Float
    public let maxWidth: Float
    public let minDepth: Float
    public let maxDepth: Float
    public let minHeight: Float
    public let maxHeight: Float

    public init(
        minWidth: Float,
        maxWidth: Float,
        minDepth: Float,
        maxDepth: Float,
        minHeight: Float,
        maxHeight: Float
    ) {
        precondition(minWidth > 0 && maxWidth >= minWidth, "Width range must be positive and ordered.")
        precondition(minDepth > 0 && maxDepth >= minDepth, "Depth range must be positive and ordered.")
        precondition(minHeight > 0 && maxHeight >= minHeight, "Height range must be positive and ordered.")

        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }

    public func sample(using rng: inout StableRNG) -> PropVector3 {
        PropVector3(
            x: rng.nextFloat(in: minWidth...maxWidth),
            y: rng.nextFloat(in: minHeight...maxHeight),
            z: rng.nextFloat(in: minDepth...maxDepth)
        )
    }
}

public struct StructureRecipe: Hashable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let function: BuildingFunction
    public let dimensions: StructureDimensionRange
    public let minStoreys: Int
    public let maxStoreys: Int
    public let roofProfile: RoofProfile
    public let materialFamilies: [SettlementMaterialFamily]
    public let allowedSupportSolutions: [TerrainSupportSolution]
    public let tags: [GameplayTag]

    public init(
        id: String,
        displayName: String,
        function: BuildingFunction,
        dimensions: StructureDimensionRange,
        minStoreys: Int = 1,
        maxStoreys: Int = 1,
        roofProfile: RoofProfile,
        materialFamilies: [SettlementMaterialFamily],
        allowedSupportSolutions: [TerrainSupportSolution],
        tags: [GameplayTag] = []
    ) {
        precondition(!id.isEmpty, "StructureRecipe id cannot be empty.")
        precondition(!displayName.isEmpty, "StructureRecipe displayName cannot be empty.")
        precondition(minStoreys > 0 && maxStoreys >= minStoreys, "Storey range must be positive and ordered.")
        precondition(!materialFamilies.isEmpty, "StructureRecipe needs at least one material family.")
        precondition(!allowedSupportSolutions.isEmpty, "StructureRecipe needs at least one support solution.")

        self.id = id
        self.displayName = displayName
        self.function = function
        self.dimensions = dimensions
        self.minStoreys = minStoreys
        self.maxStoreys = maxStoreys
        self.roofProfile = roofProfile
        self.materialFamilies = materialFamilies
        self.allowedSupportSolutions = allowedSupportSolutions
        self.tags = tags.uniquedStable()
    }

    public static let v1Catalog: [StructureRecipe] = [
        StructureRecipe(
            id: "structure.dwelling.simple_house",
            displayName: "Simple house",
            function: .dwelling,
            dimensions: StructureDimensionRange(
                minWidth: 4.8,
                maxWidth: 7.2,
                minDepth: 4.5,
                maxDepth: 6.8,
                minHeight: 2.8,
                maxHeight: 3.8
            ),
            minStoreys: 1,
            maxStoreys: 2,
            roofProfile: .gable,
            materialFamilies: [.timber, .stone, .clay, .salvage],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .stilts, .retainingWalls],
            tags: [.buildings, .settlement, .terrainAdapted]
        ),
        StructureRecipe(
            id: "structure.dwelling.cabin",
            displayName: "Terrain cabin",
            function: .dwelling,
            dimensions: StructureDimensionRange(
                minWidth: 3.8,
                maxWidth: 5.8,
                minDepth: 3.6,
                maxDepth: 5.4,
                minHeight: 2.5,
                maxHeight: 3.2
            ),
            roofProfile: .shed,
            materialFamilies: [.timber, .reed, .salvage],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .stilts],
            tags: [.buildings, .survival, .terrainAdapted]
        ),
        StructureRecipe(
            id: "structure.storage.shed",
            displayName: "Storage shed",
            function: .storage,
            dimensions: StructureDimensionRange(
                minWidth: 3.6,
                maxWidth: 5.4,
                minDepth: 3.0,
                maxDepth: 4.8,
                minHeight: 2.4,
                maxHeight: 3.1
            ),
            roofProfile: .shed,
            materialFamilies: [.timber, .stone, .salvage],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .stilts],
            tags: [.buildings, .crafting]
        ),
        StructureRecipe(
            id: "structure.workshop.small",
            displayName: "Small workshop",
            function: .workshop,
            dimensions: StructureDimensionRange(
                minWidth: 5.0,
                maxWidth: 7.8,
                minDepth: 4.8,
                maxDepth: 7.4,
                minHeight: 3.0,
                maxHeight: 4.2
            ),
            roofProfile: .flat,
            materialFamilies: [.timber, .stone, .metal, .salvage],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .retainingWalls],
            tags: [.buildings, .crafting, .technology]
        ),
        StructureRecipe(
            id: "structure.market.stall_cluster",
            displayName: "Market stall cluster",
            function: .market,
            dimensions: StructureDimensionRange(
                minWidth: 5.5,
                maxWidth: 8.5,
                minDepth: 3.8,
                maxDepth: 6.2,
                minHeight: 2.6,
                maxHeight: 3.4
            ),
            roofProfile: .shed,
            materialFamilies: [.timber, .reed, .salvage],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .stilts],
            tags: [.buildings, .trade, .social]
        ),
        StructureRecipe(
            id: "structure.shrine.small",
            displayName: "Small shrine",
            function: .shrine,
            dimensions: StructureDimensionRange(
                minWidth: 3.6,
                maxWidth: 6.0,
                minDepth: 3.6,
                maxDepth: 6.0,
                minHeight: 3.2,
                maxHeight: 5.2
            ),
            roofProfile: .pyramidal,
            materialFamilies: [.stone, .timber, .clay],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .retainingWalls, .rockAnchors],
            tags: [.buildings, .myth, .architecture]
        ),
        StructureRecipe(
            id: "structure.defense.watchtower",
            displayName: "Watchtower",
            function: .watchtower,
            dimensions: StructureDimensionRange(
                minWidth: 3.2,
                maxWidth: 4.8,
                minDepth: 3.2,
                maxDepth: 4.8,
                minHeight: 5.8,
                maxHeight: 8.5
            ),
            minStoreys: 2,
            maxStoreys: 3,
            roofProfile: .pyramidal,
            materialFamilies: [.timber, .stone, .metal],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .retainingWalls, .rockAnchors],
            tags: [.buildings, .threat]
        ),
        StructureRecipe(
            id: "structure.civic.hall",
            displayName: "Common hall",
            function: .hall,
            dimensions: StructureDimensionRange(
                minWidth: 7.0,
                maxWidth: 10.0,
                minDepth: 6.0,
                maxDepth: 9.0,
                minHeight: 3.6,
                maxHeight: 5.0
            ),
            roofProfile: .gable,
            materialFamilies: [.timber, .stone, .clay],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .retainingWalls],
            tags: [.buildings, .social, .settlement]
        ),
        StructureRecipe(
            id: "structure.farm.field_house",
            displayName: "Field house",
            function: .farm,
            dimensions: StructureDimensionRange(
                minWidth: 4.2,
                maxWidth: 6.4,
                minDepth: 4.0,
                maxDepth: 6.0,
                minHeight: 2.6,
                maxHeight: 3.6
            ),
            roofProfile: .gable,
            materialFamilies: [.timber, .reed, .clay],
            allowedSupportSolutions: [.flatFoundation, .steppedFoundation, .stilts],
            tags: [.buildings, .ecology]
        ),
    ]
}

public struct WeightedStructureRecipe: Hashable, Codable, Sendable {
    public let recipe: StructureRecipe
    public let weight: Float

    public init(recipe: StructureRecipe, weight: Float) {
        precondition(weight >= 0, "WeightedStructureRecipe weight must be non-negative.")

        self.recipe = recipe
        self.weight = weight
    }
}
