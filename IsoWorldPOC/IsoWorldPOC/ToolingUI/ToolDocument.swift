import Foundation

struct ToolDocument: Codable, Equatable, Identifiable {
    var id: UUID
    var toolID: String
    var seedText: String
    var presetName: String
    var sampleCount: Int
    var notes: String

    init(
        id: UUID = UUID(),
        toolID: String,
        seedText: String,
        presetName: String,
        sampleCount: Int,
        notes: String = ""
    ) {
        self.id = id
        self.toolID = toolID
        self.seedText = seedText
        self.presetName = presetName
        self.sampleCount = sampleCount
        self.notes = notes
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
}

struct ToolValidationReport: Codable, Equatable {
    let toolID: String
    let issues: [ToolValidationIssue]

    var isValid: Bool {
        !issues.contains { $0.severity == .error }
    }
}
