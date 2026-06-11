public struct JobHandle<Output: Sendable>: Sendable {
    public let id: EngineJobID
    public let name: String
    public let priority: JobPriority
    public let cancellationToken: CancellationToken

    private let task: Task<Output, Error>

    init(
        id: EngineJobID,
        name: String,
        priority: JobPriority,
        cancellationToken: CancellationToken,
        task: Task<Output, Error>
    ) {
        self.id = id
        self.name = name
        self.priority = priority
        self.cancellationToken = cancellationToken
        self.task = task
    }

    public var isCancelled: Bool {
        cancellationToken.isCancelled || task.isCancelled
    }

    public func cancel() {
        cancellationToken.cancel()
        task.cancel()
    }

    public func value() async throws -> Output {
        try await task.value
    }
}
