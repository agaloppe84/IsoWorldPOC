import Foundation

public struct ProceduralAssetGenerator: Sendable {
    public let seed: WorldSeed

    public init(seed: WorldSeed) {
        self.seed = seed
    }

    public func variant(
        for placement: PropPlacement,
        biome: Biome,
        chunk: ChunkCoordinate
    ) -> PropVariant {
        let variantSeed = localVariantSeed(for: placement, biome: biome, chunk: chunk)
        var random = StableRNG(seedValue: variantSeed)
        let archetype = PropArchetype.definition(for: placement.type, biome: biome)
        let size = scaledSize(for: archetype, placementScale: placement.scale, random: &random)
        let proportions = PropVector3(
            x: safeRatio(size.x, archetype.maximumSize.x * placement.scale),
            y: safeRatio(size.y, archetype.maximumSize.y * placement.scale),
            z: safeRatio(size.z, archetype.maximumSize.z * placement.scale)
        )
        let materials = materialSet(for: placement.type, biome: biome, random: &random)
        let geometry = geometry(
            for: placement.type,
            biome: biome,
            size: size,
            random: &random
        )

        return PropVariant(
            placement: placement,
            archetypeID: archetype.identifier,
            variantSeed: variantSeed,
            size: size,
            proportions: proportions,
            geometry: geometry,
            primaryMaterial: materials.primary,
            secondaryMaterial: materials.secondary,
            accentMaterial: materials.accent,
            collisionSize: collisionSize(for: placement.type, size: size)
        )
    }

    private func scaledSize(
        for archetype: PropArchetype,
        placementScale: Float,
        random: inout StableRNG
    ) -> PropVector3 {
        PropVector3(
            x: lerp(archetype.minimumSize.x, archetype.maximumSize.x, randomUnit(&random)) * placementScale,
            y: lerp(archetype.minimumSize.y, archetype.maximumSize.y, randomUnit(&random)) * placementScale,
            z: lerp(archetype.minimumSize.z, archetype.maximumSize.z, randomUnit(&random)) * placementScale
        )
    }

    private func geometry(
        for type: PropType,
        biome: Biome,
        size: PropVector3,
        random: inout StableRNG
    ) -> PropGeometryDescriptor {
        switch type {
        case .rock:
            rockGeometry(size: size)
        case .pebble:
            pebbleGeometry(size: size)
        case .grass:
            grassGeometry(size: size, random: &random)
        case .tree:
            treeGeometry(size: size, biome: biome)
        case .deadwood:
            deadwoodGeometry(size: size, random: &random)
        case .crystal:
            crystalGeometry(size: size, random: &random)
        }
    }

    private func rockGeometry(size: PropVector3) -> PropGeometryDescriptor {
        PropGeometryDescriptor(
            parts: [
                PropGeometryPart(
                    shape: .capsule,
                    size: size,
                    cornerRadius: min(size.x, min(size.y, size.z)) * 0.22,
                    position: PropVector3(x: 0, y: size.y * 0.5, z: 0),
                    materialSlot: .primary
                )
            ]
        )
    }

    private func pebbleGeometry(size: PropVector3) -> PropGeometryDescriptor {
        PropGeometryDescriptor(
            parts: [
                PropGeometryPart(
                    shape: .capsule,
                    size: size,
                    cornerRadius: min(size.x, min(size.y, size.z)) * 0.18,
                    position: PropVector3(x: 0, y: size.y * 0.5, z: 0),
                    materialSlot: .primary
                )
            ]
        )
    }

    private func grassGeometry(size: PropVector3, random: inout StableRNG) -> PropGeometryDescriptor {
        let bladeCount = 3 + Int(random.next() % 3)
        let bladeWidth = max(size.x * 0.18, 0.025)
        let bladeDepth = max(size.z * 0.12, 0.018)
        var parts: [PropGeometryPart] = []
        parts.reserveCapacity(bladeCount)

        for index in 0..<bladeCount {
            let angle = (Float(index) / Float(bladeCount)) * Float.pi * 2 +
                randomUnit(&random) * 0.35
            let height = size.y * (0.72 + randomUnit(&random) * 0.38)
            let radius = min(size.x, size.z) * (0.10 + randomUnit(&random) * 0.18)

            parts.append(PropGeometryPart(
                shape: .cone,
                size: PropVector3(x: bladeWidth, y: height, z: bladeDepth),
                position: PropVector3(
                    x: cos(angle) * radius,
                    y: height * 0.5,
                    z: sin(angle) * radius
                ),
                rotationRadians: PropVector3(
                    x: sin(angle) * 0.20,
                    y: angle,
                    z: cos(angle) * 0.20
                ),
                materialSlot: index == 0 ? .secondary : .primary
            ))
        }

        return PropGeometryDescriptor(parts: parts)
    }

