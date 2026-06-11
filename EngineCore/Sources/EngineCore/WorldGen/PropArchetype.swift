public struct PropArchetype: Equatable, Hashable, Codable, Sendable {
    public let identifier: String
    public let type: PropType
    public let minimumSize: PropVector3
    public let maximumSize: PropVector3
    public let allowedBiomes: [BiomeType]

    public init(
        identifier: String,
        type: PropType,
        minimumSize: PropVector3,
        maximumSize: PropVector3,
        allowedBiomes: [BiomeType]
    ) {
        self.identifier = identifier
        self.type = type
        self.minimumSize = minimumSize
        self.maximumSize = maximumSize
        self.allowedBiomes = allowedBiomes
    }

    public static func definition(for type: PropType, biome: Biome) -> PropArchetype {
        switch type {
        case .rock:
            rockArchetype(for: biome)
        case .pebble:
            pebbleArchetype(for: biome)
        case .grass:
            grassArchetype(for: biome)
        case .tree:
            treeArchetype(for: biome)
        case .deadwood:
            deadwoodArchetype(for: biome)
        case .crystal:
            crystalArchetype(for: biome)
        }
    }

    private static func rockArchetype(for biome: Biome) -> PropArchetype {
        switch biome.type {
        case .mountain:
            PropArchetype(
                identifier: "prop.rock.boulder",
                type: .rock,
                minimumSize: PropVector3(x: 0.34, y: 0.24, z: 0.30),
                maximumSize: PropVector3(x: 0.58, y: 0.42, z: 0.54),
                allowedBiomes: BiomeType.allCases
            )
        case .desert, .coast:
            PropArchetype(
                identifier: "prop.rock.flatPlateau",
                type: .rock,
                minimumSize: PropVector3(x: 0.36, y: 0.16, z: 0.28),
                maximumSize: PropVector3(x: 0.72, y: 0.30, z: 0.58),
                allowedBiomes: BiomeType.allCases
            )
        default:
            PropArchetype(
                identifier: "prop.rock.rounded",
                type: .rock,
                minimumSize: PropVector3(x: 0.26, y: 0.18, z: 0.24),
                maximumSize: PropVector3(x: 0.48, y: 0.34, z: 0.44),
                allowedBiomes: BiomeType.allCases
            )
        }
    }

    private static func pebbleArchetype(for biome: Biome) -> PropArchetype {
        switch biome.type {
        case .coast, .freshwater:
            PropArchetype(
                identifier: "prop.pebble.smooth",
                type: .pebble,
                minimumSize: PropVector3(x: 0.10, y: 0.05, z: 0.08),
                maximumSize: PropVector3(x: 0.24, y: 0.12, z: 0.18),
                allowedBiomes: BiomeType.allCases
            )
        default:
            PropArchetype(
                identifier: "prop.pebble.scatter",
                type: .pebble,
                minimumSize: PropVector3(x: 0.08, y: 0.04, z: 0.08),
                maximumSize: PropVector3(x: 0.20, y: 0.11, z: 0.20),
                allowedBiomes: BiomeType.allCases
            )
        }
    }

    private static func grassArchetype(for biome: Biome) -> PropArchetype {
        switch biome.type {
        case .marsh, .freshwater:
            PropArchetype(
                identifier: "prop.grass.reeds",
                type: .grass,
                minimumSize: PropVector3(x: 0.18, y: 0.46, z: 0.18),
                maximumSize: PropVector3(x: 0.30, y: 0.88, z: 0.30),
                allowedBiomes: [.grassland, .temperateForest, .marsh, .taiga, .coast, .freshwater]
            )
        case .desert, .coast:
            PropArchetype(
                identifier: "prop.grass.dryTuft",
                type: .grass,
                minimumSize: PropVector3(x: 0.16, y: 0.24, z: 0.16),
                maximumSize: PropVector3(x: 0.28, y: 0.46, z: 0.28),
                allowedBiomes: [.grassland, .temperateForest, .desert, .marsh, .taiga, .coast, .freshwater]
            )
        default:
            PropArchetype(
                identifier: "prop.grass.tuft",
                type: .grass,
                minimumSize: PropVector3(x: 0.18, y: 0.28, z: 0.18),
                maximumSize: PropVector3(x: 0.34, y: 0.62, z: 0.34),
                allowedBiomes: [.grassland, .temperateForest, .marsh, .taiga, .coast, .freshwater]
            )
        }
    }

    private static func treeArchetype(for biome: Biome) -> PropArchetype {
        switch biome.type {
        case .desert, .coast:
            PropArchetype(
                identifier: "prop.tree.dryScrub",
                type: .tree,
                minimumSize: PropVector3(x: 0.34, y: 0.70, z: 0.34),
                maximumSize: PropVector3(x: 0.52, y: 1.05, z: 0.52),
                allowedBiomes: [.grassland, .temperateForest, .desert, .marsh, .taiga, .coast, .freshwater]
            )
        case .temperateForest, .marsh, .taiga, .freshwater:
            PropArchetype(
                identifier: "prop.tree.broadCrown",
                type: .tree,
                minimumSize: PropVector3(x: 0.46, y: 1.05, z: 0.46),
                maximumSize: PropVector3(x: 0.76, y: 1.55, z: 0.76),
                allowedBiomes: [.grassland, .temperateForest, .desert, .marsh, .taiga, .coast, .freshwater]
            )
        default:
            PropArchetype(
                identifier: "prop.tree.generic",
                type: .tree,
                minimumSize: PropVector3(x: 0.38, y: 0.85, z: 0.38),
                maximumSize: PropVector3(x: 0.60, y: 1.20, z: 0.60),
                allowedBiomes: [.grassland, .temperateForest, .desert, .marsh, .taiga, .coast, .freshwater]
            )
        }
    }

    private static func deadwoodArchetype(for biome: Biome) -> PropArchetype {
        switch biome.type {
        case .coast, .freshwater:
            PropArchetype(
                identifier: "prop.deadwood.drift",
                type: .deadwood,
                minimumSize: PropVector3(x: 0.18, y: 0.14, z: 0.72),
                maximumSize: PropVector3(x: 0.30, y: 0.24, z: 1.18),
                allowedBiomes: [.grassland, .temperateForest, .marsh, .taiga, .coast, .freshwater]
            )
        default:
            PropArchetype(
                identifier: "prop.deadwood.branch",
                type: .deadwood,
                minimumSize: PropVector3(x: 0.16, y: 0.12, z: 0.56),
                maximumSize: PropVector3(x: 0.28, y: 0.22, z: 0.96),
                allowedBiomes: [.grassland, .temperateForest, .marsh, .taiga, .coast, .freshwater]
            )
        }
    }

    private static func crystalArchetype(for biome: Biome) -> PropArchetype {
        switch biome.type {
        case .marsh, .freshwater:
            PropArchetype(
                identifier: "prop.crystal.wetCluster",
                type: .crystal,
                minimumSize: PropVector3(x: 0.20, y: 0.42, z: 0.20),
                maximumSize: PropVector3(x: 0.34, y: 0.78, z: 0.34),
                allowedBiomes: BiomeType.allCases
            )
        default:
            PropArchetype(
                identifier: "prop.crystal.shard",
                type: .crystal,
                minimumSize: PropVector3(x: 0.16, y: 0.36, z: 0.16),
                maximumSize: PropVector3(x: 0.30, y: 0.70, z: 0.30),
                allowedBiomes: BiomeType.allCases
            )
        }
    }
}
