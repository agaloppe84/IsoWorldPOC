public enum LODLevel: Int, CaseIterable, Comparable, Codable, Sendable {
    case lod0 = 0
    case lod1 = 1
    case lod2 = 2
    case lod3 = 3

    public static func < (lhs: LODLevel, rhs: LODLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .lod0:
            "LOD0"
        case .lod1:
            "LOD1"
        case .lod2:
            "LOD2"
        case .lod3:
            "LOD3"
        }
    }

    public var terrainIndexStride: Int {
        switch self {
        case .lod0:
            1
        case .lod1:
            2
        case .lod2:
            4
        case .lod3:
            8
        }
    }

    public var rendersProps: Bool {
        switch self {
        case .lod0, .lod1:
            true
        case .lod2, .lod3:
            false
        }
    }
}