    private func treeGeometry(size: PropVector3, biome: Biome) -> PropGeometryDescriptor {
        let trunkHeight = size.y * trunkHeightRatio(for: biome)
        let crownHeight = max(size.y - trunkHeight * 0.65, size.y * 0.35)
        let trunkWidth = max(size.x * 0.22, 0.08)
        let crownWidth = size.x
        let crownDepth = size.z
        let crownShape: PropGeometryShape = biome.type == .taiga ? .cone : .capsule

        return PropGeometryDescriptor(
            parts: [
                PropGeometryPart(
                    shape: .capsule,
                    size: PropVector3(x: trunkWidth, y: trunkHeight, z: trunkWidth),
                    cornerRadius: trunkWidth * 0.16,
                    position: PropVector3(x: 0, y: trunkHeight * 0.5, z: 0),
                    materialSlot: .primary
                ),
                PropGeometryPart(
                    shape: crownShape,
                    size: PropVector3(x: crownWidth, y: crownHeight, z: crownDepth),
                    cornerRadius: min(crownWidth, min(crownHeight, crownDepth)) * 0.18,
                    position: PropVector3(x: 0, y: trunkHeight + crownHeight * 0.34, z: 0),
                    materialSlot: .secondary
                )
            ]
        )
    }

    private func deadwoodGeometry(size: PropVector3, random: inout StableRNG) -> PropGeometryDescriptor {
        let branchAngle = (randomUnit(&random) - 0.5) * 0.9
        let smallBranchScale = 0.42 + randomUnit(&random) * 0.18

        return PropGeometryDescriptor(
            parts: [
                PropGeometryPart(
                    shape: .capsule,
                    size: PropVector3(x: size.x, y: size.z, z: size.x),
                    position: PropVector3(x: 0, y: size.y * 0.48, z: 0),
                    rotationRadians: PropVector3(x: Float.pi * 0.5, y: branchAngle, z: 0),
                    materialSlot: .primary
                ),
                PropGeometryPart(
                    shape: .capsule,
                    size: PropVector3(
                        x: size.x * 0.55,
                        y: size.z * smallBranchScale,
                        z: size.x * 0.55
                    ),
                    position: PropVector3(x: size.x * 0.18, y: size.y * 0.62, z: size.z * 0.04),
                    rotationRadians: PropVector3(
                        x: Float.pi * 0.5,
                        y: branchAngle + 0.9,
                        z: 0.18
                    ),
                    materialSlot: .accent
                )
            ]
        )
    }

    private func crystalGeometry(size: PropVector3, random: inout StableRNG) -> PropGeometryDescriptor {
        let tilt = (randomUnit(&random) - 0.5) * 0.55
        let secondaryScale = 0.58 + randomUnit(&random) * 0.22

        return PropGeometryDescriptor(
            parts: [
                PropGeometryPart(
                    shape: .cone,
                    size: size,
                    cornerRadius: min(size.x, size.z) * 0.12,
                    position: PropVector3(x: 0, y: size.y * 0.5, z: 0),
                    rotationRadians: PropVector3(x: 0, y: 0, z: tilt),
                    materialSlot: .primary
                ),
                PropGeometryPart(
                    shape: .cone,
                    size: PropVector3(
                        x: size.x * secondaryScale,
                        y: size.y * secondaryScale,
                        z: size.z * secondaryScale
                    ),
                    cornerRadius: min(size.x, size.z) * 0.10,
                    position: PropVector3(x: size.x * 0.35, y: size.y * 0.35, z: size.z * 0.20),
                    rotationRadians: PropVector3(x: 0, y: 0, z: -tilt * 0.75),
                    materialSlot: .accent
                )
            ]
        )
    }

