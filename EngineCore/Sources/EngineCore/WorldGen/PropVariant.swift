public struct PropMaterialDescriptor: Equatable, Hashable, Codable, Sendable {
    public let identifier: String
    public let color: BiomeColor
    public let roughness: Float

    public init(identifier: String, color: BiomeColor, roughness: Float) {
        self.identifier = identifier
        self.color = color
        self.roughness = roughness
    }
}

public struct PropVariant: Equatable, Hashable, Codable, Sendable {
    public let placement: PropPlacement
    public let archetypeID: String
    public let variantSeed: UInt64
    public let size: PropVector3
    public let proportions: PropVector3
    public let geometry: PropGeometryDescriptor
    public let primaryMaterial: PropMaterialDescriptor
    public let secondaryMaterial: PropMaterialDescriptor
    public let accentMaterial: PropMaterialDescriptor
    public let collisionSize: PropVector3

    public init(
        placement: PropPlacement,
        archetypeID: String,
        variantSeed: UInt64,
        size: PropVector3,
        proportions: PropVector3,
        geometry: PropGeometryDescriptor,
        primaryMaterial: PropMaterialDescriptor,
        secondaryMaterial: PropMaterialDescriptor,
        accentMaterial: PropMaterialDescriptor,
        collisionSize: PropVector3
    ) {
        self.placement = placement
        self.archetypeID = archetypeID
        self.variantSeed = variantSeed
        self.size = size
        self.proportions = proportions
        self.geometry = geometry
        self.primaryMaterial = primaryMaterial
        self.secondaryMaterial = secondaryMaterial
        self.accentMaterial = accentMaterial
        self.collisionSize = collisionSize
    }

    public func material(for slot: PropMaterialSlot) -> PropMaterialDescriptor {
        switch slot {
        case .primary:
            primaryMaterial
        case .secondary:
            secondaryMaterial
        case .accent:
            accentMaterial
        }
    }
}
