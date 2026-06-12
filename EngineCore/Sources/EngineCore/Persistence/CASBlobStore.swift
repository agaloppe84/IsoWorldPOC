import Foundation

public enum CASBlobKind: String, CaseIterable, Codable, Sendable {
    case runtimeAsset
    case generatedCache
    case diagnosticBundle
    case toolExport
}

public struct CASBlobReference: Hashable, Codable, Sendable {
    public let hash: String
    public let stableHash: StableHash
    public let byteCount: Int
    public let relativePath: String
    public let kind: CASBlobKind

    public init(
        hash: String,
        stableHash: StableHash,
        byteCount: Int,
        relativePath: String,
        kind: CASBlobKind
    ) {
        precondition(!hash.isEmpty, "CAS hash cannot be empty.")
        precondition(byteCount >= 0, "CAS byteCount must be non-negative.")
        precondition(!relativePath.isEmpty, "CAS relativePath cannot be empty.")

        self.hash = hash
        self.stableHash = stableHash
        self.byteCount = byteCount
        self.relativePath = relativePath
        self.kind = kind
    }
}

public struct CASBlobManifest: Hashable, Codable, Sendable {
    public static let currentFormat = "IsoWorldCASBlobManifest"

    public let format: String
    public let blobs: [CASBlobReference]

    public init(
        format: String = Self.currentFormat,
        blobs: [CASBlobReference] = []
    ) {
        self.format = format
        self.blobs = blobs.sorted { lhs, rhs in
            if lhs.hash != rhs.hash {
                return lhs.hash < rhs.hash
            }

            return lhs.relativePath < rhs.relativePath
        }
    }

    public var relativePath: String {
        "blobs/manifest.json"
    }

    public var totalByteCount: Int {
        blobs.reduce(0) { $0 + $1.byteCount }
    }

    public func appending(_ reference: CASBlobReference) -> CASBlobManifest {
        CASBlobManifest(blobs: blobs.filter { $0.hash != reference.hash } + [reference])
    }
}

public struct CASBlobStore: Sendable {
    private let fileWriter: AtomicFileWriter

    public init(fileWriter: AtomicFileWriter = AtomicFileWriter()) {
        self.fileWriter = fileWriter
    }

    public func write(
        _ data: Data,
        kind: CASBlobKind,
        relativeTo rootURL: URL
    ) throws -> CASBlobReference {
        let stableHash = StableHash.make(data: data)
        let hash = stableHash.description
        let relativePath = Self.relativePath(for: hash)
        let url = rootURL.appendingPathComponent(relativePath)

        if !FileManager.default.fileExists(atPath: url.path) {
            try fileWriter.write(data, to: url)
        }

        return CASBlobReference(
            hash: hash,
            stableHash: stableHash,
            byteCount: data.count,
            relativePath: relativePath,
            kind: kind
        )
    }

    public func read(
        _ reference: CASBlobReference,
        relativeTo rootURL: URL
    ) throws -> Data {
        try Data(contentsOf: rootURL.appendingPathComponent(reference.relativePath))
    }

    public func verify(
        _ reference: CASBlobReference,
        relativeTo rootURL: URL
    ) throws -> Bool {
        let data = try read(reference, relativeTo: rootURL)
        return StableHash.make(data: data) == reference.stableHash &&
            data.count == reference.byteCount
    }

    public func writeManifest(
        _ manifest: CASBlobManifest,
        relativeTo rootURL: URL
    ) throws -> String {
        try fileWriter.writeJSON(manifest, to: rootURL.appendingPathComponent(manifest.relativePath))
        return manifest.relativePath
    }

    public func readManifest(relativeTo rootURL: URL) throws -> CASBlobManifest {
        try fileWriter.readJSON(
            CASBlobManifest.self,
            from: rootURL.appendingPathComponent(CASBlobManifest().relativePath)
        )
    }

    public static func relativePath(for hash: String) -> String {
        let cleanHash = hash.replacingOccurrences(of: "0x", with: "")
        let prefix = String(cleanHash.prefix(2))
        return "blobs/\(prefix)/\(hash).blob"
    }
}

public extension StableHash {
    static func make(data: Data) -> StableHash {
        make { builder in
            builder.combine(data.count)

            for byte in data {
                builder.combine(UInt64(byte))
            }
        }
    }
}
