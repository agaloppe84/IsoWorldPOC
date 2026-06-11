import Foundation

public enum AtomicFileWriterError: Error, Equatable, Sendable {
    case replacementFailed(URL)
}

public struct AtomicFileWriter: Sendable {
    public init() {}

    public func write(_ data: Data, to url: URL) throws {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let temporaryURL = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: temporaryURL, options: [.completeFileProtectionUnlessOpen])

        if fileManager.fileExists(atPath: url.path) {
            let resultingURL = try fileManager.replaceItemAt(
                url,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )

            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }

            guard resultingURL != nil || fileManager.fileExists(atPath: url.path) else {
                throw AtomicFileWriterError.replacementFailed(url)
            }
        } else {
            try fileManager.moveItem(at: temporaryURL, to: url)
        }
    }

    public func writeJSON<Value: Encodable>(_ value: Value, to url: URL) throws {
        let data = try Self.makeJSONEncoder().encode(value)
        try write(data, to: url)
    }

    public func readJSON<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value {
        let data = try Data(contentsOf: url)
        return try Self.makeJSONDecoder().decode(type, from: data)
    }

    public static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
