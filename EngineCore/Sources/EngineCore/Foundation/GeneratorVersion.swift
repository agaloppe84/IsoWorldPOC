public struct GeneratorVersion: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int = 0, patch: Int = 0) {
        precondition(major >= 0, "major must be non-negative.")
        precondition(minor >= 0, "minor must be non-negative.")
        precondition(patch >= 0, "patch must be non-negative.")

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static let v1 = GeneratorVersion(major: 1)

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: GeneratorVersion, rhs: GeneratorVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

public struct GeneratorVersionEntry: Hashable, Codable, Sendable {
    public let domain: SeedDomain
    public let version: GeneratorVersion

    public init(domain: SeedDomain, version: GeneratorVersion) {
        self.domain = domain
        self.version = version
    }
}

public struct GeneratorVersionTable: Hashable, Codable, Sendable {
    public let entries: [GeneratorVersionEntry]

    public init(entries: [GeneratorVersionEntry] = []) {
        var versionsByDomain: [SeedDomain: GeneratorVersion] = [:]

        for entry in entries {
            versionsByDomain[entry.domain] = entry.version
        }

        self.entries = versionsByDomain
            .map { GeneratorVersionEntry(domain: $0.key, version: $0.value) }
            .sorted { $0.domain.rawValue < $1.domain.rawValue }
    }

    public func version(for domain: SeedDomain) -> GeneratorVersion {
        entries.first { $0.domain == domain }?.version ?? .v1
    }

    public func setting(_ version: GeneratorVersion, for domain: SeedDomain) -> GeneratorVersionTable {
        var updated = entries.filter { $0.domain != domain }
        updated.append(GeneratorVersionEntry(domain: domain, version: version))
        return GeneratorVersionTable(entries: updated)
    }
}

public extension GeneratorVersionTable {
    static let current = GeneratorVersionTable(entries: [
        GeneratorVersionEntry(domain: .worldDNA, version: .v1),
        GeneratorVersionEntry(domain: .terrain, version: .v1),
        GeneratorVersionEntry(domain: .biomes, version: .v1),
        GeneratorVersionEntry(domain: .render, version: .v1),
        GeneratorVersionEntry(domain: .rpg, version: .v1),
        GeneratorVersionEntry(domain: .style, version: .v1),
        GeneratorVersionEntry(domain: .chunks, version: .v1),
        GeneratorVersionEntry(domain: .props, version: .v1),
        GeneratorVersionEntry(domain: .entities, version: .v1),
        GeneratorVersionEntry(domain: .characters, version: .v1),
        GeneratorVersionEntry(domain: .animation, version: .v1),
    ])
}
