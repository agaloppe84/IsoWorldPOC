import XCTest
@testable import EngineCore

final class AnimationSystemTests: XCTestCase {
    func testAnimationSamplerInterpolatesWalkPoseAndFootContacts() {
        let body = CharacterBodyParameters()
        let clip = AnimationClip.humanoidWalk(body: body)
        let sampler = AnimationSampler()

        let leftPlant = sampler.sample(clip: clip, time: clip.duration * 0.10)
        let rightPlant = sampler.sample(clip: clip, time: clip.duration * 0.55)

        XCTAssertEqual(leftPlant.clipID, .humanoidWalk)
        XCTAssertEqual(leftPlant.footPlantWeights.left, 1)
        XCTAssertEqual(leftPlant.footPlantWeights.right, 0)
        XCTAssertEqual(rightPlant.footPlantWeights.left, 0)
        XCTAssertEqual(rightPlant.footPlantWeights.right, 1)
        XCTAssertNotNil(leftPlant.pose.joint(.leftFoot))
        XCTAssertGreaterThan(clip.rootMotionMetersPerCycle, 0)
    }

    func testSurfaceContactResolverUsesMaterialWetnessAndTraversalClass() {
        let sample = terrainSample(
            biome: .marsh,
            slope: 0.45,
            roughness: 0.70,
            moisture: 0.92,
            waterDepth: 0.08,
            walkability: 0.45
        )
        let patch = SurfaceContactResolver().patch(
            for: sample,
            worldX: 12,
            worldZ: -4,
            coordinate: .origin,
            surfaceClass: .steep
        )

        XCTAssertEqual(patch.materialKind, .mud)
        XCTAssertTrue(patch.tags.contains(.mud))
        XCTAssertTrue(patch.tags.contains(.water))
        XCTAssertTrue(patch.tags.contains(.soft))
        XCTAssertTrue(patch.tags.contains(.slippery))
        XCTAssertTrue(patch.tags.contains(.smallObstacle))
        XCTAssertLessThan(patch.friction, 0.30)
        XCTAssertGreaterThan(patch.wetness, 0.90)
        XCTAssertEqual(patch.surfaceClass, .steep)
    }

    func testFootIKLocksPlantedFootAndCompensatesPelvis() {
        let patch = SurfaceContactResolver().patch(
            for: terrainSample(biome: .grassland, height: 1.0),
            worldX: 0,
            worldZ: 0,
            coordinate: .origin,
            surfaceClass: .walkable
        )
        let solver = FootIKSolver()
        let first = solver.solve(FootIKInput(
            side: .left,
            animatedFootPosition: SIMD3<Float>(0, 0.35, 0),
            legLength: 0.9,
            plantWeight: 1,
            contactPatch: patch
        ))
        let second = solver.solve(FootIKInput(
            side: .left,
            animatedFootPosition: SIMD3<Float>(0.2, 0.35, 0.1),
            legLength: 0.9,
            plantWeight: 1,
            contactPatch: patch,
            previousLock: first.lockState
        ))

        XCTAssertNotNil(first.lockState)
        XCTAssertNotNil(second.lockState)
        XCTAssertEqual(first.target.y, 1.018, accuracy: 0.0001)
        XCTAssertLessThan(first.pelvisOffsetY, 0)
        XCTAssertLessThan(second.target.x, 0.2)
        XCTAssertEqual(second.weight, 1)
    }

    func testCharacterMotorUsesSurfaceFrictionAndBlocksUnsafePatches() {
        let body = CharacterBodyParameters()
        let runtime = CharacterRuntimeState()
        let safePatch = SurfaceContactResolver().patch(
            for: terrainSample(biome: .grassland, height: 0.3),
            worldX: 0,
            worldZ: 0,
            coordinate: .origin,
            surfaceClass: .walkable
        )
        let blockedPatch = SurfaceContactResolver().patch(
            for: terrainSample(
                biome: .freshwater,
                height: 0.3,
                waterDepth: 0.5,
                walkability: 0
            ),
            worldX: 0,
            worldZ: 0,
            coordinate: .origin,
            surfaceClass: .blocked
        )
        let motor = CharacterMotor()

        let safe = motor.update(CharacterMotorInput(
            currentPosition: SIMD3<Float>(0, 0.32, 0),
            desiredMove: SIMD2<Float>(1, 0),
            deltaTime: 0.25,
            body: body,
            runtimeState: runtime,
            groundPatch: safePatch
        ))
        let blocked = motor.update(CharacterMotorInput(
            currentPosition: SIMD3<Float>(0, 0.32, 0),
            desiredMove: SIMD2<Float>(1, 0),
            deltaTime: 0.25,
            body: body,
            runtimeState: runtime,
            groundPatch: blockedPatch
        ))

        XCTAssertFalse(safe.movementBlocked)
        XCTAssertGreaterThan(safe.position.x, 0)
        XCTAssertEqual(safe.position.y, 0.32, accuracy: 0.0001)
        XCTAssertTrue(blocked.movementBlocked)
        XCTAssertEqual(blocked.velocity.x, 0, accuracy: 0.0001)
    }

    func testFootstepEmitterCreatesMaterialAwareEventsOnPlantTransition() {
        var emitter = FootstepEventEmitter()
        let patch = SurfaceContactResolver().patch(
            for: terrainSample(biome: .mountain),
            worldX: 2,
            worldZ: 3,
            coordinate: .origin,
            surfaceClass: .walkable
        )
        let events = emitter.events(
            time: 0.25,
            previousPosition: SIMD3<Float>(0, 0, 0),
            currentPosition: SIMD3<Float>(0.2, 0, 0),
            weights: AnimationFootPlantWeights(left: 1, right: 0),
            patchesByFoot: [.left: patch]
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .heelStrike)
        XCTAssertEqual(events[0].side, .left)
        XCTAssertEqual(events[0].materialKind, .rock)
        XCTAssertGreaterThan(events[0].intensity, 0)
    }

    private func terrainSample(
        biome: BiomeType,
        height: Float = 0,
        slope: Float = 0,
        roughness: Float = 0.2,
        moisture: Float = 0.2,
        waterDepth: Float = 0,
        walkability: Float = 1
    ) -> TerrainSample {
        TerrainSample(
            localX: 4,
            localZ: 5,
            worldX: 4,
            worldZ: 5,
            height: height,
            normal: SIMD3<Float>(0, 1, 0),
            slope: slope,
            curvature: roughness,
            roughness: roughness,
            moisture: moisture,
            temperature: 0.55,
            materialWeights: MaterialWeights(primaryBiome: Biome.definition(for: biome)),
            waterDepth: waterDepth,
            walkability: walkability
        )
    }
}
