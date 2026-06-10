public struct ChunkCoordinate: Hashable, Codable, Sendable {
    public static let origin = ChunkCoordinate(x: 0, y: 0, z: 0)

    public let x: Int
    public let y: Int
    public let z: Int

    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    public func offsetBy(x deltaX: Int = 0, y deltaY: Int = 0, z deltaZ: Int = 0) -> ChunkCoordinate {
        ChunkCoordinate(
            x: x + deltaX,
            y: y + deltaY,
            z: z + deltaZ
        )
    }
}

public struct TerrainGeometryBuffers: Equatable, Codable, Sendable {
    public struct Position: Equatable, Hashable, Codable, Sendable {
        public let x: Float
        public let y: Float
        public let z: Float
    }

    public struct Normal: Equatable, Hashable, Codable, Sendable {
        public let x: Float
        public let y: Float
        public let z: Float
    }

    public struct TextureCoordinate: Equatable, Hashable, Codable, Sendable {
        public let u: Float
        public let v: Float
    }

    public let resolution: Int
    public let positions: [Position]
    public let normals: [Normal]
    public let textureCoordinates: [TextureCoordinate]
    public let indices: [UInt32]

    public init(
        resolution: Int,
        positions: [Position],
        normals: [Normal],
        textureCoordinates: [TextureCoordinate],
        indices: [UInt32]
    ) {
        self.resolution = resolution
        self.positions = positions
        self.normals = normals
        self.textureCoordinates = textureCoordinates
        self.indices = indices
    }
}

public struct TerrainSampler: Sendable {
    public struct Sample: Equatable, Sendable {
        public let height: Float
        public let slope: Float

        public init(height: Float, slope: Float) {
            self.height = height
            self.slope = slope
        }

        public func isWalkable(maxSlope: Float) -> Bool {
            precondition(maxSlope >= 0, "maxSlope must be non-negative.")

            return slope <= maxSlope
        }
    }

    public let resolution: Int
    public let horizontalScale: Float
    public let originX: Float
    public let originZ: Float

    private let heights: [Float]

    public init(
        geometry: TerrainGeometryBuffers,
        originX: Float = 0,
        originZ: Float = 0
    ) {
        precondition(geometry.resolution > 1, "TerrainSampler requires at least two samples per axis.")
        precondition(
            geometry.positions.count == geometry.resolution * geometry.resolution,
            "TerrainSampler requires a square terrain geometry."
        )

        self.resolution = geometry.resolution
        self.horizontalScale = Self.deriveHorizontalScale(from: geometry)
        self.originX = originX
        self.originZ = originZ
        self.heights = geometry.positions.map(\.y)
    }

    public func sampleAt(x: Float, z: Float) -> Sample {
        Sample(
            height: heightAt(x: x, z: z),
            slope: slopeAt(x: x, z: z)
        )
    }

    public func isWalkableAt(x: Float, z: Float, maxSlope: Float) -> Bool {
        sampleAt(x: x, z: z).isWalkable(maxSlope: maxSlope)
    }

    public func heightAt(x: Float, z: Float) -> Float {
        let localX = gridCoordinate(for: x, origin: originX)
        let localZ = gridCoordinate(for: z, origin: originZ)
        let minX = Int(localX.rounded(.down))
        let minZ = Int(localZ.rounded(.down))
        let maxX = min(minX + 1, resolution - 1)
        let maxZ = min(minZ + 1, resolution - 1)
        let blendX = localX - Float(minX)
        let blendZ = localZ - Float(minZ)

        let h00 = height(localX: minX, localZ: minZ)
        let h10 = height(localX: maxX, localZ: minZ)
        let h01 = height(localX: minX, localZ: maxZ)
        let h11 = height(localX: maxX, localZ: maxZ)

        return lerp(
            lerp(h00, h10, blendX),
            lerp(h01, h11, blendX),
            blendZ
        )
    }

    public func slopeAt(x: Float, z: Float) -> Float {
        let left = heightAt(x: x - horizontalScale, z: z)
        let right = heightAt(x: x + horizontalScale, z: z)
        let back = heightAt(x: x, z: z - horizontalScale)
        let forward = heightAt(x: x, z: z + horizontalScale)
        let xSlope = (right - left) / (horizontalScale * 2)
        let zSlope = (forward - back) / (horizontalScale * 2)

        return (xSlope * xSlope + zSlope * zSlope).squareRoot()
    }

    private static func deriveHorizontalScale(from geometry: TerrainGeometryBuffers) -> Float {
        let first = geometry.positions[0]
        let second = geometry.positions[1]
        let scale = abs(second.x - first.x)

        precondition(scale > 0, "TerrainSampler requires positive horizontal spacing.")
        return scale
    }

    private func gridCoordinate(for value: Float, origin: Float) -> Float {
        let gridValue = (value - origin) / horizontalScale
        return clamped(gridValue, lowerBound: 0, upperBound: Float(resolution - 1))
    }

    private func height(localX: Int, localZ: Int) -> Float {
        heights[localZ * resolution + localX]
    }

    private func clamped(_ value: Float, lowerBound: Float, upperBound: Float) -> Float {
        min(max(value, lowerBound), upperBound)
    }

