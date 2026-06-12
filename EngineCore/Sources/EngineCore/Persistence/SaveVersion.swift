public struct SaveVersion: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let formatVersion: Int
    public let schemaVersion: Int

    public init(formatVersion: Int, schemaVersion: Int) {
        precondition(formatVersion > 0, "formatVersion must be positive.")
        precondition(schemaVersion > 0, "schemaVersion must be positive.")

        self.formatVersion = formatVersion
        self.schemaVersion = schemaVersion
    }

    public static let current = SaveVersion(formatVersion: 1, schemaVersion: 2)

    public var description: String {
        "format-\(formatVersion).schema-\(schemaVersion)"
    }

    public static func < (lhs: SaveVersion, rhs: SaveVersion) -> Bool {
        if lhs.formatVersion != rhs.formatVersion {
            return lhs.formatVersion < rhs.formatVersion
        }

        return lhs.schemaVersion < rhs.schemaVersion
    }
}
