import Foundation

enum ToolCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case world
    case terrain
    case biomes
    case props
    case materials
    case lod

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .world:
            "World"
        case .terrain:
            "Terrain"
        case .biomes:
            "Biomes"
        case .props:
            "Props"
        case .materials:
            "Materials"
        case .lod:
            "LOD"
        }
    }

    var systemImage: String {
        switch self {
        case .world:
            "globe.europe.africa"
        case .terrain:
            "mountain.2"
        case .biomes:
            "leaf"
        case .props:
            "shippingbox"
        case .materials:
            "paintpalette"
        case .lod:
            "square.stack.3d.up"
        }
    }
}

enum ToolCapability: String, CaseIterable, Codable, Hashable {
    case preview
    case validation
    case presets
    case export

    var displayName: String {
        switch self {
        case .preview:
            "Preview"
        case .validation:
            "Validation"
        case .presets:
            "Presets"
        case .export:
            "Export"
        }
    }
}

struct ToolDescriptor: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let category: ToolCategory
    let summary: String
    let systemImage: String
    let capabilities: [ToolCapability]

    init(
        id: String,
        name: String,
        category: ToolCategory,
        summary: String,
        systemImage: String,
        capabilities: [ToolCapability]
    ) {
        precondition(!id.isEmpty, "Tool id cannot be empty.")
        precondition(!name.isEmpty, "Tool name cannot be empty.")
        self.id = id
        self.name = name
        self.category = category
        self.summary = summary
        self.systemImage = systemImage
        self.capabilities = capabilities
    }
}
