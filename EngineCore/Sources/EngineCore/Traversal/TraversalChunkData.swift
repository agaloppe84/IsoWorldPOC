public struct TraversalChunkData: Equatable, Codable, Sendable {
    public let seed: WorldSeed
    public let coordinate: ChunkCoordinate
    public let resolution: Int
    public let climbabilityMap: ClimbabilityMap
    public let ledges: [LedgeCandidate]
    public let ropeAnchors: [RopeAnchorCandidate]
    public let stairAttachCandidates: [StairAttachCandidate]
    public let verticalTraversalCandidates: [VerticalTraversalCandidate]

    public init(
        seed: WorldSeed,
        coordinate: ChunkCoordinate,
        resolution: Int,
        climbabilityMap: ClimbabilityMap,
        ledges: [LedgeCandidate],
        ropeAnchors: [RopeAnchorCandidate],
        stairAttachCandidates: [StairAttachCandidate],
        verticalTraversalCandidates: [VerticalTraversalCandidate]
    ) {
        self.seed = seed
        self.coordinate = coordinate
        self.resolution = resolution
        self.climbabilityMap = climbabilityMap
        self.ledges = ledges
        self.ropeAnchors = ropeAnchors
        self.stairAttachCandidates = stairAttachCandidates
        self.verticalTraversalCandidates = verticalTraversalCandidates
    }

    public init(sampleGrid: TerrainSampleGrid) {
        let climbabilityMap = ClimbabilityMap(sampleGrid: sampleGrid)
        let builder = CandidateBuilder(grid: sampleGrid, climbabilityMap: climbabilityMap)
        let ledges = builder.makeLedges()
        let ropeAnchors = builder.makeRopeAnchors(from: ledges)
        let stairAttachCandidates = builder.makeStairAttachCandidates(from: ledges)
        let verticalTraversalCandidates = builder.makeVerticalTraversalCandidates(
            ledges: ledges,
            ropeAnchors: ropeAnchors,
            stairAttachCandidates: stairAttachCandidates
        )

        self.init(
            seed: sampleGrid.seed,
            coordinate: sampleGrid.coordinate,
            resolution: sampleGrid.resolution,
            climbabilityMap: climbabilityMap,
            ledges: ledges,
            ropeAnchors: ropeAnchors,
            stairAttachCandidates: stairAttachCandidates,
            verticalTraversalCandidates: verticalTraversalCandidates
        )
    }

    public func surfaceClass(localX: Int, localZ: Int) -> TraversalSurfaceClass {
        climbabilityMap.surfaceClass(localX: localX, localZ: localZ)
    }

    public func surfaceClass(nearestLocalX: Float, nearestLocalZ: Float) -> TraversalSurfaceClass {
        climbabilityMap.surfaceClass(nearestLocalX: nearestLocalX, nearestLocalZ: nearestLocalZ)
    }

    public func ledgeScore(localX: Int, localZ: Int) -> Float {
        climbabilityMap.ledgeScore(localX: localX, localZ: localZ)
    }

    public var walkableRatio: Float {
        climbabilityMap.walkableRatio
    }

    public var climbableRatio: Float {
        climbabilityMap.climbableRatio
    }

    public var blockedRatio: Float {
        climbabilityMap.blockedRatio
    }

    public var candidateCount: Int {
        ledges.count + ropeAnchors.count + stairAttachCandidates.count + verticalTraversalCandidates.count
    }
}

private struct CandidateBuilder {
    let grid: TerrainSampleGrid
    let climbabilityMap: ClimbabilityMap

    func makeLedges() -> [LedgeCandidate] {
        var candidates: [LedgeCandidate] = []

        for localZ in 1..<(grid.resolution - 1) {
            for localX in 1..<(grid.resolution - 1) {
                let ledgeScore = climbabilityMap.ledgeScore(localX: localX, localZ: localZ)

                guard ledgeScore >= 0.48 else {
                    continue
                }

                let sample = grid[localX, localZ]
                let edge = strongestEdge(localX: localX, localZ: localZ)
                let topAccessScore = accessScore(edge.higher)
                let bottomAccessScore = accessScore(edge.lower)
                let attachableScore = clamped01(
                    ledgeScore * 0.52 +
                    rockStability(sample) * 0.24 +
                    min(topAccessScore, bottomAccessScore) * 0.24
                )

                guard topAccessScore >= 0.22 || bottomAccessScore >= 0.22 else {
                    continue
                }

                candidates.append(LedgeCandidate(
                    id: candidateID(kind: "ledge", localX: localX, localZ: localZ),
                    coordinate: grid.coordinate,
                    localX: localX,
                    localZ: localZ,
                    position: position(sample),
                    normal: normal(sample),
                    slopeDegrees: TraversalSurfaceClass.slopeDegrees(for: sample.slope),
                    rockStability: rockStability(sample),
                    ledgeScore: ledgeScore,
                    climbGrip: sample.climbability,
                    fallHeight: edge.verticalDistance,
                    topAccessScore: topAccessScore,
                    bottomAccessScore: bottomAccessScore,
                    attachableScore: attachableScore
                ))
            }
        }

        return top(candidates, limit: 18) { first, second in
            if first.ledgeScore != second.ledgeScore {
                return first.ledgeScore > second.ledgeScore
            }

            return first.id < second.id
        }
    }

