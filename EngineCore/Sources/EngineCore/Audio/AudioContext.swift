public struct AudioContext: Equatable, Hashable, Codable, Sendable {
    public let worldSeed: WorldSeed
    public let simulationTime: Float
    public let listenerPosition: WorldPosition?
    public let mixState: AudioMixState

    public init(
        worldSeed: WorldSeed,
        simulationTime: Float,
        listenerPosition: WorldPosition? = nil,
        mixState: AudioMixState = AudioMixState()
    ) {
        self.worldSeed = worldSeed
        self.simulationTime = max(simulationTime, 0)
        self.listenerPosition = listenerPosition
        self.mixState = mixState
    }

    public func surfaceResponse(
        for materialKind: TerrainMaterialKind,
        wetness: Float,
        friction: Float
    ) -> AudioSurfaceResponse {
        AudioSurfaceResponse.response(
            for: materialKind,
            wetness: wetness,
            friction: friction
        )
    }

    public func seed(
        sourceID: StableID,
        recipeID: AudioRecipeID,
        kind: IsoAudioEventKind,
        salt: UInt64 = 0
    ) -> UInt64 {
        StableHash.make { builder in
            builder.combine(worldSeed)
            builder.combine(SeedDomain.audio)
            builder.combine(sourceID.rawValue)
            builder.combine(recipeID.rawValue)
            builder.combine(kind.rawValue)
            builder.combine(salt)
        }.value
    }

    public func distanceMeters(to position: WorldPosition?) -> Float {
        guard let listenerPosition, let position else {
            return 0
        }

        let dx = listenerPosition.x - position.x
        let dy = listenerPosition.y - position.y
        let dz = listenerPosition.z - position.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }
}
