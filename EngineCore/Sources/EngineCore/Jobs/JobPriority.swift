public enum JobPriority: Int, CaseIterable, Codable, Comparable, Sendable {
    case background = 0
    case utility = 1
    case userInitiated = 2
    case critical = 3

    public var taskPriority: TaskPriority {
        switch self {
        case .background:
            .background
        case .utility:
            .utility
        case .userInitiated:
            .userInitiated
        case .critical:
            .high
        }
    }

    public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
