public struct TerrainMeshBuilder: Sendable {
    public let horizontalScale: Float
    public let verticalScale: Float

    public init(horizontalScale: Float, verticalScale: Float) {
        precondition(horizontalScale > 0, "horizontalScale must be positive.")

        self.horizontalScale = horizontalScale
        self.verticalScale = verticalScale
    }

    public static func build(
        from heightmap: ChunkHeightmap,
        horizontalScale: Float,
        verticalScale: Float
    ) -> TerrainMesh {
        TerrainMeshBuilder(
            horizontalScale: horizontalScale,
            verticalScale: verticalScale
        ).build(from: heightmap)
    }

    public func build(from heightmap: ChunkHeightmap) -> TerrainMesh {
        var vertices: [TerrainMesh.Vertex] = []
        var normals: [TerrainMesh.Normal] = []
        var uvs: [TerrainMesh.UV] = []
        var indices: [UInt32] = []

        vertices.reserveCapacity(ChunkHeightmap.sampleCount)
        normals.reserveCapacity(ChunkHeightmap.sampleCount)
        uvs.reserveCapacity(ChunkHeightmap.sampleCount)
        indices.reserveCapacity((ChunkHeightmap.resolution - 1) * (ChunkHeightmap.resolution - 1) * 6)

        for localZ in 0..<ChunkHeightmap.resolution {
            for localX in 0..<ChunkHeightmap.resolution {
                vertices.append(vertex(localX: localX, localZ: localZ, in: heightmap))
                normals.append(normal(localX: localX, localZ: localZ, in: heightmap))
                uvs.append(uv(localX: localX, localZ: localZ))
            }
        }

        for localZ in 0..<(ChunkHeightmap.resolution - 1) {
            for localX in 0..<(ChunkHeightmap.resolution - 1) {
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

        return TerrainMesh(
            vertices: vertices,
            normals: normals,
            uvs: uvs,
            indices: indices
        )
    }

    private func vertex(localX: Int, localZ: Int, in heightmap: ChunkHeightmap) -> TerrainMesh.Vertex {
        TerrainMesh.Vertex(
            x: Float(localX) * horizontalScale,
            y: heightmap.height(localX: localX, localZ: localZ) * verticalScale,
            z: Float(localZ) * horizontalScale
        )
    }

    private func normal(localX: Int, localZ: Int, in heightmap: ChunkHeightmap) -> TerrainMesh.Normal {
        let leftX = max(localX - 1, 0)
        let rightX = min(localX + 1, ChunkHeightmap.resolution - 1)
        let backZ = max(localZ - 1, 0)
        let forwardZ = min(localZ + 1, ChunkHeightmap.resolution - 1)

        let left = heightmap.height(localX: leftX, localZ: localZ) * verticalScale
        let right = heightmap.height(localX: rightX, localZ: localZ) * verticalScale
        let back = heightmap.height(localX: localX, localZ: backZ) * verticalScale
        let forward = heightmap.height(localX: localX, localZ: forwardZ) * verticalScale

        return TerrainMesh.Normal(
            x: left - right,
            y: horizontalScale * 2.0,
            z: back - forward
        )
    }

    private func uv(localX: Int, localZ: Int) -> TerrainMesh.UV {
        let maxCoordinate = Float(ChunkHeightmap.resolution - 1)

        return TerrainMesh.UV(
            u: Float(localX) / maxCoordinate,
            v: Float(localZ) / maxCoordinate
        )
    }

    private func vertexIndex(localX: Int, localZ: Int) -> UInt32 {
        UInt32(localZ * ChunkHeightmap.resolution + localX)
    }
}
