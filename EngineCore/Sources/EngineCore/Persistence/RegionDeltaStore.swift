public enum RegionDeltaKind: String, CaseIterable, Codable, Sendable {
    case terrain
    case prop
    case settlement
    case entity
}

public enum PropDeltaAction: String, CaseIterable, Codable, Sendable {
    case placed
    case removed
    case transformed
    case consumed
}

public struct TerrainSampleDelta: Hashable, Codable, Sendable {
    public let localX: Int
    public let localZ: Int
    public let heightOffset: Float
    public let materialOverride: String?
    public let walkabilityOverride: Float?

    public init(
        localX: Int,
        localZ: Int,
        heightOffset: Float = 0,
        materialOverride: String? = nil,
        walkabilityOverride: Float? = nil
    ) {
        precondition(localX >= 0 && localZ >= 0, "Terrain delta coordinates must be non-negative.")

        self.localX = localX
        self.localZ = localZ
        self.heightOffset = heightOffset
        self.materialOverride = materialOverride
        self.walkabilityOverride = walkabilityOverride.map(Self.clamped01)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct PropDelta: Hashable, Codable, Sendable {
    public let propID: StableID
    public let action: PropDeltaAction
    public let type: PropType?
    public let worldPosition: WorldPosition?
    public let rotationRadians: Float?
    public let scale: Float?

    public init(
        propID: StableID,
        action: PropDeltaAction,
        type: PropType? = nil,
        worldPosition: WorldPosition? = nil,
        rotationRadians: Float? = nil,
        scale: Float? = nil
    ) {
        precondition(scale == nil || scale! > 0, "Prop delta scale must be positive.")

        self.propID = propID
        self.action = action
        self.type = type
        self.worldPosition = worldPosition
        self.rotationRadians = rotationRadians
        self.scale = scale
    }
}

public struct SettlementDelta: Hashable, Codable, Sendable {
    public let settlementID: StableID
    public let buildingID: StableID?
    public let isDestroyed: Bool
    public let progress: Float
    public let note: String?

    public init(
        settlementID: StableID,
        buildingID: StableID? = nil,
        isDestroyed: Bool = false,
        progress: Float = 1,
        note: String? = nil
    ) {
        self.settlementID = settlementID
        self.buildingID = buildingID
        self.isDestroyed = isDestroyed
        self.progress = Self.clamped01(progress)
        self.note = note
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct ChunkDelta: Hashable, Codable, Sendable {
    public let coordinate: ChunkCoordinate
    public let terrainDeltas: [TerrainSampleDelta]
    public let propDeltas: [PropDelta]
    public let settlementDeltas: [SettlementDelta]
    public let entityIDs: [StableID]
    public let lastModifiedTick: UInt64

    public init(
        coordinate: ChunkCoordinate,
        terrainDeltas: [TerrainSampleDelta] = [],
        propDeltas: [PropDelta] = [],
        settlementDeltas: [SettlementDelta] = [],
        entityIDs: [StableID] = [],
        lastModifiedTick: UInt64
    ) {
        self.coordinate = coordinate
        self.terrainDeltas = terrainDeltas
        self.propDeltas = propDeltas
        self.settlementDeltas = settlementDeltas
        self.entityIDs = Self.uniquedStable(entityIDs)
        self.lastModifiedTick = lastModifiedTick
    }

    public var isEmpty: Bool {
        terrainDeltas.isEmpty &&
            propDeltas.isEmpty &&
            settlementDeltas.isEmpty &&
            entityIDs.isEmpty
    }

    public func merging(_ other: ChunkDelta) -> ChunkDelta {
        precondition(coordinate == other.coordinate, "Cannot merge deltas for different chunks.")

        return ChunkDelta(
            coordinate: coordinate,
            terrainDeltas: terrainDeltas + other.terrainDeltas,
            propDeltas: propDeltas + other.propDeltas,
            settlementDeltas: settlementDeltas + other.settlementDeltas,
            entityIDs: entityIDs + other.entityIDs,
            lastModifiedTick: max(lastModifiedTick, other.lastModifiedTick)
        )
    }

    private static func uniquedStable(_ values: [StableID]) -> [StableID] {
        var seen: Set<StableID> = []
        var result: [StableID] = []

        for value in values where seen.insert(value).inserted {
            result.append(value)
        }

        return result
    }
}

public struct RegionDeltaFile: Hashable, Codable, Sendable {
    public static let currentFormat = "IsoWorldRegionDelta"

    public let format: String
    public let saveVersion: SaveVersion
    public let worldSeed: WorldSeed
    public let region: RegionCoordinate
    public let generation: Int
    public let generatorVersionsHash: StableHash
    public let chunks: [ChunkDelta]

    public init(
        format: String = Self.currentFormat,
        saveVersion: SaveVersion = .current,
        worldSeed: WorldSeed,
        region: RegionCoordinate,
        generation: Int,
        generatorVersionsHash: StableHash,
        chunks: [ChunkDelta]
    ) {
        precondition(generation >= 0, "generation must be non-negative.")

        self.format = format
        self.saveVersion = saveVersion
        self.worldSeed = worldSeed
        self.region = region
        self.generation = generation
        self.generatorVersionsHash = generatorVersionsHash
        self.chunks = chunks
            .filter { !$0.isEmpty }
            .sorted { lhs, rhs in
                if lhs.coordinate.x != rhs.coordinate.x { return lhs.coordinate.x < rhs.coordinate.x }
                if lhs.coordinate.y != rhs.coordinate.y { return lhs.coordinate.y < rhs.coordinate.y }
                return lhs.coordinate.z < rhs.coordinate.z
            }
    }

    public var relativePath: String {
        "regions/r.\(region.x).\(region.y).\(region.z).isoregion"
    }

    public var modifiedChunkCount: Int {
        chunks.count
    }
}

public struct RegionDeltaStore: Hashable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let regionSizeInChunks: Int
    public let generation: Int
    public let generatorVersions: GeneratorVersionTable
    public let files: [RegionDeltaFile]

    public init(
        worldSeed: WorldSeed,
        regionSizeInChunks: Int = 8,
        generation: Int = 0,
        generatorVersions: GeneratorVersionTable = .current,
        files: [RegionDeltaFile] = []
    ) {
        precondition(regionSizeInChunks > 0, "regionSizeInChunks must be positive.")
        precondition(generation >= 0, "generation must be non-negative.")

        self.worldSeed = worldSeed
        self.regionSizeInChunks = regionSizeInChunks
        self.generation = generation
        self.generatorVersions = generatorVersions
        self.files = Self.merged(files)
    }

    public func region(for coordinate: ChunkCoordinate) -> RegionCoordinate {
        RegionCoordinate.containing(
            coordinate,
            regionSizeInChunks: regionSizeInChunks
        )
    }

    public func adding(_ delta: ChunkDelta) -> RegionDeltaStore {
        let region = region(for: delta.coordinate)
        let newFile = RegionDeltaFile(
            worldSeed: worldSeed,
            region: region,
            generation: generation,
            generatorVersionsHash: generatorVersions.persistenceHash,
            chunks: [delta]
        )

        return RegionDeltaStore(
            worldSeed: worldSeed,
            regionSizeInChunks: regionSizeInChunks,
            generation: generation,
            generatorVersions: generatorVersions,
            files: files + [newFile]
        )
    }

    public func file(for region: RegionCoordinate) -> RegionDeltaFile? {
        files.first { $0.region == region }
    }

    public var relativePaths: [String] {
        files.map(\.relativePath)
    }

    private static func merged(_ files: [RegionDeltaFile]) -> [RegionDeltaFile] {
        var chunksByRegion: [RegionCoordinate: [ChunkCoordinate: ChunkDelta]] = [:]
        var templateByRegion: [RegionCoordinate: RegionDeltaFile] = [:]

        for file in files {
            templateByRegion[file.region] = file
            for chunk in file.chunks {
                if let existing = chunksByRegion[file.region]?[chunk.coordinate] {
                    chunksByRegion[file.region]?[chunk.coordinate] = existing.merging(chunk)
                } else {
                    chunksByRegion[file.region, default: [:]][chunk.coordinate] = chunk
                }
            }
        }

        return chunksByRegion.keys.sorted { lhs, rhs in
            if lhs.x != rhs.x { return lhs.x < rhs.x }
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.z < rhs.z
        }.compactMap { region in
            guard let template = templateByRegion[region] else {
                return nil
            }

            return RegionDeltaFile(
                format: template.format,
                saveVersion: template.saveVersion,
                worldSeed: template.worldSeed,
                region: region,
                generation: template.generation,
                generatorVersionsHash: template.generatorVersionsHash,
                chunks: chunksByRegion[region].map { Array($0.values) } ?? []
            )
        }
    }
}
