public struct EngineVersion: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        precondition(major >= 0, "major must be non-negative.")
        precondition(minor >= 0, "minor must be non-negative.")
        precondition(patch >= 0, "patch must be non-negative.")

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static let current = EngineVersion(major: 0, minor: 3, patch: 0)

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: EngineVersion, rhs: EngineVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}