    private func trunkHeightRatio(for biome: Biome) -> Float {
        switch biome.type {
        case .desert, .coast:
            0.72
        case .temperateForest, .marsh, .taiga, .freshwater:
            0.58
        default:
            0.64
        }
    }

    private func materialSet(
        for type: PropType,
        biome: Biome,
        random: inout StableRNG
    ) -> (
        primary: PropMaterialDescriptor,
        secondary: PropMaterialDescriptor,
        accent: PropMaterialDescriptor
    ) {
        switch type {
        case .rock:
            let rock = PropMaterialDescriptor(
                identifier: "prop.material.rock.\(biome.type.rawValue)",
                color: varied(rockColor(for: biome), amount: 0.08, random: &random),
                roughness: 0.88
            )
            return (rock, rock, rock)
        case .pebble:
            let pebble = PropMaterialDescriptor(
                identifier: "prop.material.pebble.\(biome.type.rawValue)",
                color: varied(rockColor(for: biome), amount: 0.10, random: &random),
                roughness: 0.92
            )
            return (pebble, pebble, pebble)
        case .grass:
            let grass = PropMaterialDescriptor(
                identifier: "prop.material.grass.\(biome.type.rawValue)",
                color: varied(foliageColor(for: biome), amount: 0.12, random: &random),
                roughness: 0.84
            )
            let highlight = PropMaterialDescriptor(
                identifier: "prop.material.grassHighlight.\(biome.type.rawValue)",
                color: varied(foliageAccentColor(for: biome), amount: 0.10, random: &random),
                roughness: 0.82
            )
            return (grass, highlight, grass)
        case .tree:
            return (
                PropMaterialDescriptor(
                    identifier: "prop.material.trunk.\(biome.type.rawValue)",
                    color: varied(trunkColor(for: biome), amount: 0.06, random: &random),
                    roughness: 0.82
                ),
                PropMaterialDescriptor(
                    identifier: "prop.material.foliage.\(biome.type.rawValue)",
                    color: varied(foliageColor(for: biome), amount: 0.08, random: &random),
                    roughness: 0.78
                ),
                PropMaterialDescriptor(
                    identifier: "prop.material.foliageAccent.\(biome.type.rawValue)",
                    color: varied(foliageColor(for: biome), amount: 0.12, random: &random),
                    roughness: 0.78
                )
            )
        case .deadwood:
            let bark = PropMaterialDescriptor(
                identifier: "prop.material.deadwood.\(biome.type.rawValue)",
                color: varied(deadwoodColor(for: biome), amount: 0.10, random: &random),
                roughness: 0.90
            )
            let exposed = PropMaterialDescriptor(
                identifier: "prop.material.deadwoodAccent.\(biome.type.rawValue)",
                color: varied(deadwoodAccentColor(for: biome), amount: 0.08, random: &random),
                roughness: 0.86
            )
            return (bark, bark, exposed)
        case .crystal:
            let crystal = PropMaterialDescriptor(
                identifier: "prop.material.crystal.\(biome.type.rawValue)",
                color: varied(crystalColor(for: biome), amount: 0.10, random: &random),
                roughness: 0.36
            )
            let accent = PropMaterialDescriptor(
                identifier: "prop.material.crystalAccent.\(biome.type.rawValue)",
                color: varied(crystalAccentColor(for: biome), amount: 0.10, random: &random),
                roughness: 0.30
            )
            return (crystal, crystal, accent)
        }
    }

