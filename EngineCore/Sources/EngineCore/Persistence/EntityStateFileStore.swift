import Foundation

public enum EntityStateFileStoreError: Error, Equatable, Sendable {
    case worldSeedMismatch(expected: WorldSeed, actual: WorldSeed?)
}

public struct EntityStatePackage: Hashable, Codable, Sendable {
    public static let currentFormat = "IsoWorldEntityState"

    public let format: String
    public let saveVersion: SaveVersion
    public let worldSeed: WorldSeed
    public let generation: Int
    public let store: EntityStateStore

    public init(
        format: String = Self.currentFormat,
        saveVersion: SaveVersion = .current,
        worldSeed: WorldSeed,
        generation: Int,
        store: EntityStateStore
    ) {
        precondition(generation >= 0, "generation must be non-negative.")

        self.format = format
        self.saveVersion = saveVersion
        self.worldSeed = worldSeed
        self.generation = generation
        self.store = store
    }
}

public struct EntityStateFileStore: Sendable {
    public static let defaultRelativePath = "entities/state.isoentity"

    private let fileWriter: AtomicFileWriter

    public init(fileWriter: AtomicFileWriter = AtomicFileWriter()) {
        self.fileWriter = fileWriter
    }

    @discardableResult
    public func write(
        _ store: EntityStateStore,
        worldSeed: WorldSeed,
        generation: Int,
        relativeTo rootURL: URL,
        relativePath: String = Self.defaultRelativePath
    ) throws -> String {
        let package = EntityStatePackage(
            worldSeed: worldSeed,
            generation: generation,
            store: store
        )
        try fileWriter.writeJSON(package, to: rootURL.appendingPathComponent(relativePath))
        return relativePath
    }

    public func read(
        relativeTo rootURL: URL,
        relativePath: String = Self.defaultRelativePath,
        expectedWorldSeed: WorldSeed? = nil
    ) throws -> EntityStatePackage {
        let package = try fileWriter.readJSON(
            EntityStatePackage.self,
            from: rootURL.appendingPathComponent(relativePath)
        )

        if let expectedWorldSeed, package.worldSeed != expectedWorldSeed {
            throw EntityStateFileStoreError.worldSeedMismatch(
                expected: expectedWorldSeed,
                actual: package.worldSeed
            )
        }

        return package
    }
}
