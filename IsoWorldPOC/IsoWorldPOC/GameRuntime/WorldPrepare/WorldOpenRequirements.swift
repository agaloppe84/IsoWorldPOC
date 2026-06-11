import EngineCore

struct WorldOpenRequirements: Equatable, Sendable {
    let normalizedSeed: String
    let worldSeed: WorldSeed
    let initialChunkRadius: Int
    let requiredInitialChunkCount: Int
    let preparedChunkCount: Int
    let missingInitialChunks: [ChunkCoordinate]
    let spawnPosition: WorldPosition?
    let hasWorldDNA: Bool
    let hasWorldRules: Bool
    let hasRenderPayloads: Bool
    let hasCollisionBootstrap: Bool
    let hasRendererWarmupPayload: Bool

    var isSatisfied: Bool {
        blockingReasons.isEmpty
    }

    var blockingReasons: [String] {
        var reasons: [String] = []

        if normalizedSeed.isEmpty {
            reasons.append("Seed is empty.")
        }

        if !hasWorldDNA {
            reasons.append("WorldDNA was not generated.")
        }

        if !hasWorldRules {
            reasons.append("World rules were not initialized.")
        }

        if preparedChunkCount < requiredInitialChunkCount || !missingInitialChunks.isEmpty {
            reasons.append("Initial chunk set is incomplete.")
        }

        if spawnPosition == nil {
            reasons.append("No valid player spawn was resolved.")
        }

        if !hasRenderPayloads {
            reasons.append("Initial render payloads are not ready.")
        }

        if !hasCollisionBootstrap {
            reasons.append("Minimal collision bootstrap is not ready.")
        }

        if !hasRendererWarmupPayload {
            reasons.append("Renderer warmup payload is not ready.")
        }

        return reasons
    }
}
