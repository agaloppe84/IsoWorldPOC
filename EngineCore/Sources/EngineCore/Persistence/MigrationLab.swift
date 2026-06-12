import Foundation

public struct MigrationCorpusSample: Hashable, Codable, Sendable {
    public let sampleID: String
    public let sourceVersion: SaveVersion
    public let mode: SaveMigrationMode

    public init(
        sampleID: String,
        sourceVersion: SaveVersion,
        mode: SaveMigrationMode = .migrated
    ) {
        precondition(!sampleID.isEmpty, "sampleID cannot be empty.")

        self.sampleID = sampleID
        self.sourceVersion = sourceVersion
        self.mode = mode
    }
}

public struct MigrationLabReport: Hashable, Codable, Sendable {
    public let checkedSamples: Int
    public let readySamples: Int
    public let blockedSamples: Int
    public let migratedSystems: [String]

    public var isReady: Bool {
        checkedSamples > 0 && blockedSamples == 0
    }
}

public struct MigrationLab: Sendable {
    private let manager: MigrationManager

    public init(manager: MigrationManager = MigrationManager()) {
        self.manager = manager
    }

    public func run(
        samples: [MigrationCorpusSample],
        targetVersion: SaveVersion = .current
    ) -> MigrationLabReport {
        let plans = samples.map { sample in
            manager.plan(from: sample.sourceVersion, to: targetVersion, mode: sample.mode)
        }
        let readyPlans = plans.filter(\.isExecutable)
        let migratedSystems = Array(Set(plans.flatMap { $0.rules.map(\.systemID) })).sorted()

        return MigrationLabReport(
            checkedSamples: samples.count,
            readySamples: readyPlans.count,
            blockedSamples: plans.count - readyPlans.count,
            migratedSystems: migratedSystems
        )
    }
}
