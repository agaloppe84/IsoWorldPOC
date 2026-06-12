import Foundation

public enum RegionDeltaFileStoreError: Error, Equatable, Sendable {
    case invalidFormat(String)
    case regionMismatch(expected: RegionCoordinate, actual: RegionCoordinate)
    case worldSeedMismatch(expected: WorldSeed, actual: WorldSeed)
}

public struct RegionDeltaFileStore: Sendable {
    private let fileWriter: AtomicFileWriter

    public init(fileWriter: AtomicFileWriter = AtomicFileWriter()) {
        self.fileWriter = fileWriter
    }

    public func write(
        _ file: RegionDeltaFile,
        relativeTo rootURL: URL
    ) throws -> String {
        try validate(file)
        try fileWriter.writeJSON(file, to: rootURL.appendingPathComponent(file.relativePath))
        return file.relativePath
    }

    public func write(
        _ files: [RegionDeltaFile],
        relativeTo rootURL: URL
    ) throws -> [String] {
        try files
            .sorted { lhs, rhs in
                if lhs.region.x != rhs.region.x { return lhs.region.x < rhs.region.x }
                if lhs.region.y != rhs.region.y { return lhs.region.y < rhs.region.y }
                return lhs.region.z < rhs.region.z
            }
            .map { try write($0, relativeTo: rootURL) }
    }

    public func read(
        region: RegionCoordinate,
        relativeTo rootURL: URL,
        expectedWorldSeed: WorldSeed? = nil
    ) throws -> RegionDeltaFile {
        let file = try fileWriter.readJSON(
            RegionDeltaFile.self,
            from: rootURL.appendingPathComponent(Self.relativePath(for: region))
        )

        try validate(file, expectedRegion: region, expectedWorldSeed: expectedWorldSeed)
        return file
    }

    public func read(from url: URL, expectedWorldSeed: WorldSeed? = nil) throws -> RegionDeltaFile {
        let file = try fileWriter.readJSON(RegionDeltaFile.self, from: url)

        try validate(file, expectedWorldSeed: expectedWorldSeed)
        return file
    }

    public static func relativePath(for region: RegionCoordinate) -> String {
        "regions/r.\(region.x).\(region.y).\(region.z).isoregion"
    }

    private func validate(
        _ file: RegionDeltaFile,
        expectedRegion: RegionCoordinate? = nil,
        expectedWorldSeed: WorldSeed? = nil
    ) throws {
        guard file.format == RegionDeltaFile.currentFormat else {
            throw RegionDeltaFileStoreError.invalidFormat(file.format)
        }

        if let expectedRegion, file.region != expectedRegion {
            throw RegionDeltaFileStoreError.regionMismatch(
                expected: expectedRegion,
                actual: file.region
            )
        }

        if let expectedWorldSeed, file.worldSeed != expectedWorldSeed {
            throw RegionDeltaFileStoreError.worldSeedMismatch(
                expected: expectedWorldSeed,
                actual: file.worldSeed
            )
        }
    }
}
