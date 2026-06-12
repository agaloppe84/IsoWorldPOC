public enum PersistentEntityKind: String, CaseIterable, Codable, Sendable {
    case player
    case npc
    case animal
    case uniqueEnemy
    case prop
    case settlementBuilding
    case container
    case machine
    case projectile
    case toolPlacedObject
}

public struct EntityComponentState: Hashable, Codable, Sendable {
    public let componentID: String
    public let schemaVersion: Int
    public let payloadHash: StableHash
    public let scalarValues: [String: Double]
    public let stringValues: [String: String]

    public init(
        componentID: String,
        schemaVersion: Int = 1,
        payloadHash: StableHash,
        scalarValues: [String: Double] = [:],
        stringValues: [String: String] = [:]
    ) {
        precondition(!componentID.isEmpty, "componentID cannot be empty.")
        precondition(schemaVersion > 0, "schemaVersion must be positive.")

        self.componentID = componentID
        self.schemaVersion = schemaVersion
        self.payloadHash = payloadHash
        self.scalarValues = scalarValues
        self.stringValues = stringValues
    }
}

public struct EntityPersistenceState: Hashable, Codable, Sendable {
    public let id: StableID
    public let kind: PersistentEntityKind
    public let displayName: String?
    public let worldPosition: WorldPosition
    public let chunk: ChunkCoordinate
    public let region: RegionCoordinate
    public let stateVersion: Int
    public let lastModifiedTick: UInt64
    public let tags: [GameplayTag]
    public let components: [EntityComponentState]
    public let isRemoved: Bool

    public init(
        id: StableID,
        kind: PersistentEntityKind,
        displayName: String? = nil,
        worldPosition: WorldPosition,
        chunk: ChunkCoordinate? = nil,
        region: RegionCoordinate? = nil,
        regionSizeInChunks: Int = 8,
        stateVersion: Int = 1,
        lastModifiedTick: UInt64,
        tags: [GameplayTag] = [],
        components: [EntityComponentState] = [],
        isRemoved: Bool = false
    ) {
        precondition(regionSizeInChunks > 0, "regionSizeInChunks must be positive.")
        precondition(stateVersion > 0, "stateVersion must be positive.")

        let resolvedChunk = chunk ?? ChunkCoordinate.containing(
            worldPosition,
            chunkSize: Float(ChunkHeightmap.gridStride)
        )

        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.worldPosition = worldPosition
        self.chunk = resolvedChunk
        self.region = region ?? RegionCoordinate.containing(
            resolvedChunk,
            regionSizeInChunks: regionSizeInChunks
        )
        self.stateVersion = stateVersion
        self.lastModifiedTick = lastModifiedTick
        self.tags = tags.uniquedStable()
        self.components = components.sorted { $0.componentID < $1.componentID }
        self.isRemoved = isRemoved
    }

    public func moved(
        to position: WorldPosition,
        tick: UInt64,
        regionSizeInChunks: Int = 8
    ) -> EntityPersistenceState {
        EntityPersistenceState(
            id: id,
            kind: kind,
            displayName: displayName,
            worldPosition: position,
            regionSizeInChunks: regionSizeInChunks,
            stateVersion: stateVersion,
            lastModifiedTick: tick,
            tags: tags,
            components: components,
            isRemoved: isRemoved
        )
    }

    public func removed(at tick: UInt64) -> EntityPersistenceState {
        EntityPersistenceState(
            id: id,
            kind: kind,
            displayName: displayName,
            worldPosition: worldPosition,
            chunk: chunk,
            region: region,
            stateVersion: stateVersion,
            lastModifiedTick: tick,
            tags: tags,
            components: components,
            isRemoved: true
        )
    }
}

public struct EntityStateStore: Hashable, Codable, Sendable {
    public let regionSizeInChunks: Int
    public let entities: [EntityPersistenceState]

    public init(
        regionSizeInChunks: Int = 8,
        entities: [EntityPersistenceState] = []
    ) {
        precondition(regionSizeInChunks > 0, "regionSizeInChunks must be positive.")

        self.regionSizeInChunks = regionSizeInChunks
        self.entities = Self.deduplicated(entities)
    }

    public func upserting(_ entity: EntityPersistenceState) -> EntityStateStore {
        EntityStateStore(
            regionSizeInChunks: regionSizeInChunks,
            entities: entities.filter { $0.id != entity.id } + [entity]
        )
    }

    public func removing(entityID: StableID, tick: UInt64) -> EntityStateStore {
        guard let entity = entities.first(where: { $0.id == entityID }) else {
            return self
        }

        return upserting(entity.removed(at: tick))
    }

    public func entity(id: StableID, includeRemoved: Bool = false) -> EntityPersistenceState? {
        entities.first { $0.id == id && (includeRemoved || !$0.isRemoved) }
    }

    public func entities(in region: RegionCoordinate, includeRemoved: Bool = false) -> [EntityPersistenceState] {
        entities.filter { entity in
            entity.region == region && (includeRemoved || !entity.isRemoved)
        }
    }

    public func chunkDelta(for coordinate: ChunkCoordinate, tick: UInt64) -> ChunkDelta {
        ChunkDelta(
            coordinate: coordinate,
            entityIDs: entities
                .filter { $0.chunk == coordinate }
                .map(\.id),
            lastModifiedTick: tick
        )
    }

    private static func deduplicated(_ entities: [EntityPersistenceState]) -> [EntityPersistenceState] {
        var byID: [StableID: EntityPersistenceState] = [:]

        for entity in entities {
            if let existing = byID[entity.id], existing.lastModifiedTick > entity.lastModifiedTick {
                continue
            }

            byID[entity.id] = entity
        }

        return byID.values.sorted { lhs, rhs in
            lhs.id.rawValue < rhs.id.rawValue
        }
    }
}
