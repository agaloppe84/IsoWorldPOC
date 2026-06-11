public struct DebugSnapshot: Equatable, Codable, Sendable {
    public let frameIndex: UInt64
    public let currentChunk: ChunkCoordinate?
    public let currentGroundChunk: ChunkCoordinate?
    public let activeChunkCount: Int
    public let visibleChunkCount: Int
    public let generatedChunkCount: Int
    public let cachedChunkCount: Int
    public let approximateTriangleCount: Int
    public let approximatePropCount: Int
    public let jobs: JobSchedulerSnapshot
    public let chunksReadyForUpload: Int
    public let chunkUploadsThisFrame: Int
    public let averageChunkDataGenerationTimeMs: Float?

    public init(
        frameIndex: UInt64,
        currentChunk: ChunkCoordinate? = nil,
        currentGroundChunk: ChunkCoordinate? = nil,
        activeChunkCount: Int = 0,
        visibleChunkCount: Int = 0,
        generatedChunkCount: Int = 0,
        cachedChunkCount: Int = 0,
        approximateTriangleCount: Int = 0,
        approximatePropCount: Int = 0,
        jobs: JobSchedulerSnapshot = JobSchedulerSnapshot(
            activeJobCount: 0,
            submittedJobCount: 0,
            succeededJobCount: 0,
            cancelledJobCount: 0,
            failedJobCount: 0
        ),
        chunksReadyForUpload: Int = 0,
        chunkUploadsThisFrame: Int = 0,
        averageChunkDataGenerationTimeMs: Float? = nil
    ) {
        self.frameIndex = frameIndex
        self.currentChunk = currentChunk
        self.currentGroundChunk = currentGroundChunk
        self.activeChunkCount = activeChunkCount
        self.visibleChunkCount = visibleChunkCount
        self.generatedChunkCount = generatedChunkCount
        self.cachedChunkCount = cachedChunkCount
        self.approximateTriangleCount = approximateTriangleCount
        self.approximatePropCount = approximatePropCount
        self.jobs = jobs
        self.chunksReadyForUpload = chunksReadyForUpload
        self.chunkUploadsThisFrame = chunkUploadsThisFrame
        self.averageChunkDataGenerationTimeMs = averageChunkDataGenerationTimeMs
    }
}
