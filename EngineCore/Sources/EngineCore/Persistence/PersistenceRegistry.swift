public enum PersistenceDomain: String, CaseIterable, Codable, Sendable {
    case manifest
    case regionDeltas
    case eventJournal
    case snapshots
    case entityState
    case toolProjects
    case assetPackages
    case graphPackages
    case blobStore
    case sqliteIndex
    case generatedCaches
}

public struct PersistenceDomainDescriptor: Hashable, Codable, Sendable {
    public let domain: PersistenceDomain
    public let rootPath: String
    public let fileExtension: String?
    public let isAuthoritative: Bool
    public let isRebuildable: Bool

    public init(
        domain: PersistenceDomain,
        rootPath: String,
        fileExtension: String? = nil,
        isAuthoritative: Bool,
        isRebuildable: Bool
    ) {
        precondition(!rootPath.isEmpty, "Persistence rootPath cannot be empty.")
        precondition(
            fileExtension == nil || fileExtension?.isEmpty == false,
            "Persistence fileExtension cannot be empty."
        )

        self.domain = domain
        self.rootPath = rootPath
        self.fileExtension = fileExtension
        self.isAuthoritative = isAuthoritative
        self.isRebuildable = isRebuildable
    }
}

public struct PersistenceRegistry: Hashable, Codable, Sendable {
    public let descriptors: [PersistenceDomainDescriptor]

    public init(descriptors: [PersistenceDomainDescriptor]) {
        let domains = descriptors.map(\.domain)
        precondition(Set(domains).count == domains.count, "Persistence domains must be unique.")

        self.descriptors = descriptors.sorted { $0.domain.rawValue < $1.domain.rawValue }
    }

    public func descriptor(for domain: PersistenceDomain) -> PersistenceDomainDescriptor? {
        descriptors.first { $0.domain == domain }
    }

    public func rootPath(for domain: PersistenceDomain) -> String? {
        descriptor(for: domain)?.rootPath
    }

    public var authoritativeDomains: [PersistenceDomain] {
        descriptors
            .filter(\.isAuthoritative)
            .map(\.domain)
    }

    public var rebuildableDomains: [PersistenceDomain] {
        descriptors
            .filter(\.isRebuildable)
            .map(\.domain)
    }

    public static let productionV2 = PersistenceRegistry(descriptors: [
        PersistenceDomainDescriptor(
            domain: .manifest,
            rootPath: "manifest.json",
            fileExtension: "json",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .regionDeltas,
            rootPath: "regions",
            fileExtension: "isoregion",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .eventJournal,
            rootPath: "events/journal.json",
            fileExtension: "json",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .snapshots,
            rootPath: "snapshots",
            fileExtension: "isosnapshot",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .entityState,
            rootPath: "entities/state.isoentity",
            fileExtension: "isoentity",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .toolProjects,
            rootPath: "projects",
            fileExtension: "isoproj",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .assetPackages,
            rootPath: "assets",
            fileExtension: "isoasset",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .graphPackages,
            rootPath: "graphs",
            fileExtension: "isograph",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .blobStore,
            rootPath: "blobs",
            isAuthoritative: true,
            isRebuildable: false
        ),
        PersistenceDomainDescriptor(
            domain: .sqliteIndex,
            rootPath: "state.sqlite",
            fileExtension: "sqlite",
            isAuthoritative: false,
            isRebuildable: true
        ),
        PersistenceDomainDescriptor(
            domain: .generatedCaches,
            rootPath: "caches",
            isAuthoritative: false,
            isRebuildable: true
        ),
    ])
}
