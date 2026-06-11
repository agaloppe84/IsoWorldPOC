import XCTest
@testable import EngineCore

final class MaterialPipelineTests: XCTestCase {
    func testBiomeDefinitionsExposePreviewMaterialData() {
        for type in BiomeType.allCases {
            let biome = Biome.definition(for: type)

            XCTAssertEqual(biome.type, type)
            XCTAssertFalse(biome.materialIdentifier.isEmpty)
            XCTAssertGreaterThanOrEqual(biome.previewColor.red, 0)
            XCTAssertLessThanOrEqual(biome.previewColor.red, 1)
            XCTAssertGreaterThanOrEqual(biome.previewColor.green, 0)
            XCTAssertLessThanOrEqual(biome.previewColor.green, 1)
            XCTAssertGreaterThanOrEqual(biome.previewColor.blue, 0)
            XCTAssertLessThanOrEqual(biome.previewColor.blue, 1)
            XCTAssertGreaterThan(biome.ruggednessMultiplier, 0)
            XCTAssertGreaterThanOrEqual(biome.propDensityMultiplier, 0)
            XCTAssertFalse(biome.terrainMaterial.identifier.isEmpty)
            XCTAssertGreaterThanOrEqual(biome.terrainMaterial.roughness, 0)
            XCTAssertLessThanOrEqual(biome.terrainMaterial.roughness, 1)
        }
    }

    func testTerrainMaterialDescriptorsExposeBasicMaterialData() {
        for kind in TerrainMaterialKind.allCases {
            let descriptor = TerrainMaterialDescriptor.definition(for: kind)

            XCTAssertEqual(descriptor.kind, kind)
            XCTAssertFalse(descriptor.identifier.isEmpty)
            XCTAssertGreaterThanOrEqual(descriptor.baseColor.red, 0)
            XCTAssertLessThanOrEqual(descriptor.baseColor.red, 1)
            XCTAssertGreaterThanOrEqual(descriptor.baseColor.green, 0)
            XCTAssertLessThanOrEqual(descriptor.baseColor.green, 1)
            XCTAssertGreaterThanOrEqual(descriptor.baseColor.blue, 0)
            XCTAssertLessThanOrEqual(descriptor.baseColor.blue, 1)
            XCTAssertGreaterThanOrEqual(descriptor.roughness, 0)
            XCTAssertLessThanOrEqual(descriptor.roughness, 1)
        }
    }

    func testTerrainTextureSlotsAreExplicitAndStable() {
        let slots = TerrainTextureSlot.allTerrainSlots

        XCTAssertEqual(slots.count, TerrainMaterialKind.allCases.count)
        XCTAssertEqual(slots.map(\.textureLayerIndex), Array(0..<slots.count))

        for slot in slots {
            let descriptor = TerrainMaterialDescriptor.definition(for: slot.materialKind)

            XCTAssertEqual(slot.map, .albedo)
            XCTAssertEqual(slot.materialIdentifier, descriptor.identifier)
            XCTAssertGreaterThan(slot.uvScale, 0)
            XCTAssertFalse(slot.debugName.isEmpty)
        }

        XCTAssertEqual(TerrainTextureSlot.slot(for: .grass).textureLayerIndex, 0)
        XCTAssertEqual(TerrainTextureSlot.slot(for: .rock).textureLayerIndex, 1)
        XCTAssertEqual(TerrainTextureSlot.slot(for: .mud).debugName, "Mud")
    }

    func testTerrainPBRTextureSlotsAreAvailableForEachMaterial() {
        let allSlots = TerrainTextureSlot.allTerrainPBRSlots

        XCTAssertEqual(
            allSlots.count,
            TerrainMaterialKind.allCases.count * TerrainTextureMap.allCases.count
        )

        for kind in TerrainMaterialKind.allCases {
            let slots = TerrainTextureSlot.pbrSlots(for: kind)

            XCTAssertEqual(slots.allSlots.map(\.map), TerrainTextureMap.allCases)
            XCTAssertTrue(slots.allSlots.allSatisfy { $0.materialKind == kind })
            XCTAssertTrue(slots.allSlots.allSatisfy {
                $0.textureLayerIndex == TerrainTextureSlot.textureLayerIndex(for: kind)
            })
            XCTAssertTrue(slots.allSlots.allSatisfy {
                $0.uvScale == TerrainTextureSlot.uvScale(for: kind)
            })
        }
    }

