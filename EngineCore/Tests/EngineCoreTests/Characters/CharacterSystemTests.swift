import Foundation
import XCTest
@testable import EngineCore

final class CharacterSystemTests: XCTestCase {
    func testPlayerCharacterDNAIsDeterministicAndVersioned() {
        let seed = WorldSeed(0xCAFE)
        let first = CharacterDNA.makePlayer(worldSeed: seed, characterIndex: 0)
        let second = CharacterDNA.makePlayer(worldSeed: seed, characterIndex: 0)
        let alternateIndex = CharacterDNA.makePlayer(worldSeed: seed, characterIndex: 1)
        let alternateSeed = CharacterDNA.makePlayer(worldSeed: WorldSeed(0xBEEF), characterIndex: 0)
        let alternateVersion = CharacterDNA.makePlayer(
            worldSeed: seed,
            characterIndex: 0,
            generatorVersions: GeneratorVersionTable.current.setting(
                GeneratorVersion(major: 2),
                for: .characters
            )
        )

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first.id, alternateIndex.id)
        XCTAssertNotEqual(first.characterSeed, alternateSeed.characterSeed)
        XCTAssertNotEqual(first.id, alternateVersion.id)
        XCTAssertEqual(first.schemaVersion, CharacterDNA.currentSchemaVersion)
    }

    func testBodyParametersClampAndExposeCanonicalSkeletonSocketsAndMovement() {
        let body = CharacterBodyParameters(
            heightMeters: 3,
            shoulderWidth: 0.1,
            hipWidth: 2,
            chestDepth: 0.01,
            headScale: 2,
            legLengthRatio: 0.1,
            armLengthRatio: 3,
            musculature: 2,
            bodyFat: -1,
            faceBlend: 4
        )

        XCTAssertEqual(body.heightMeters, 2.12, accuracy: 0.0001)
        XCTAssertEqual(body.shoulderWidth, 0.32, accuracy: 0.0001)
        XCTAssertEqual(body.hipWidth, 0.62, accuracy: 0.0001)
        XCTAssertEqual(body.chestDepth, 0.18, accuracy: 0.0001)
        XCTAssertEqual(body.headScale, 1.16, accuracy: 0.0001)
        XCTAssertEqual(body.legLengthRatio, 0.86, accuracy: 0.0001)
        XCTAssertEqual(body.armLengthRatio, 1.16, accuracy: 0.0001)
        XCTAssertEqual(body.musculature, 1, accuracy: 0.0001)
        XCTAssertEqual(body.bodyFat, 0, accuracy: 0.0001)
        XCTAssertEqual(body.faceBlend, 1, accuracy: 0.0001)

        XCTAssertEqual(Set(body.skeleton.joints.map(\.id)), Set(CharacterJointID.allCases))
        XCTAssertEqual(body.sockets.count, CharacterSocketID.allCases.count)
        XCTAssertEqual(
            body.sockets.first { $0.id == .rightHand }?.jointID,
            .rightHand
        )
        XCTAssertEqual(
            body.sockets.first { $0.id == .back }?.allowedSlots,
            [.back]
        )
        XCTAssertGreaterThan(body.collisionCapsule.height, body.collisionCapsule.radius * 2)
        XCTAssertGreaterThan(body.naturalWalkSpeedMetersPerSecond, 1.1)
        XCTAssertGreaterThan(body.handReachMeters, 0)
    }

    func testStarterEquipmentSlotsAndReplacementAreStable() {
        var random = StableRNG(seedValue: 123)
        let equipment = CharacterEquipmentSet.starterOutfit(
            worldSeed: WorldSeed(42),
            characterID: StableID(99),
            random: &random
        )

        XCTAssertNotNil(equipment.item(in: .torso))
        XCTAssertNotNil(equipment.item(in: .legs))
        XCTAssertNotNil(equipment.item(in: .feet))
        XCTAssertNotNil(equipment.item(in: .back))
        XCTAssertEqual(equipment.item(in: .rightHand)?.identifier, "starter.tool")

        let replacementWeapon = WearableItem(
            id: StableID(100),
            kind: .weapon,
            identifier: "test.weapon",
            displayName: "Test weapon",
            occupiedSlots: [.rightHand],
            material: CharacterPBRMaterial(
                identifier: "test.weapon.material",
                debugName: "Weapon",
                baseColor: BiomeColor(red: 0.6, green: 0.6, blue: 0.6),
                roughness: 0.45,
                metallic: 0.8
            )
        )
        let updatedEquipment = equipment.equipping(replacementWeapon)

        XCTAssertEqual(updatedEquipment.item(in: .rightHand)?.identifier, "test.weapon")
        XCTAssertFalse(updatedEquipment.items.contains { $0.identifier == "starter.tool" })
        XCTAssertEqual(updatedEquipment.occupiedSlots.count, equipment.occupiedSlots.count)
    }

    func testAppearanceMeshDescriptorAndLODPolicyExposeRenderableContracts() {
        let dna = CharacterDNA.makePlayer(worldSeed: WorldSeed(777))

        XCTAssertEqual(dna.meshDescriptor.identifier, "character.mesh.simple-humanoid.v1")
        XCTAssertEqual(dna.meshDescriptor.skeletonJointCount, CharacterJointID.allCases.count)
        XCTAssertEqual(dna.meshDescriptor.bodyMaterialIdentifier, dna.appearance.skinMaterial.identifier)
        XCTAssertEqual(
            dna.meshDescriptor.clothingMaterialIdentifiers,
            dna.equipment.items.map(\.material.identifier)
        )
        XCTAssertEqual(
            dna.appearance.skinMaterial.renderMaterial.identifier,
            dna.appearance.skinMaterial.identifier
        )
        XCTAssertEqual(dna.lodPolicy.level(forDistance: 0), .high)
        XCTAssertEqual(dna.lodPolicy.level(forDistance: 12), .medium)
        XCTAssertEqual(dna.lodPolicy.level(forDistance: 30), .low)
        XCTAssertEqual(dna.lodPolicy.level(forDistance: 120), .impostor)
    }

    func testCustomizationSaveRoundTripsAndKeepsRegenerationContract() throws {
        let baseSave = CharacterCustomizationSave.defaultPlayer(worldSeed: WorldSeed(55))
        let save = baseSave.withRuntimeState(
            CharacterRuntimeState(
                health: 0.8,
                stamina: 0.7,
                fatigue: 0.2,
                wetness: 2,
                dirtiness: -1,
                movementStance: .climbing,
                equipment: baseSave.runtimeState.equipment
            )
        )
        let data = try AtomicFileWriter.makeJSONEncoder().encode(save)
        let decoded = try AtomicFileWriter.makeJSONDecoder().decode(
            CharacterCustomizationSave.self,
            from: data
        )

        XCTAssertEqual(decoded, save)
        XCTAssertTrue(decoded.isRegenerable)
        XCTAssertEqual(decoded.runtimeState.wetness, 1, accuracy: 0.0001)
        XCTAssertEqual(decoded.runtimeState.dirtiness, 0, accuracy: 0.0001)
        XCTAssertEqual(decoded.runtimeState.movementStance, .climbing)
    }

    func testPlayerProfileKeepsCharacterCustomizationAcrossProfileMutations() throws {
        let customization = CharacterCustomizationSave.defaultPlayer(worldSeed: WorldSeed(88))
        let profile = PlayerProfile(displayName: "Tester")
            .withCharacterCustomization(customization)
            .recordingRecentSeed("step-16")
            .opening(slotID: "slot-character")
        let data = try AtomicFileWriter.makeJSONEncoder().encode(profile)
        let decoded = try AtomicFileWriter.makeJSONDecoder().decode(PlayerProfile.self, from: data)

        XCTAssertEqual(profile.characterCustomization, customization)
        XCTAssertEqual(profile.recentSeeds, ["step-16"])
        XCTAssertEqual(profile.lastOpenedSlotID, "slot-character")
        XCTAssertEqual(decoded, profile)
    }
}
