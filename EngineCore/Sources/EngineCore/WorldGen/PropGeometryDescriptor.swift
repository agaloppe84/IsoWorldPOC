public struct PropVector3: Equatable, Hashable, Codable, Sendable {
    public let x: Float
    public let y: Float
    public let z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public enum PropGeometryShape: String, CaseIterable, Codable, Sendable {
    case box
    case capsule
    case cone
}

public enum PropMaterialSlot: String, CaseIterable, Codable, Sendable {
    case primary
    case secondary
    case accent
}

public struct PropGeometryPart: Equatable, Hashable, Codable, Sendable {
    public let shape: PropGeometryShape
    public let size: PropVector3
    public let cornerRadius: Float
    public let position: PropVector3
    public let rotationRadians: PropVector3
    public let materialSlot: PropMaterialSlot

    public init(
        shape: PropGeometryShape,
        size: PropVector3,
        cornerRadius: Float = 0,
        position: PropVector3 = PropVector3(x: 0, y: 0, z: 0),
        rotationRadians: PropVector3 = PropVector3(x: 0, y: 0, z: 0),
        materialSlot: PropMaterialSlot = .primary
    ) {
        self.shape = shape
        self.size = size
        self.cornerRadius = cornerRadius
        self.position = position
        self.rotationRadians = rotationRadians
        self.materialSlot = materialSlot
    }
}

public struct PropGeometryDescriptor: Equatable, Hashable, Codable, Sendable {
    public let parts: [PropGeometryPart]

    public init(parts: [PropGeometryPart]) {
        self.parts = parts
    }
}