    func testRenderMaterialWrapsTerrainTextureSlot() {
        let descriptor = TerrainMaterialDescriptor.definition(for: .rock)
        let material = RenderMaterial.terrain(descriptor)

        guard let slot = material.terrainTextureSlot else {
            XCTFail("Terrain render material should expose a texture slot.")
            return
        }

        XCTAssertEqual(material.identifier, descriptor.identifier)
        XCTAssertEqual(material.baseColor, descriptor.baseColor)
        XCTAssertEqual(material.roughness, descriptor.roughness, accuracy: 0.0001)
        XCTAssertEqual(slot.materialKind, .rock)
        XCTAssertEqual(slot.textureLayerIndex, TerrainTextureSlot.textureLayerIndex(for: .rock))
        XCTAssertEqual(slot.uvScale, TerrainTextureSlot.uvScale(for: .rock), accuracy: 0.0001)

        guard let pbrSlots = material.terrainPBRTextureSlots else {
            XCTFail("Terrain render material should expose PBR texture slots.")
            return
        }

        XCTAssertEqual(pbrSlots.albedo, slot)
        XCTAssertEqual(pbrSlots.normal.map, .normal)
        XCTAssertEqual(pbrSlots.roughness.map, .roughness)
        XCTAssertEqual(pbrSlots.metallicAmbientOcclusion.map, .metallicAmbientOcclusion)
    }

    func testTerrainSurfaceDescriptorUsesOpaquePBRAndTextureBindings() {
        let material = TerrainMaterialDescriptor.definition(for: .rock)
        let descriptor = SurfaceDescriptor.terrain(material)

        XCTAssertEqual(descriptor.materialID.rawValue, material.identifier)
        XCTAssertEqual(descriptor.shadingModel, .opaquePBR)
        XCTAssertEqual(descriptor.terrainMaterialKind, .rock)
        XCTAssertTrue(descriptor.supportsTriplanar)
        XCTAssertEqual(descriptor.triplanarSlopeThreshold, 0.55, accuracy: 0.0001)
        XCTAssertEqual(
            descriptor.textureBindings.map(\.role),
            [.baseColor, .normal, .orm]
        )
        XCTAssertEqual(
            descriptor.textureBindings.compactMap(\.terrainTextureSlot?.map),
            [.albedo, .normal, .metallicAmbientOcclusion]
        )
    }

    func testIsoMaterialRuntimeAppliesSurfaceState() {
        let material = TerrainMaterialDescriptor.definition(for: .rock)
        let runtime = IsoMaterialRuntime.terrain(
            material,
            surfaceState: SurfaceState(wetness: 1)
        )
        let dryParameters = MaterialParameterBlock.terrain(material)
        let wetParameters = runtime.resolvedParameters

        XCTAssertEqual(runtime.materialID.rawValue, material.identifier)
        XCTAssertEqual(runtime.shadingModel, .opaquePBR)
        XCTAssertLessThan(wetParameters.baseColor.red, dryParameters.baseColor.red)
        XCTAssertLessThan(wetParameters.baseColor.green, dryParameters.baseColor.green)
        XCTAssertLessThan(wetParameters.baseColor.blue, dryParameters.baseColor.blue)
        XCTAssertLessThan(wetParameters.roughness, dryParameters.roughness)
    }

    func testRenderMaterialExposesRuntimeMaterial() {
        let descriptor = TerrainMaterialDescriptor.definition(for: .mud)
        let material = RenderMaterial.terrain(descriptor)
        let runtime = material.runtimeMaterial

        XCTAssertEqual(material.materialID.rawValue, descriptor.identifier)
        XCTAssertEqual(runtime.descriptor.materialID.rawValue, descriptor.identifier)
        XCTAssertEqual(runtime.descriptor.terrainMaterialKind, descriptor.kind)
        XCTAssertEqual(runtime.resolvedParameters.baseColor, descriptor.baseColor)
        XCTAssertEqual(runtime.resolvedParameters.roughness, descriptor.roughness, accuracy: 0.0001)
    }
}
