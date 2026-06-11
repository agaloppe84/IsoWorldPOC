import Foundation

public struct JobSchedulerSnapshot: Equatable, Codable, Sendable {
    public let activeJobCount: Int
    public let submittedJobCount: Int
    public let succeededJobCount: Int
    public let cancelledJobCount: Int
    public let failedJobCount: Int

    public init(
        activeJobCount: Int,
        submittedJobCount: Int,
        succeededJobCount: Int,
        cancelledJobCount: Int,
        failedJobCount: Int
    ) {
        self.activeJobCount = activeJobCount
        self.submittedJobCount = submittedJobCount
        self.succeededJobCount = succeededJobCount
        self.cancelledJobCount = cancelledJobCount
        self.failedJobCount = failedJobCount
    }
}

public final class JobScheduler: @unchecked Sendable {
    private struct ScheduledJob: Sendable {
        let id: EngineJobID
        let name: String
        let priority: JobPriority
        let cancel: @Sendable () -> Void
    }

    private enum CompletionOutcome: Sendable {
        case succeeded
        case cancelled
        case failed
    }

    private let lock = NSLock()
    private var jobs: [EngineJobID: ScheduledJob] = [:]
    private var submittedJobCount = 0
    private var succeededJobCount = 0
    private var cancelledJobCount = 0
    private var failedJobCount = 0

    public init() {}

    public var activeJobCount: Int {
        lock.lock()
        defer { lock.unlock() }

        return jobs.count
    }

    public var snapshot: JobSchedulerSnapshot {
        lock.lock()
        defer { lock.unlock() }

        return JobSchedulerSnapshot(
            activeJobCount: jobs.count,
            submittedJobCount: submittedJobCount,
            succeededJobCount: succeededJobCount,
            cancelledJobCount: cancelledJobCount,
            failedJobCount: failedJobCount
        )
    }

    public func submit<Output: Sendable>(_ job: EngineJob<Output>) -> JobHandle<Output> {
        let cancellationToken = CancellationToken()
        let task = Task.detached(priority: job.priority.taskPriority) {
            try cancellationToken.checkCancellation()
            return try await job.operation(cancellationToken)
        }
        let handle = JobHandle(
            id: job.id,
            name: job.name,
            priority: job.priority,
            cancellationToken: cancellationToken,
            task: task
        )

        store(
            ScheduledJob(
                id: job.id,
                name: job.name,
                priority: job.priority,
                cancel: { handle.cancel() }
            )
        )

        Task.detached(priority: .background) { [weak self] in
            let result = await task.result
            self?.finish(job.id, outcome: Self.outcome(for: result))
        }

        return handle
    }

    public func cancel(_ id: EngineJobID) {
        lock.lock()
        let job = jobs[id]
        lock.unlock()

        job?.cancel()
    }

    public func cancelAll() {
        lock.lock()
        let activeJobs = Array(jobs.values)
        lock.unlock()

        for job in activeJobs {
            job.cancel()
        }
    }

    private func store(_ job: ScheduledJob) {
        lock.lock()
        jobs[job.id] = job
        submittedJobCount += 1
        lock.unlock()
    }

    private func finish(_ id: EngineJobID, outcome: CompletionOutcome) {
        lock.lock()
        guard jobs.removeValue(forKey: id) != nil else {
            lock.unlock()
            return
        }

        switch outcome {
        case .succeeded:
            succeededJobCount += 1
        case .cancelled:
            cancelledJobCount += 1
        case .failed:
            failedJobCount += 1
        }

        lock.unlock()
    }

    private static func outcome<Output>(for result: Result<Output, Error>) -> CompletionOutcome {
        switch result {
        case .success:
            .succeeded
        case .failure(let error):
            isCancellation(error) ? .cancelled : .failed
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is JobCancellationError || error is CancellationError
    }
}
