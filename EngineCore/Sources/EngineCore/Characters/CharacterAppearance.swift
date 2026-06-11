public enum CharacterHairStyle: String, CaseIterable, Codable, Sendable {
    case shaved
    case short
    case tiedBack
    case shoulderLength
}

public enum CharacterBeardStyle: String, CaseIterable, Codable, Sendable {
    case none
    case stubble
    case short
}

public enum CharacterLODLevel: Int, CaseIterable, Codable, Sendable {
    case high
    case medium
    case low
    case impostor
}

public struct CharacterPBRMaterial: Equatable, Hashable, Codable, Sendable {
    public let identifier: String
    public let debugName: String
    public let baseColor: BiomeColor
    public let roughness: Float
    public let metallic: Float

    public init(
        identifier: String,
        debugName: String,
        baseColor: BiomeColor,
        roughness: Float,
        metallic: Float = 0
    ) {
        precondition(!identifier.isEmpty, "Character material identifier cannot be empty.")
        precondition(!debugName.isEmpty, "Character material debugName cannot be empty.")

        self.identifier = identifier
        self.debugName = debugName
        self.baseColor = baseColor
        self.roughness = Self.clamped01(roughness)
        self.metallic = Self.clamped01(metallic)
    }

    public var renderMaterial: RenderMaterial {
        RenderMaterial(
            identifier: identifier,
            debugName: debugName,
            baseColor: baseColor,
            roughness: roughness
        )
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

public struct CharacterLODPolicy: Equatable, Hashable, Codable, Sendable {
    public let highDetailDistance: Float
    public let mediumDetailDistance: Float
    public let lowDetailDistance: Float
    public let impostorDistance: Float

    public init(
        highDetailDistance: Float = 6,
        mediumDetailDistance: Float = 18,
        lowDetailDistance: Float = 42,
        impostorDistance: Float = 90
    ) {
        precondition(highDetailDistance > 0, "highDetailDistance must be positive.")
        precondition(mediumDetailDistance >= highDetailDistance, "LOD distances must be ordered.")
        precondition(lowDetailDistance >= mediumDetailDistance, "LOD distances must be ordered.")
        precondition(impostorDistance >= lowDetailDistance, "LOD distances must be ordered.")

        self.highDetailDistance = highDetailDistance
        self.mediumDetailDistance = mediumDetailDistance
        self.lowDetailDistance = lowDetailDistance
        self.impostorDistance = impostorDistance
    }

    public func level(forDistance distance: Float) -> CharacterLODLevel {
        let distance = max(distance, 0)

        if distance <= highDetailDistance {
            return .high
        }

        if distance <= mediumDetailDistance {
            return .medium
        }

        if distance <= lowDetailDistance {
            return .low
        }

        return .impostor
    }
}

public struct CharacterMeshDescriptor: Equatable, Hashable, Codable, Sendable {
    public let identifier: String
    public let skeletonJointCount: Int
    public let maxSkinInfluencesPerVertex: Int
    public let estimatedVertexCountLOD0: Int
    public let bodyMaterialIdentifier: String
    public let clothingMaterialIdentifiers: [String]

    public init(
        identifier: String,
        skeletonJointCount: Int,
        maxSkinInfluencesPerVertex: Int = 4,
        estimatedVertexCountLOD0: Int,
        bodyMaterialIdentifier: String,
        clothingMaterialIdentifiers: [String]
    ) {
        precondition(!identifier.isEmpty, "Character mesh identifier cannot be empty.")
        precondition(skeletonJointCount > 0, "skeletonJointCount must be positive.")
        precondition(maxSkinInfluencesPerVertex > 0, "maxSkinInfluencesPerVertex must be positive.")
        precondition(estimatedVertexCountLOD0 > 0, "estimatedVertexCountLOD0 must be positive.")

        self.identifier = identifier
        self.skeletonJointCount = skeletonJointCount
        self.maxSkinInfluencesPerVertex = maxSkinInfluencesPerVertex
        self.estimatedVertexCountLOD0 = estimatedVertexCountLOD0
        self.bodyMaterialIdentifier = bodyMaterialIdentifier
        self.clothingMaterialIdentifiers = clothingMaterialIdentifiers
    }

    public static func simpleHumanoid(
        body: CharacterBodyParameters,
        appearance: CharacterAppearance,
        equipment: CharacterEquipmentSet
    ) -> CharacterMeshDescriptor {
        CharacterMeshDescriptor(
            identifier: "character.mesh.simple-humanoid.v1",
            skeletonJointCount: body.skeleton.joints.count,
            estimatedVertexCountLOD0: 3_200,
            bodyMaterialIdentifier: appearance.skinMaterial.identifier,
            clothingMaterialIdentifiers: equipment.items.map(\.material.identifier)
        )
    }
}

public struct CharacterAppearance: Equatable, Hashable, Codable, Sendable {
    public let skinMaterial: CharacterPBRMaterial
    public let hairMaterial: CharacterPBRMaterial
    public let eyeColor: BiomeColor
    public let hairStyle: CharacterHairStyle
    public let beardStyle: CharacterBeardStyle
    public let faceWidth: Float
    public let jawStrength: Float
    public let noseBridge: Float
    public let voicePitch: Float
    public let lodPolicy: CharacterLODPolicy

    public init(
        skinMaterial: CharacterPBRMaterial,
        hairMaterial: CharacterPBRMaterial,
        eyeColor: BiomeColor,
        hairStyle: CharacterHairStyle,
        beardStyle: CharacterBeardStyle,
        faceWidth: Float,
        jawStrength: Float,
        noseBridge: Float,
        voicePitch: Float,
        lodPolicy: CharacterLODPolicy = CharacterLODPolicy()
    ) {
        self.skinMaterial = skinMaterial
        self.hairMaterial = hairMaterial
        self.eyeColor = eyeColor
        self.hairStyle = hairStyle
        self.beardStyle = beardStyle
        self.faceWidth = Self.clamped01(faceWidth)
        self.jawStrength = Self.clamped01(jawStrength)
        self.noseBridge = Self.clamped01(noseBridge)
        self.voicePitch = Self.clamped01(voicePitch)
        self.lodPolicy = lodPolicy
    }

    public static func makePlayerAppearance(random: inout StableRNG) -> CharacterAppearance {
        let skin = BiomeColor(
            red: random.nextFloat(in: 0.50...0.88),
            green: random.nextFloat(in: 0.34...0.67),
            blue: random.nextFloat(in: 0.25...0.55)
        )
        let hair = BiomeColor(
            red: random.nextFloat(in: 0.08...0.42),
            green: random.nextFloat(in: 0.06...0.32),
            blue: random.nextFloat(in: 0.04...0.24)
        )
        let eyes = [
            BiomeColor(red: 0.16, green: 0.28, blue: 0.20),
            BiomeColor(red: 0.22, green: 0.36, blue: 0.52),
            BiomeColor(red: 0.36, green: 0.25, blue: 0.15),
            BiomeColor(red: 0.40, green: 0.42, blue: 0.34),
        ]

        return CharacterAppearance(
            skinMaterial: CharacterPBRMaterial(
                identifier: "character.skin.seeded",
                debugName: "Skin",
                baseColor: skin,
                roughness: random.nextFloat(in: 0.45...0.70)
            ),
            hairMaterial: CharacterPBRMaterial(
                identifier: "character.hair.seeded",
                debugName: "Hair",
                baseColor: hair,
                roughness: random.nextFloat(in: 0.58...0.86)
            ),
            eyeColor: eyes[random.nextInt(upperBound: eyes.count)],
            hairStyle: CharacterHairStyle.allCases[random.nextInt(upperBound: CharacterHairStyle.allCases.count)],
            beardStyle: CharacterBeardStyle.allCases[random.nextInt(upperBound: CharacterBeardStyle.allCases.count)],
            faceWidth: random.nextFloat(in: 0.30...0.72),
            jawStrength: random.nextFloat(in: 0.22...0.78),
            noseBridge: random.nextFloat(in: 0.18...0.82),
            voicePitch: random.nextFloat(in: 0.25...0.76)
        )
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
