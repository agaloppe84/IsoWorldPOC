import XCTest
import simd
@testable import EngineCore

final class AudioSystemTests: XCTestCase {
    func testFootstepAudioRecipeSwitchesByMaterialAndIsDeterministic() throws {
        let resolver = AudioRecipeResolver()
        let context = AudioContext(
            worldSeed: WorldSeed(123),
            simulationTime: 12.5,
            listenerPosition: WorldPosition(x: 0, y: 0, z: 0)
        )
        let rockStep = makeFootstep(
            id: 1,
            materialKind: .rock,
            wetness: 0.05,
            friction: 0.75,
            intensity: 0.9
        )
        let mudStep = makeFootstep(
            id: 2,
            materialKind: .mud,
            wetness: 0.85,
            friction: 0.22,
            intensity: 0.9
        )

        let firstRock = try XCTUnwrap(resolver.makeFootstepEvent(from: rockStep, context: context))
        let repeatedRock = try XCTUnwrap(resolver.makeFootstepEvent(from: rockStep, context: context))
        let mud = try XCTUnwrap(resolver.makeFootstepEvent(from: mudStep, context: context))

        XCTAssertEqual(firstRock, repeatedRock)
        XCTAssertEqual(firstRock.recipeID, .footstep(for: .rock))
        XCTAssertEqual(mud.recipeID, .footstep(for: .mud))
        XCTAssertNotEqual(firstRock.recipeID, mud.recipeID)
        XCTAssertNotEqual(firstRock.seedContext.eventSeed, mud.seedContext.eventSeed)
        XCTAssertGreaterThan(firstRock.parameters.value(for: .gain), 0)
        XCTAssertGreaterThan(mud.parameters.value(for: .surfaceSplash), firstRock.parameters.value(for: .surfaceSplash))
        XCTAssertEqual(firstRock.surface?.materialKind, .rock)
        XCTAssertEqual(mud.surface?.materialKind, .mud)
    }

    func testWetMudSurfaceResponseRaisesSplashAndSquish() {
        let dryMud = AudioSurfaceResponse.response(for: .mud, wetness: 0.05, friction: 0.45)
        let wetMud = AudioSurfaceResponse.response(for: .mud, wetness: 0.95, friction: 0.18)

        XCTAssertGreaterThan(wetMud.splash, dryMud.splash)
        XCTAssertGreaterThan(wetMud.squish, dryMud.squish)
        XCTAssertLessThan(wetMud.gainScale, 1.3)
        XCTAssertEqual(wetMud.surfaceInfo(wetness: 0.95, friction: 0.18).materialKind, .mud)
    }

    func testAudioParameterSetDeduplicatesAndSorts() {
        let parameters = AudioParameterSet(parameters: [
            AudioParameter(id: .surfaceRoughness, value: 0.25),
            AudioParameter(id: .gain, value: 0.2),
            AudioParameter(id: .surfaceRoughness, value: 0.75),
        ])

        XCTAssertEqual(parameters.value(for: .surfaceRoughness), 0.75)
        XCTAssertEqual(parameters.value(for: .gain), 0.2)
        XCTAssertEqual(parameters.parameters.map(\.id.rawValue), [
            AudioParameterID.gain.rawValue,
            AudioParameterID.surfaceRoughness.rawValue,
        ])
    }

    func testAudioMixStateRoutesChildBusThroughMaster() {
        let mixState = AudioMixState(buses: [
            AudioBus(id: .master, gain: 0.5),
            AudioBus(id: .foley, gain: 0.25),
            AudioBus(id: .ui, gain: 0.8, isMuted: true),
        ])

        XCTAssertEqual(mixState.effectiveGain(for: .foley), 0.125, accuracy: 0.0001)
        XCTAssertEqual(mixState.effectiveGain(for: .ui), 0, accuracy: 0.0001)
        XCTAssertEqual(mixState.effectiveGain(for: .master), 0.5, accuracy: 0.0001)
    }

    private func makeFootstep(
        id: UInt64,
        materialKind: TerrainMaterialKind,
        wetness: Float,
        friction: Float,
        intensity: Float
    ) -> FootstepEvent {
        FootstepEvent(
            id: StableID(id),
            kind: .heelStrike,
            side: .left,
            time: 0.1,
            position: SIMD3<Float>(3, 0, 4),
            materialKind: materialKind,
            friction: friction,
            wetness: wetness,
            intensity: intensity
        )
    }
}
