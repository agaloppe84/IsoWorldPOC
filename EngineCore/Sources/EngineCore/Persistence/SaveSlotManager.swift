import Foundation

public actor SaveSlotManager {
    public let rootDirectory: URL
    public let manifestFileName: String

    private let fileWriter: AtomicFileWriter

    public init(
        rootDirectory: URL,
        manifestFileName: String = "manifest.json",
        fileWriter: AtomicFileWriter = AtomicFileWriter()
    ) {
        precondition(!manifestFileName.isEmpty, "manifestFileName cannot be empty.")

        self.rootDirectory = rootDirectory
        self.manifestFileName = manifestFileName
        self.fileWriter = fileWriter
    }

    public func save(_ manifest: SaveManifest) throws {
        try fileWriter.writeJSON(manifest, to: manifestURL(for: manifest.slotID))
    }

    public func load(slotID: SaveSlotID) throws -> SaveManifest {
        try fileWriter.readJSON(SaveManifest.self, from: manifestURL(for: slotID))
    }

    public func listSlots() throws -> [SaveSlotSummary] {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let slotURLs = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return try slotURLs.compactMap { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else {
                return nil
            }

            let manifestURL = url.appendingPathComponent(manifestFileName)
            guard fileManager.fileExists(atPath: manifestURL.path) else {
                return nil
            }

            return try fileWriter.readJSON(SaveManifest.self, from: manifestURL).summary
        }
        .sorted { first, second in
            if first.lastSavedAt != second.lastSavedAt {
                return first.lastSavedAt > second.lastSavedAt
            }

            return first.slotID.rawValue < second.slotID.rawValue
        }
    }

    public func delete(slotID: SaveSlotID) throws {
        let url = slotURL(for: slotID)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public func slotURL(for slotID: SaveSlotID) -> URL {
        rootDirectory.appendingPathComponent(slotID.rawValue, isDirectory: true)
    }

    public func manifestURL(for slotID: SaveSlotID) -> URL {
        slotURL(for: slotID).appendingPathComponent(manifestFileName)
    }
}
