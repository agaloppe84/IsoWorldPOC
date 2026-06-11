import XCTest
@testable import EngineCore

final class JobSystemTests: XCTestCase {
    func testJobSchedulerCompletesSubmittedJob() async throws {
        let scheduler = JobScheduler()
        let handle = scheduler.submit(EngineJob<Int>(name: "unit-job", priority: .utility) { token in
            try token.checkCancellation()
            return 42
        })

        let value = try await handle.value()
        try await waitForSchedulerCleanup(scheduler)
        let snapshot = scheduler.snapshot

        XCTAssertEqual(value, 42)
        XCTAssertEqual(snapshot.activeJobCount, 0)
        XCTAssertEqual(snapshot.submittedJobCount, 1)
        XCTAssertEqual(snapshot.succeededJobCount, 1)
        XCTAssertEqual(snapshot.cancelledJobCount, 0)
        XCTAssertEqual(snapshot.failedJobCount, 0)
    }

    func testJobHandleCancelsRunningJob() async throws {
        let scheduler = JobScheduler()
        let handle = scheduler.submit(EngineJob<Int>(name: "cancel-job", priority: .background) { token in
            while true {
                try token.checkCancellation()
                try await Task.sleep(for: .milliseconds(1))
            }
        })

        handle.cancel()

        do {
            _ = try await handle.value()
            XCTFail("Cancelled job should not produce a value.")
        } catch {
            XCTAssertTrue(error is JobCancellationError || error is CancellationError)
        }

        try await waitForSchedulerCleanup(scheduler)
        XCTAssertEqual(scheduler.snapshot.cancelledJobCount, 1)
    }

    func testCancellationTokenCanBePolledWithoutAwaiting() {
        let token = CancellationToken()

        XCTAssertFalse(token.isCancelled)
        token.cancel()
        XCTAssertTrue(token.isCancelled)
        XCTAssertThrowsError(try token.checkCancellation()) { error in
            XCTAssertTrue(error is JobCancellationError)
        }
    }

    func testJobPrioritiesAreOrderedFromBackgroundToCritical() {
        XCTAssertLessThan(JobPriority.background, .utility)
        XCTAssertLessThan(JobPriority.utility, .userInitiated)
        XCTAssertLessThan(JobPriority.userInitiated, .critical)
    }

    private func waitForSchedulerCleanup(
        _ scheduler: JobScheduler,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0..<50 {
            if scheduler.snapshot.activeJobCount == 0 {
                return
            }

            try await Task.sleep(for: .milliseconds(2))
        }

        XCTFail("Scheduler did not clean up completed jobs.", file: file, line: line)
    }
}