    private func foliageAccentColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .desert, .coast:
            BiomeColor(red: 0.56, green: 0.48, blue: 0.22)
        case .marsh, .freshwater:
            BiomeColor(red: 0.14, green: 0.55, blue: 0.36)
        case .taiga:
            BiomeColor(red: 0.13, green: 0.36, blue: 0.30)
        default:
            BiomeColor(red: 0.24, green: 0.52, blue: 0.20)
        }
    }

    private func deadwoodColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .coast, .freshwater:
            BiomeColor(red: 0.42, green: 0.34, blue: 0.24)
        case .marsh:
            BiomeColor(red: 0.22, green: 0.16, blue: 0.11)
        default:
            BiomeColor(red: 0.31, green: 0.21, blue: 0.13)
        }
    }

    private func deadwoodAccentColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .coast, .freshwater:
            BiomeColor(red: 0.58, green: 0.48, blue: 0.34)
        case .marsh:
            BiomeColor(red: 0.34, green: 0.26, blue: 0.18)
        default:
            BiomeColor(red: 0.45, green: 0.32, blue: 0.20)
        }
    }

    private func rockColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .desert, .coast:
            BiomeColor(red: 0.48, green: 0.36, blue: 0.22)
        case .marsh, .freshwater:
            BiomeColor(red: 0.28, green: 0.34, blue: 0.30)
        case .mountain:
            BiomeColor(red: 0.45, green: 0.45, blue: 0.42)
        default:
            BiomeColor(red: 0.38, green: 0.38, blue: 0.34)
        }
    }

    private func trunkColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .desert, .coast:
            BiomeColor(red: 0.42, green: 0.30, blue: 0.16)
        case .marsh, .freshwater:
            BiomeColor(red: 0.28, green: 0.20, blue: 0.13)
        default:
            BiomeColor(red: 0.34, green: 0.21, blue: 0.12)
        }
    }

    private func foliageColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .desert, .coast:
            BiomeColor(red: 0.42, green: 0.38, blue: 0.18)
        case .marsh, .freshwater:
            BiomeColor(red: 0.08, green: 0.42, blue: 0.27)
        case .temperateForest:
            BiomeColor(red: 0.07, green: 0.34, blue: 0.14)
        case .taiga:
            BiomeColor(red: 0.08, green: 0.28, blue: 0.22)
        default:
            BiomeColor(red: 0.18, green: 0.42, blue: 0.16)
        }
    }

    private func crystalColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .desert, .coast:
            BiomeColor(red: 0.64, green: 0.56, blue: 0.32)
        case .marsh, .freshwater:
            BiomeColor(red: 0.22, green: 0.70, blue: 0.78)
        default:
            BiomeColor(red: 0.30, green: 0.82, blue: 0.90)
        }
    }

    private func crystalAccentColor(for biome: Biome) -> BiomeColor {
        switch biome.type {
        case .desert, .coast:
            BiomeColor(red: 0.82, green: 0.72, blue: 0.40)
        case .marsh, .freshwater:
            BiomeColor(red: 0.45, green: 0.90, blue: 0.82)
        default:
            BiomeColor(red: 0.58, green: 0.95, blue: 1.00)
        }
    }

    private func collisionSize(for type: PropType, size: PropVector3) -> PropVector3 {
        switch type {
        case .rock:
            size
        case .pebble:
            PropVector3(x: size.x, y: size.y * 0.8, z: size.z)
        case .grass:
            PropVector3(x: size.x, y: size.y * 0.7, z: size.z)
        case .tree:
            PropVector3(x: size.x, y: size.y, z: size.z)
        case .deadwood:
            PropVector3(x: size.x, y: size.y, z: size.z)
        case .crystal:
            PropVector3(x: size.x * 1.2, y: size.y, z: size.z * 1.2)
        }
    }

    private func localVariantSeed(
        for placement: PropPlacement,
        biome: Biome,
        chunk: ChunkCoordinate
    ) -> UInt64 {
        StableHash.make { builder in
            builder.combine(seed)
            builder.combine(SeedDomain.props)
            builder.combine(chunk)
            builder.combine(placement.placementIndex)
            builder.combine(placement.type.rawValue)
            builder.combine(biome.type.rawValue)
        }.value
    }

    private func varied(_ color: BiomeColor, amount: Float, random: inout StableRNG) -> BiomeColor {
        BiomeColor(
            red: clamped(color.red + variation(amount: amount, random: &random)),
            green: clamped(color.green + variation(amount: amount, random: &random)),
            blue: clamped(color.blue + variation(amount: amount, random: &random))
        )
    }

    private func variation(amount: Float, random: inout StableRNG) -> Float {
        (randomUnit(&random) * 2.0 - 1.0) * amount
    }

    private func safeRatio(_ value: Float, _ maximum: Float) -> Float {
        guard maximum > 0 else {
            return 0
        }

        return value / maximum
    }

    private func clamped(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }

    private func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }

    private func randomUnit(_ random: inout StableRNG) -> Float {
        random.nextUnitFloat()
    }
}
