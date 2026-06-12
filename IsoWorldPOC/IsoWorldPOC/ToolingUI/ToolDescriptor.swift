import Foundation

enum ToolCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case world
    case terrain
    case biomes
    case props
    case materials
    case lod
    case characters
    case animation
    case fx
    case audio
    case rpg
    case settlements
    case saves
    case performance
    case snapshots

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
        case .characters:
            "Characters"
        case .animation:
            "Animation"
        case .fx:
            "FX"
        case .audio:
            "Audio"
        case .rpg:
            "RPG"
        case .settlements:
            "Settlements"
        case .saves:
            "Saves"
        case .performance:
            "Performance"
        case .snapshots:
            "Snapshots"
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
        case .characters:
            "person.crop.rectangle.stack"
        case .animation:
            "figure.walk.motion"
        case .fx:
            "sparkles"
        case .audio:
            "waveform"
        case .rpg:
            "map"
        case .settlements:
            "building.2"
        case .saves:
            "externaldrive"
        case .performance:
            "speedometer"
        case .snapshots:
            "square.on.square.dashed"
        }
    }
}

enum ToolCapability: String, CaseIterable, Codable, Hashable {
    case preview
    case validation
    case presets
    case export
    case persistence
    case diagnostics

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
        case .persistence:
            "Persistence"
        case .diagnostics:
            "Diagnostics"
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