    func makeRopeAnchors(from ledges: [LedgeCandidate]) -> [RopeAnchorCandidate] {
        let anchors = ledges.compactMap { ledge -> RopeAnchorCandidate? in
            guard ledge.fallHeight >= 0.50, ledge.attachableScore >= 0.45 else {
                return nil
            }

            let edge = strongestEdge(localX: ledge.localX, localZ: ledge.localZ)
            let score = clamped01(
                ledge.attachableScore * 0.46 +
                ledge.rockStability * 0.22 +
                ledge.topAccessScore * 0.16 +
                ledge.bottomAccessScore * 0.16
            )

            return RopeAnchorCandidate(
                id: candidateID(kind: "rope", localX: ledge.localX, localZ: ledge.localZ),
                coordinate: grid.coordinate,
                localX: ledge.localX,
                localZ: ledge.localZ,
                anchorPosition: position(edge.higher),
                lowerPosition: position(edge.lower),
                verticalDistance: edge.verticalDistance,
                rockStability: ledge.rockStability,
                topAccessScore: ledge.topAccessScore,
                bottomAccessScore: ledge.bottomAccessScore,
                score: score
            )
        }

        return top(anchors, limit: 8) { first, second in
            if first.score != second.score {
                return first.score > second.score
            }

            return first.id < second.id
        }
    }

    func makeStairAttachCandidates(from ledges: [LedgeCandidate]) -> [StairAttachCandidate] {
        let stairs = ledges.compactMap { ledge -> StairAttachCandidate? in
            let slopeDegrees = ledge.slopeDegrees

            guard ledge.fallHeight >= 0.22,
                  ledge.fallHeight <= 1.90,
                  slopeDegrees >= 22,
                  slopeDegrees <= 70,
                  ledge.attachableScore >= 0.36
            else {
                return nil
            }

            let edge = strongestEdge(localX: ledge.localX, localZ: ledge.localZ)
            let widthScore = lateralWidthScore(localX: ledge.localX, localZ: ledge.localZ)
            let difficulty = clamped01(
                ledge.fallHeight * 0.22 +
                smoothStep(edge0: 28, edge1: 70, slopeDegrees) * 0.52 +
                (1 - widthScore) * 0.26
            )

            return StairAttachCandidate(
                id: candidateID(kind: "stairs", localX: ledge.localX, localZ: ledge.localZ),
                coordinate: grid.coordinate,
                localX: ledge.localX,
                localZ: ledge.localZ,
                start: position(edge.lower),
                end: position(edge.higher),
                stepCount: max(3, Int((ledge.fallHeight / 0.18).rounded(.up))),
                widthScore: widthScore,
                slopeDegrees: slopeDegrees,
                attachableScore: ledge.attachableScore,
                difficulty: difficulty
            )
        }

        return top(stairs, limit: 10) { first, second in
            if first.attachableScore != second.attachableScore {
                return first.attachableScore > second.attachableScore
            }

            return first.id < second.id
        }
    }

    func makeVerticalTraversalCandidates(
        ledges: [LedgeCandidate],
        ropeAnchors: [RopeAnchorCandidate],
        stairAttachCandidates: [StairAttachCandidate]
    ) -> [VerticalTraversalCandidate] {
        var candidates: [VerticalTraversalCandidate] = []

        for anchor in ropeAnchors {
            candidates.append(VerticalTraversalCandidate(
                id: candidateID(kind: "route-rope", localX: anchor.localX, localZ: anchor.localZ),
                kind: .rope,
                coordinate: grid.coordinate,
                sourceLocalX: anchor.localX,
                sourceLocalZ: anchor.localZ,
                start: anchor.lowerPosition,
                end: anchor.anchorPosition,
                difficulty: clamped01(0.28 + anchor.verticalDistance * 0.18 + (1 - anchor.rockStability) * 0.32),
                confidence: anchor.score,
                requiredTool: .rope
            ))
        }

        for stair in stairAttachCandidates {
            candidates.append(VerticalTraversalCandidate(
                id: candidateID(kind: "route-stairs", localX: stair.localX, localZ: stair.localZ),
                kind: .carvedStairs,
                coordinate: grid.coordinate,
                sourceLocalX: stair.localX,
                sourceLocalZ: stair.localZ,
                start: stair.start,
                end: stair.end,
                difficulty: stair.difficulty,
                confidence: stair.attachableScore,
                requiredTool: .none
            ))
        }

        for ledge in ledges.prefix(6) {
            guard ledge.ledgeScore >= 0.58 else {
                continue
            }

            let edge = strongestEdge(localX: ledge.localX, localZ: ledge.localZ)
            candidates.append(VerticalTraversalCandidate(
                id: candidateID(kind: "route-ledge", localX: ledge.localX, localZ: ledge.localZ),
                kind: .naturalLedges,
                coordinate: grid.coordinate,
                sourceLocalX: ledge.localX,
                sourceLocalZ: ledge.localZ,
                start: position(edge.lower),
                end: position(edge.higher),
                difficulty: clamped01(0.22 + ledge.fallHeight * 0.16 + (1 - ledge.climbGrip) * 0.24),
                confidence: ledge.ledgeScore,
                requiredTool: ledge.climbGrip >= 0.55 ? .none : .climbingGear
            ))
        }

        return top(candidates, limit: 20) { first, second in
            if first.confidence != second.confidence {
                return first.confidence > second.confidence
            }

            return first.id < second.id
        }
    }

