import simd
import XCTest
@testable import EngineCore

final class FXSystemTests: XCTestCase {
    func testFootstepDustAndDecalAreStableFromMaterialAwareEvent() {
        let recipe = FXRecipe()
        let context = FXContext(worldSeed: WorldSeed(123), simulationTime: 1.25)
        let footstep = makeFootstep(
            id: 1,
            materialKind: .sand,
            wetness: 0.05,
            friction: 0.52,
            intensity: 0.90
        )

        let first = recipe.makeFootstepFX(from: [footstep], context: context)
        let second = recipe.makeFootstepFX(from: [footstep], context: context)

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.events.contains { $0.kind == .footstepDust })
        XCTAssertTrue(first.events.contains { $0.kind == .footprintDecal })
        XCTAssertFalse(first.events.contains { $0.kind == .footstepSplash })
        XCTAssertFalse(first.particles.isEmpty)
        XCTAssertEqual(first.decals.count, 1)
        XCTAssertEqual(first.particles.first?.materialKind, .sand)
        XCTAssertEqual(first.decals.first?.materialKind, .sand)
    }

    func testWetMudFootstepUsesSplashInsteadOfDust() {
        let recipe = FXRecipe()
        let footstep = makeFootstep(
            id: 2,
            materialKind: .mud,
            wetness: 0.96,
            friction: 0.18,
            intensity: 0.85
        )
        let snapshot = recipe.makeFootstepFX(
            from: [footstep],
            context: FXContext(worldSeed: WorldSeed(456), simulationTime: 2)
        )

        XCTAssertTrue(snapshot.events.contains { $0.kind == .footstepSplash })
        XCTAssertFalse(snapshot.events.contains { $0.kind == .footstepDust })
        XCTAssertFalse(snapshot.particles.isEmpty)
        XCTAssertEqual(snapshot.decals.count, 1)
    }

    func testRockImpactCanSpawnStableSparks() {
        let recipe = FXRecipe()
        let snapshot = recipe.makeImpactFX(
            sourceID: StableID(99),
            position: SIMD3<Float>(1, 0.4, -2),
            normal: SIMD3<Float>(0, 1, 0),
            materialKind: .rock,
            intensity: 1,
            context: FXContext(worldSeed: WorldSeed(789), simulationTime: 3)
        )
        let repeated = recipe.makeImpactFX(
            sourceID: StableID(99),
            position: SIMD3<Float>(1, 0.4, -2),
            normal: SIMD3<Float>(0, 1, 0),
            materialKind: .rock,
            intensity: 1,
            context: FXContext(worldSeed: WorldSeed(789), simulationTime: 3)
        )

        XCTAssertEqual(snapshot, repeated)
        XCTAssertEqual(snapshot.events.map(\.kind), [.impactSparks])
        XCTAssertFalse(snapshot.particles.isEmpty)
        XCTAssertEqual(snapshot.decals.count, 0)
    }

    func testBudgetClampsEventsParticlesAndDecals() {
        let recipe = FXRecipe()
        let footsteps = [
            makeFootstep(id: 10, materialKind: .sand, wetness: 0.05, friction: 0.5, intensity: 1),
            makeFootstep(id: 11, materialKind: .mud, wetness: 0.95, friction: 0.2, intensity: 1),
        ]
        let budget = FXBudget(
            maxEventsPerFrame: 2,
            maxParticlesPerFrame: 3,
            maxDecalsPerFrame: 1,
            maxParticlesPerBurst: 8
        )

        let snapshot = recipe.makeFootstepFX(
            from: footsteps,
            context: FXContext(worldSeed: WorldSeed(111), simulationTime: 4),
            budget: budget
        )

        XCTAssertLessThanOrEqual(snapshot.events.count, 2)
        XCTAssertLessThanOrEqual(snapshot.particles.count, 3)
        XCTAssertLessThanOrEqual(snapshot.decals.count, 1)
        XCTAssertGreaterThan(snapshot.budget.droppedEvents + snapshot.budget.droppedParticles + snapshot.budget.droppedDecals, 0)
    }

    func testFXFrameStateAdvancesAndExpiresTransientParticles() {
        let recipe = FXRecipe()
        let emitted = recipe.makeFootstepFX(
            from: [makeFootstep(id: 20, materialKind: .dirt, wetness: 0.1, friction: 0.6, intensity: 1)],
            context: FXContext(worldSeed: WorldSeed(222), simulationTime: 5)
        )
        var state = FXFrameState()
        let live = state.merge(emitted, budget: .v1Realtime)

        XCTAssertFalse(live.particles.isEmpty)
        XCTAssertFalse(live.decals.isEmpty)

        state.advance(deltaTime: 10)
        let expired = state.snapshot(budget: .v1Realtime)

        XCTAssertTrue(expired.particles.isEmpty)
        XCTAssertTrue(expired.decals.isEmpty)
    }

    func testColorAndSizeCurvesSampleOverLife() {
        let particle = FXBillboardParticle(
            id: StableID(1),
            definitionID: .footstepDust,
            materialKind: .dirt,
            position: .zero,
            velocity: .zero,
            startColor: FXColor(red: 1, green: 0, blue: 0, alpha: 1),
            endColor: FXColor(red: 0, green: 0, blue: 1, alpha: 0),
            startSize: 0.2,
            endSize: 0.8,
            lifetime: 1,
            age: 0.5,
            gravity: 0,
            seed: 1
        )

        XCTAssertEqual(particle.displaySize, 0.5, accuracy: 0.0001)
        XCTAssertEqual(particle.displayColor.red, 0.5, accuracy: 0.0001)
        XCTAssertEqual(particle.displayColor.blue, 0.5, accuracy: 0.0001)
        XCTAssertEqual(particle.displayColor.alpha, 0.5, accuracy: 0.0001)
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
            position: SIMD3<Float>(1, 0, 2),
            materialKind: materialKind,
            friction: friction,
            wetness: wetness,
            intensity: intensity
        )
    }
}
