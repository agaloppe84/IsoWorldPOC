import Foundation

public enum SaveMigrationMode: String, CaseIterable, Codable, Sendable {
    case strict
    case migrated
    case regenerated
}

public enum SaveMigrationPlanStatus: String, CaseIterable, Codable, Sendable {
    case notNeeded
    case ready
    case blocked
}

public struct SaveMigrationRule: Hashable, Codable, Sendable {
    public let systemID: String
    public let sourceVersion: SaveVersion
    public let targetVersion: SaveVersion
    public let description: String
    public let requiresBackup: Bool
    public let allowsRegeneration: Bool

    public init(
        systemID: String,
        sourceVersion: SaveVersion,
        targetVersion: SaveVersion,
        description: String,
        requiresBackup: Bool = true,
        allowsRegeneration: Bool = false
    ) {
        precondition(!systemID.isEmpty, "systemID cannot be empty.")
        precondition(!description.isEmpty, "description cannot be empty.")
        precondition(sourceVersion < targetVersion, "Migration rules must move forward.")

        self.systemID = systemID
        self.sourceVersion = sourceVersion
        self.targetVersion = targetVersion
        self.description = description
        self.requiresBackup = requiresBackup
        self.allowsRegeneration = allowsRegeneration
    }
}

public struct SaveMigrationPlan: Hashable, Codable, Sendable {
    public let sourceVersion: SaveVersion
    public let targetVersion: SaveVersion
    public let mode: SaveMigrationMode
    public let status: SaveMigrationPlanStatus
    public let rules: [SaveMigrationRule]
    public let requiresBackup: Bool
    public let issues: [String]

    public init(
        sourceVersion: SaveVersion,
        targetVersion: SaveVersion,
        mode: SaveMigrationMode,
        status: SaveMigrationPlanStatus,
        rules: [SaveMigrationRule] = [],
        requiresBackup: Bool = false,
        issues: [String] = []
    ) {
        precondition(sourceVersion <= targetVersion, "Save migrations cannot downgrade saves.")

        self.sourceVersion = sourceVersion
        self.targetVersion = targetVersion
        self.mode = mode
        self.status = status
        self.rules = rules
        self.requiresBackup = requiresBackup
        self.issues = issues
    }

    public var isExecutable: Bool {
        status == .ready || status == .notNeeded
    }
}

public struct SaveMigrationReport: Hashable, Codable, Sendable {
    public let plan: SaveMigrationPlan
    public let migratedAt: Date
    public let success: Bool
    public let migratedSystems: [String]
    public let issues: [String]

    public init(
        plan: SaveMigrationPlan,
        migratedAt: Date = Date(),
        success: Bool,
        migratedSystems: [String],
        issues: [String] = []
    ) {
        self.plan = plan
        self.migratedAt = migratedAt
        self.success = success
        self.migratedSystems = Self.uniquedStable(migratedSystems)
        self.issues = issues
    }

    private static func uniquedStable(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values where !value.isEmpty && seen.insert(value).inserted {
            result.append(value)
        }

        return result
    }
}

public struct MigrationManager: Hashable, Codable, Sendable {
    public let rules: [SaveMigrationRule]

    public init(rules: [SaveMigrationRule] = Self.defaultRules) {
        self.rules = rules.sorted { lhs, rhs in
            if lhs.sourceVersion != rhs.sourceVersion { return lhs.sourceVersion < rhs.sourceVersion }
            if lhs.targetVersion != rhs.targetVersion { return lhs.targetVersion < rhs.targetVersion }
            return lhs.systemID < rhs.systemID
        }
    }

    public func plan(
        from sourceVersion: SaveVersion,
        to targetVersion: SaveVersion = .current,
        mode: SaveMigrationMode = .migrated
    ) -> SaveMigrationPlan {
        precondition(sourceVersion <= targetVersion, "Save migrations cannot downgrade saves.")

        guard sourceVersion != targetVersion else {
            return SaveMigrationPlan(
                sourceVersion: sourceVersion,
                targetVersion: targetVersion,
                mode: mode,
                status: .notNeeded
            )
        }

        switch mode {
        case .strict:
            return SaveMigrationPlan(
                sourceVersion: sourceVersion,
                targetVersion: targetVersion,
                mode: mode,
                status: .blocked,
                issues: ["Save version \(sourceVersion) must match \(targetVersion) in strict mode."]
            )
        case .migrated:
            return migrationPlan(from: sourceVersion, to: targetVersion, mode: mode)
        case .regenerated:
            return SaveMigrationPlan(
                sourceVersion: sourceVersion,
                targetVersion: targetVersion,
                mode: mode,
                status: .ready,
                rules: regenerationRules(from: sourceVersion, to: targetVersion),
                requiresBackup: true
            )
        }
    }

    public func report(
        for plan: SaveMigrationPlan,
        at date: Date = Date(),
        extraIssues: [String] = []
    ) -> SaveMigrationReport {
        let issues = plan.issues + extraIssues
        return SaveMigrationReport(
            plan: plan,
            migratedAt: date,
            success: plan.isExecutable && issues.isEmpty,
            migratedSystems: plan.rules.map(\.systemID),
            issues: issues
        )
    }

    private func migrationPlan(
        from sourceVersion: SaveVersion,
        to targetVersion: SaveVersion,
        mode: SaveMigrationMode
    ) -> SaveMigrationPlan {
        var current = sourceVersion
        var selectedRules: [SaveMigrationRule] = []
        var issues: [String] = []

        while current < targetVersion {
            guard let rule = rules.first(where: { $0.sourceVersion == current && $0.targetVersion <= targetVersion }) else {
                issues.append("Missing migration rule from \(current) toward \(targetVersion).")
                break
            }

            selectedRules.append(rule)
            current = rule.targetVersion
        }

        return SaveMigrationPlan(
            sourceVersion: sourceVersion,
            targetVersion: targetVersion,
            mode: mode,
            status: current == targetVersion ? .ready : .blocked,
            rules: selectedRules,
            requiresBackup: selectedRules.contains(where: \.requiresBackup),
            issues: issues
        )
    }

    private func regenerationRules(
        from sourceVersion: SaveVersion,
        to targetVersion: SaveVersion
    ) -> [SaveMigrationRule] {
        rules.filter {
            $0.sourceVersion >= sourceVersion &&
                $0.targetVersion <= targetVersion &&
                $0.allowsRegeneration
        }
    }
}

public extension MigrationManager {
    static let defaultRules = [
        SaveMigrationRule(
            systemID: "persistence.region-deltas",
            sourceVersion: SaveVersion(formatVersion: 1, schemaVersion: 1),
            targetVersion: SaveVersion(formatVersion: 1, schemaVersion: 2),
            description: "Introduce V2 region delta files, persistent entity state, journals, and project packages.",
            requiresBackup: true,
            allowsRegeneration: true
        )
    ]
}
