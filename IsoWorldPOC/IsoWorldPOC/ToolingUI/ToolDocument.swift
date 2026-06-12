import Foundation

struct ToolDocument: Codable, Equatable, Identifiable {
    var id: UUID
    var toolID: String
    var seedText: String
    var presetName: String
    var sampleCount: Int
    var notes: String
    var revisionID: String
    var packageReferences: [String]

    init(
        id: UUID = UUID(),
        toolID: String,
        seedText: String,
        presetName: String,
        sampleCount: Int,
        notes: String = "",
        revisionID: String = "initial",
        packageReferences: [String] = []
    ) {
        self.id = id
        self.toolID = toolID
        self.seedText = seedText
        self.presetName = presetName
        self.sampleCount = sampleCount
        self.notes = notes
        self.revisionID = revisionID
        self.packageReferences = Self.normalizedPackageReferences(packageReferences)
    }

    private static func normalizedPackageReferences(_ references: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for reference in references {
            let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else {
                continue
            }

            result.append(trimmed)
        }

        return result
    }
}

enum ToolValidationSeverity: String, Codable, Hashable, Identifiable {
    case info
    case warning
    case error

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .info:
            "Info"
        case .warning:
            "Warning"
        case .error:
            "Error"
        }
    }

    var systemImage: String {
        switch self {
        case .info:
            "info.circle"
        case .warning:
            "exclamationmark.triangle"
        case .error:
            "xmark.octagon"
        }
    }
}

struct ToolValidationIssue: Codable, Equatable, Identifiable {
    let id: String
    let severity: ToolValidationSeverity
    let message: String
    let fixHint: String?

    init(
        id: String,
        severity: ToolValidationSeverity,
        message: String,
        fixHint: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.fixHint = fixHint
    }
}

struct ToolValidationReport: Codable, Equatable {
    let toolID: String
    let issues: [ToolValidationIssue]

    var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }

    var blockingIssueCount: Int {
        issues.filter { $0.severity == .error }.count
    }
}
