public struct ChunkStreamingPlan: Equatable, Sendable {
    public let currentChunk: ChunkCoordinate
    public let activeRadius: Int
    public let requiredChunks: Set<ChunkCoordinate>
    public let chunksToLoad: Set<ChunkCoordinate>
    public let chunksToUnload: Set<ChunkCoordinate>
    public let chunksToKeep: Set<ChunkCoordinate>

    public init(
        currentChunk: ChunkCoordinate,
        activeRadius: Int,
        requiredChunks: Set<ChunkCoordinate>,
        chunksToLoad: Set<ChunkCoordinate>,
        chunksToUnload: Set<ChunkCoordinate>,
        chunksToKeep: Set<ChunkCoordinate>
    ) {
        self.currentChunk = currentChunk
        self.activeRadius = activeRadius
        self.requiredChunks = requiredChunks
        self.chunksToLoad = chunksToLoad
        self.chunksToUnload = chunksToUnload
        self.chunksToKeep = chunksToKeep
    }
}

public struct ChunkStreamingPlanner: Sendable {
    public let activeRadius: Int

    public init(activeRadius: Int) {
        precondition(activeRadius >= 0, "activeRadius must be zero or positive.")

        self.activeRadius = activeRadius
    }

    public func plan(
        currentChunk: ChunkCoordinate,
        loadedChunks: Set<ChunkCoordinate>
    ) -> ChunkStreamingPlan {
        let requiredChunks = requiredChunks(around: currentChunk)

        return ChunkStreamingPlan(
            currentChunk: currentChunk,
            activeRadius: activeRadius,
            requiredChunks: requiredChunks,
            chunksToLoad: requiredChunks.subtracting(loadedChunks),
            chunksToUnload: loadedChunks.subtracting(requiredChunks),
            chunksToKeep: loadedChunks.intersection(requiredChunks)
        )
    }

    public func requiredChunks(around currentChunk: ChunkCoordinate) -> Set<ChunkCoordinate> {
        var chunks = Set<ChunkCoordinate>()
        chunks.reserveCapacity((activeRadius * 2 + 1) * (activeRadius * 2 + 1))

        for deltaZ in (-activeRadius)...activeRadius {
            for deltaX in (-activeRadius)...activeRadius {
                chunks.insert(
                    ChunkCoordinate(
                        x: currentChunk.x + deltaX,
                        y: currentChunk.y,
                        z: currentChunk.z + deltaZ
                    )
                )
            }
        }

        return chunks
    }
}