    private func strongestEdge(localX: Int, localZ: Int) -> TraversalEdge {
        let sample = grid[localX, localZ]
        let candidates = neighborSamples(localX: localX, localZ: localZ).map { neighbor -> TraversalEdge in
            if sample.height >= neighbor.height {
                return TraversalEdge(higher: sample, lower: neighbor)
            }

            return TraversalEdge(higher: neighbor, lower: sample)
        }

        return candidates.max { first, second in
            first.verticalDistance < second.verticalDistance
        } ?? TraversalEdge(higher: sample, lower: sample)
    }

    private func neighborSamples(localX: Int, localZ: Int) -> [TerrainSample] {
        [
            (localX - 1, localZ),
            (localX + 1, localZ),
            (localX, localZ - 1),
            (localX, localZ + 1),
        ].compactMap { x, z in
            grid.contains(localX: x, localZ: z) ? grid[x, z] : nil
        }
    }

    private func lateralWidthScore(localX: Int, localZ: Int) -> Float {
        let samples = [
            (localX - 1, localZ - 1),
            (localX + 1, localZ - 1),
            (localX - 1, localZ + 1),
            (localX + 1, localZ + 1),
        ].compactMap { x, z in
            grid.contains(localX: x, localZ: z) ? grid[x, z] : nil
        }

        guard !samples.isEmpty else {
            return 0
        }

        let walkableCount = samples.filter { sample in
            TraversalSurfaceClass.classify(sample) == .walkable || TraversalSurfaceClass.classify(sample) == .steep
        }.count

        return Float(walkableCount) / Float(samples.count)
    }

    private func accessScore(_ sample: TerrainSample) -> Float {
        switch TraversalSurfaceClass.classify(sample) {
        case .walkable:
            return max(sample.walkability, 0.55)
        case .steep:
            return sample.walkability * 0.62
        case .climbable:
            return sample.climbability * 0.72
        case .dangerous:
            return sample.climbability * 0.24
        case .blocked:
            return 0
        }
    }

    private func rockStability(_ sample: TerrainSample) -> Float {
        clamped01(
            0.36 +
            sample.featureMasks.mountain * 0.26 +
            sample.featureMasks.cliff * 0.24 +
            (1 - sample.roughness) * 0.14 -
            sample.featureMasks.water * 0.32
        )
    }

    private func position(_ sample: TerrainSample) -> WorldPosition {
        WorldPosition(
            x: Float(sample.worldX),
            y: sample.height,
            z: Float(sample.worldZ)
        )
    }

    private func normal(_ sample: TerrainSample) -> WorldPosition {
        WorldPosition(
            x: sample.normal.x,
            y: sample.normal.y,
            z: sample.normal.z
        )
    }

    private func candidateID(kind: String, localX: Int, localZ: Int) -> UInt64 {
        var hasher = StableHash.Builder()
        hasher.combine(grid.seed)
        hasher.combine(SeedDomain.traversal)
        hasher.combine(grid.coordinate)
        hasher.combine(kind)
        hasher.combine(localX)
        hasher.combine(localZ)
        return hasher.finalize().value
    }

    private func top<T>(
        _ candidates: [T],
        limit: Int,
        areInIncreasingOrder: (T, T) -> Bool
    ) -> [T] {
        Array(candidates.sorted(by: areInIncreasingOrder).prefix(limit))
    }

    private func smoothStep(edge0: Float, edge1: Float, _ value: Float) -> Float {
        guard edge0 != edge1 else {
            return value < edge0 ? 0 : 1
        }

        let amount = clamped01((value - edge0) / (edge1 - edge0))
        return amount * amount * (3 - 2 * amount)
    }

    private func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

private struct TraversalEdge {
    let higher: TerrainSample
    let lower: TerrainSample

    var verticalDistance: Float {
        max(higher.height - lower.height, 0)
    }
}