    private func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }
}

public extension ChunkCoordinate {
    func makeTerrainGeometry(
        seed: WorldSeed,
        horizontalScale: Float,
        verticalScale: Float
    ) -> TerrainGeometryBuffers {
        TerrainGeometryBufferBuilder(
            seed: seed,
            coordinate: self,
            horizontalScale: horizontalScale,
            verticalScale: verticalScale
        ).build()
    }
}

private struct TerrainGeometryBufferBuilder {
    private static let resolution = ChunkHeightmap.resolution
    private static let sampleCount = resolution * resolution

    let coordinate: ChunkCoordinate
    let horizontalScale: Float
    let verticalScale: Float
    let heightFunction: TerrainHeightFunction

    init(
        seed: WorldSeed,
        coordinate: ChunkCoordinate,
        horizontalScale: Float,
        verticalScale: Float
    ) {
        self.coordinate = coordinate
        self.horizontalScale = horizontalScale
        self.verticalScale = verticalScale
        self.heightFunction = TerrainHeightFunction(seed: seed)
    }

    func build() -> TerrainGeometryBuffers {
        var positions: [TerrainGeometryBuffers.Position] = []
        var normals: [TerrainGeometryBuffers.Normal] = []
        var textureCoordinates: [TerrainGeometryBuffers.TextureCoordinate] = []
        var indices: [UInt32] = []

        positions.reserveCapacity(Self.sampleCount)
        normals.reserveCapacity(Self.sampleCount)
        textureCoordinates.reserveCapacity(Self.sampleCount)
        indices.reserveCapacity((Self.resolution - 1) * (Self.resolution - 1) * 6)

        for localZ in 0..<Self.resolution {
            for localX in 0..<Self.resolution {
                let height = height(localX: localX, localZ: localZ)
                positions.append(
                    TerrainGeometryBuffers.Position(
                        x: Float(localX) * horizontalScale,
                        y: height * verticalScale,
                        z: Float(localZ) * horizontalScale
                    )
                )
                textureCoordinates.append(
                    TerrainGeometryBuffers.TextureCoordinate(
                        u: Float(localX) / Float(Self.resolution - 1),
                        v: Float(localZ) / Float(Self.resolution - 1)
                    )
                )
            }
        }

        for localZ in 0..<Self.resolution {
            for localX in 0..<Self.resolution {
                normals.append(normal(localX: localX, localZ: localZ))
            }
        }

        for localZ in 0..<(Self.resolution - 1) {
            for localX in 0..<(Self.resolution - 1) {
                let topLeft = vertexIndex(localX: localX, localZ: localZ)
                let topRight = vertexIndex(localX: localX + 1, localZ: localZ)
                let bottomLeft = vertexIndex(localX: localX, localZ: localZ + 1)
                let bottomRight = vertexIndex(localX: localX + 1, localZ: localZ + 1)

                indices.append(topLeft)
                indices.append(bottomLeft)
                indices.append(topRight)
                indices.append(topRight)
                indices.append(bottomLeft)
                indices.append(bottomRight)
            }
        }

        return TerrainGeometryBuffers(
            resolution: Self.resolution,
            positions: positions,
            normals: normals,
            textureCoordinates: textureCoordinates,
            indices: indices
        )
    }

    private func normal(localX: Int, localZ: Int) -> TerrainGeometryBuffers.Normal {
        let centerWorldX = worldX(localX: localX)
        let centerWorldZ = worldZ(localZ: localZ)
        let left = heightAtWorld(worldX: centerWorldX - 1, worldZ: centerWorldZ) * verticalScale
        let right = heightAtWorld(worldX: centerWorldX + 1, worldZ: centerWorldZ) * verticalScale
        let back = heightAtWorld(worldX: centerWorldX, worldZ: centerWorldZ - 1) * verticalScale
        let forward = heightAtWorld(worldX: centerWorldX, worldZ: centerWorldZ + 1) * verticalScale

        return normalizedNormal(x: left - right, y: horizontalScale * 2.0, z: back - forward)
    }

    private func normalizedNormal(x: Float, y: Float, z: Float) -> TerrainGeometryBuffers.Normal {
        let length = (x * x + y * y + z * z).squareRoot()

        if length == 0 {
            return TerrainGeometryBuffers.Normal(x: 0, y: 1, z: 0)
        }

        return TerrainGeometryBuffers.Normal(
            x: x / length,
            y: y / length,
            z: z / length
        )
    }

    private func height(localX: Int, localZ: Int) -> Float {
        heightAtWorld(worldX: worldX(localX: localX), worldZ: worldZ(localZ: localZ))
    }

    private func heightAtWorld(worldX: Int, worldZ: Int) -> Float {
        heightFunction.heightAt(worldX: worldX, worldZ: worldZ, verticalChunk: coordinate.y)
    }

    private func worldX(localX: Int) -> Int {
        coordinate.x * ChunkHeightmap.gridStride + localX
    }

    private func worldZ(localZ: Int) -> Int {
        coordinate.z * ChunkHeightmap.gridStride + localZ
    }

    private func vertexIndex(localX: Int, localZ: Int) -> UInt32 {
        UInt32(localZ * Self.resolution + localX)
    }
}
