import Foundation

public struct JobCancellationError: Error, Equatable, Sendable {
    public init() {}
}

public final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    public init() {}

    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }

        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    public func checkCancellation() throws {
        if isCancelled {
            throw JobCancellationError()
        }

        try Task.checkCancellation()
    }
}
