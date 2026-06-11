public struct EngineFrameSnapshot: Equatable, Codable, Sendable {
    public let frameIndex: UInt64
    public let worldSeed: WorldSeed
    public let simulationTime: Float
    public let deltaTime: Float
    public let render: RenderWorldSnapshot
    public let debug: DebugSnapshot

    public init(
        frameIndex: UInt64,
        worldSeed: WorldSeed,
        simulationTime: Float,
        deltaTime: Float,
        render: RenderWorldSnapshot,
        debug: DebugSnapshot
    ) {
        precondition(deltaTime >= 0, "deltaTime must be non-negative.")

        self.frameIndex = frameIndex
        self.worldSeed = worldSeed
        self.simulationTime = simulationTime
        self.deltaTime = deltaTime
        self.render = render
        self.debug = debug
    }
}
