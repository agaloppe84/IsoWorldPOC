import Foundation

public struct EngineJobID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String {
        rawValue.uuidString
    }
}

public struct EngineJob<Output: Sendable>: Sendable {
    public typealias Operation = @Sendable (CancellationToken) async throws -> Output

    public let id: EngineJobID
    public let name: String
    public let priority: JobPriority
    public let operation: Operation

    public init(
        id: EngineJobID = EngineJobID(),
        name: String,
        priority: JobPriority = .utility,
        operation: @escaping Operation
    ) {
        precondition(!name.isEmpty, "EngineJob name cannot be empty.")

        self.id = id
        self.name = name
        self.priority = priority
        self.operation = operation
    }
}
