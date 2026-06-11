import EngineCore
import Foundation

struct WorldPrepareRequest: Equatable, Sendable {
    static let fallbackSeed = "isoworld-seed-001"

    let seedText: String
    let initialChunkRadius: Int

    init(seedText: String, initialChunkRadius: Int = 2) {
        self.seedText = seedText
        self.initialChunkRadius = max(initialChunkRadius, 0)
    }

    var normalizedSeed: String {
        let trimmedSeed = seedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSeed.isEmpty ? Self.fallbackSeed : trimmedSeed
    }
}

enum WorldPrepareError: LocalizedError, Sendable {
    case noValidSpawn
    case openRequirementsFailed([String])

    var errorDescription: String? {
        switch self {
        case .noValidSpawn:
            return "No valid player spawn could be resolved."
        case let .openRequirementsFailed(reasons):
            return reasons.joined(separator: "\n")
        }
    }
}

actor WorldPreparePipeline {
    private let jobScheduler: JobScheduler
    private let phasePlan = WorldPreparePhasePlan.v1

    init(jobScheduler: JobScheduler = JobScheduler()) {
        self.jobScheduler = jobScheduler
    }

    func prepareWorld(
        seed: String,
        progress: @MainActor @Sendable (LoadingProgress) -> Void
    ) async throws -> WorldSession {
        try await prepareWorld(
            request: WorldPrepareRequest(seedText: seed),
            progress: progress
        )
    }

    func prepareWorld(
        request: WorldPrepareRequest,
        progress: @MainActor @Sendable (LoadingProgress) -> Void
    ) async throws -> WorldSession {
        let seed = request.normalizedSeed

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .validateSeed,
            phaseProgress: 1,
            detail: "Seed normalized"
        ) { progress($0) }

        try Task.checkCancellation()
        let worldSeed = worldSeed(from: seed)
        await publish(
            seed: seed,
            phaseID: .worldDNA,
            phaseProgress: 0,
            detail: "Creating deterministic WorldDNA"
        ) { progress($0) }
        let dna = WorldDNA.make(worldSeed: worldSeed)
        await publish(
            seed: seed,
            phaseID: .worldDNA,
            phaseProgress: 1,
            detail: "WorldDNA ready"
        ) { progress($0) }

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .initializeRules,
            phaseProgress: 0,
            detail: "Initializing terrain, biome and prop rules"
        ) { progress($0) }
        let terrainSystem = TerrainSystem(seed: worldSeed)
        let biomeSystem = BiomeSystem(seed: worldSeed, biomeDNA: dna.biomes)
        _ = PropCatalog.naturalV1
        await publish(
            seed: seed,
            phaseID: .initializeRules,
            phaseProgress: 1,
            detail: "World rules ready"
        ) { progress($0) }

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .terrainFields,
            phaseProgress: 0,
            detail: "Preparing origin terrain sample grid"
        ) { progress($0) }
        let spawnTerrainGrid = terrainSystem.sampleGrid(for: .origin)
        _ = spawnTerrainGrid.validationReport
        await publish(
            seed: seed,
            phaseID: .terrainFields,
            phaseProgress: 1,
            detail: "Terrain fields ready"
        ) { progress($0) }

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .biomeFields,
            phaseProgress: 0,
            detail: "Resolving origin biome fields"
        ) { progress($0) }
        let spawnBiomeData = biomeSystem.chunkData(
            for: .origin,
            terrainSystem: terrainSystem
        )
        await publish(
            seed: seed,
            phaseID: .biomeFields,
            phaseProgress: 1,
            detail: "Biome fields ready"
        ) { progress($0) }

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .playerSpawn,
            phaseProgress: 0,
            detail: "Searching safe spawn"
        ) { progress($0) }
        let spawnPosition = try resolveSpawn(
            terrainGrid: spawnTerrainGrid,
            biomeData: spawnBiomeData
        )
        await publish(
            seed: seed,
            phaseID: .playerSpawn,
            phaseProgress: 1,
            detail: "Spawn ready"
        ) { progress($0) }

        try Task.checkCancellation()
        let requiredCoordinates = initialChunkCoordinates(radius: request.initialChunkRadius)
        let initialChunks = try await generateInitialChunks(
            coordinates: requiredCoordinates,
            worldSeed: worldSeed,
            seed: seed,
            progress: progress
        )

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .renderPayloads,
            phaseProgress: 0,
            detail: "Validating CPU render payloads"
        ) { progress($0) }
        let hasRenderPayloads = hasRenderablePayloads(initialChunks)
        await publish(
            seed: seed,
            phaseID: .renderPayloads,
            phaseProgress: 1,
            detail: hasRenderPayloads ? "Render payloads ready" : "Render payloads incomplete"
        ) { progress($0) }

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .collisionBootstrap,
            phaseProgress: 0,
            detail: "Building minimal traversal bootstrap"
        ) { progress($0) }
        let hasCollisionBootstrap = hasCollisionBootstrap(
            spawnPosition: spawnPosition,
            chunks: initialChunks
        )
        await publish(
            seed: seed,
            phaseID: .collisionBootstrap,
            phaseProgress: 1,
            detail: hasCollisionBootstrap ? "Collision bootstrap ready" : "Collision bootstrap incomplete"
        ) { progress($0) }

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .rendererWarmup,
            phaseProgress: 1,
            detail: "Renderer warmup payload ready"
        ) { progress($0) }

        let requirements = WorldOpenRequirements(
            normalizedSeed: seed,
            worldSeed: worldSeed,
            initialChunkRadius: request.initialChunkRadius,
            requiredInitialChunkCount: requiredCoordinates.count,
            preparedChunkCount: initialChunks.count,
            missingInitialChunks: missingCoordinates(
                required: requiredCoordinates,
                chunks: initialChunks
            ),
            spawnPosition: spawnPosition,
            hasWorldDNA: true,
            hasWorldRules: true,
            hasRenderPayloads: hasRenderPayloads,
            hasCollisionBootstrap: hasCollisionBootstrap,
            hasRendererWarmupPayload: hasRenderPayloads
        )

        guard requirements.isSatisfied else {
            throw WorldPrepareError.openRequirementsFailed(requirements.blockingReasons)
        }

        try Task.checkCancellation()
        await publish(
            seed: seed,
            phaseID: .openSession,
            phaseProgress: 1,
            detail: "World session committed",
            canCancel: false
        ) { progress($0) }

        return WorldSession(
            seed: seed,
            worldSeed: worldSeed,
            dna: dna,
            spawnPosition: spawnPosition,
            initialChunkRadius: request.initialChunkRadius,
            initialChunks: initialChunks,
            openRequirements: requirements
        )
    }

    private func generateInitialChunks(
        coordinates: [ChunkCoordinate],
        worldSeed: WorldSeed,
        seed: String,
        progress: @MainActor @Sendable (LoadingProgress) -> Void
    ) async throws -> [ProceduralChunkData] {
        await publish(
            seed: seed,
            phaseID: .initialChunks,
            phaseProgress: 0,
            detail: "Generating \(coordinates.count) initial chunks"
        ) { progress($0) }

        let handles = coordinates.map { coordinate in
            jobScheduler.submit(EngineJob<ProceduralChunkData>(
                name: "prepare-initial-chunk-\(coordinate.x)-\(coordinate.z)",
                priority: .userInitiated
            ) { cancellationToken in
                try ProceduralChunkDataFactory.makeChunkData(
                    coordinate: coordinate,
                    worldSeed: worldSeed,
                    cancellationToken: cancellationToken
                )
            })
        }

        return try await withTaskCancellationHandler {
            var chunks: [ProceduralChunkData] = []
            chunks.reserveCapacity(coordinates.count)

            do {
                for (index, handle) in handles.enumerated() {
                    try Task.checkCancellation()
                    chunks.append(try await handle.value())
                    await publish(
                        seed: seed,
                        phaseID: .initialChunks,
                        phaseProgress: Double(index + 1) / Double(max(coordinates.count, 1)),
                        detail: "Generated chunk \(index + 1)/\(coordinates.count)"
                    ) { progress($0) }
                }
            } catch {
                for handle in handles {
                    handle.cancel()
                }

                throw error
            }

            return chunks.sorted { first, second in
                isCoordinate(first.coordinate, orderedBefore: second.coordinate)
            }
        } onCancel: {
            for handle in handles {
                handle.cancel()
            }
        }
    }

    private func resolveSpawn(
        terrainGrid: TerrainSampleGrid,
        biomeData: BiomeChunkData
    ) throws -> WorldPosition {
        let center = Float(terrainGrid.resolution - 1) * 0.5
        let biomeSamplesByLocal = Dictionary(
            uniqueKeysWithValues: biomeData.samples.map { sample in
                ("\(sample.localX):\(sample.localZ)", sample.weights.primaryBiomeType)
            }
        )
        let rankedSamples = terrainGrid.samples.sorted { first, second in
            spawnScore(
                sample: first,
                primaryBiome: biomeSamplesByLocal["\(first.localX):\(first.localZ)"],
                center: center
            ) > spawnScore(
                sample: second,
                primaryBiome: biomeSamplesByLocal["\(second.localX):\(second.localZ)"],
                center: center
            )
        }

        guard let sample = rankedSamples.first(where: { $0.walkability >= 0.45 }) ?? rankedSamples.first else {
            throw WorldPrepareError.noValidSpawn
        }

        let origin = ProceduralChunkDataFactory.origin(for: terrainGrid.coordinate)

        return WorldPosition(
            x: origin.x + Float(sample.localX) * ProceduralChunkDataFactory.horizontalScale,
            y: sample.height * ProceduralChunkDataFactory.verticalScale + 0.02,
            z: origin.z + Float(sample.localZ) * ProceduralChunkDataFactory.horizontalScale
        )
    }

    private func spawnScore(
        sample: TerrainSample,
        primaryBiome: BiomeType?,
        center: Float
    ) -> Float {
        let dx = Float(sample.localX) - center
        let dz = Float(sample.localZ) - center
        let distancePenalty = (dx * dx + dz * dz).squareRoot() / max(center, 1)
        let biomePenalty: Float = primaryBiome == .freshwater ? 0.35 : 0

        return sample.walkability - sample.slope * 0.25 - distancePenalty * 0.20 - biomePenalty
    }

    private func hasRenderablePayloads(_ chunks: [ProceduralChunkData]) -> Bool {
        !chunks.isEmpty && chunks.allSatisfy { chunk in
            !chunk.meshPositions.isEmpty &&
                !chunk.meshNormals.isEmpty &&
                !chunk.meshTextureCoordinates.isEmpty &&
                !chunk.meshIndices.isEmpty &&
                chunk.terrainVertexMaterials.count == chunk.meshPositions.count
        }
    }

    private func hasCollisionBootstrap(
        spawnPosition: WorldPosition,
        chunks: [ProceduralChunkData]
    ) -> Bool {
        let spawnChunk = ChunkCoordinate(
            x: Int(((spawnPosition.x + ProceduralChunkDataFactory.chunkWorldSize * 0.5) /
                ProceduralChunkDataFactory.chunkWorldSize).rounded(.down)),
            y: 0,
            z: Int(((spawnPosition.z + ProceduralChunkDataFactory.chunkWorldSize * 0.5) /
                ProceduralChunkDataFactory.chunkWorldSize).rounded(.down))
        )

        guard let chunk = chunks.first(where: { $0.coordinate == spawnChunk }) else {
            return false
        }

        let sampler = TerrainSampler(
            geometry: chunk.terrainGeometry,
            originX: chunk.originX,
            originZ: chunk.originZ
        )

        return sampler
            .sampleAt(x: spawnPosition.x, z: spawnPosition.z)
            .isWalkable(maxSlope: 0.65)
    }

    private func initialChunkCoordinates(radius: Int) -> [ChunkCoordinate] {
        var coordinates: [ChunkCoordinate] = []
        coordinates.reserveCapacity((radius * 2 + 1) * (radius * 2 + 1))

        for z in (-radius)...radius {
            for x in (-radius)...radius {
                coordinates.append(ChunkCoordinate(x: x, y: 0, z: z))
            }
        }

        return coordinates.sorted { first, second in
            let firstDistance = abs(first.x) + abs(first.z)
            let secondDistance = abs(second.x) + abs(second.z)

            if firstDistance != secondDistance {
                return firstDistance < secondDistance
            }

            return isCoordinate(first, orderedBefore: second)
        }
    }

    private func missingCoordinates(
        required: [ChunkCoordinate],
        chunks: [ProceduralChunkData]
    ) -> [ChunkCoordinate] {
        let prepared = Set(chunks.map(\.coordinate))
        return required.filter { !prepared.contains($0) }
    }

    private func isCoordinate(
        _ first: ChunkCoordinate,
        orderedBefore second: ChunkCoordinate
    ) -> Bool {
        if first.z != second.z {
            return first.z < second.z
        }

        if first.x != second.x {
            return first.x < second.x
        }

        return first.y < second.y
    }

    private func publish(
        seed: String,
        phaseID: WorldPreparePhaseID,
        phaseProgress: Double?,
        detail: String,
        warnings: [LoadingWarning] = [],
        canCancel: Bool = true,
        progress: @MainActor @Sendable (LoadingProgress) -> Void
    ) async {
        let phase = phasePlan.phase(for: phaseID)
        let update = LoadingProgress(
            seed: seed,
            title: "Preparing World",
            currentPhase: phaseID,
            phaseName: phase.name,
            phaseProgress: phaseProgress,
            globalProgress: phasePlan.globalProgress(
                for: phaseID,
                phaseProgress: phaseProgress
            ),
            detail: detail,
            warnings: warnings,
            canCancel: canCancel
        )

        await progress(update)
    }

    private func worldSeed(from seed: String) -> WorldSeed {
        WorldSeed(StableHash.make { builder in
            builder.combine(seed)
        }.value)
    }
}
