public extension TerrainGeometryBuffers {
    func indices(for level: LODLevel) -> [UInt32] {
        let stride = level.terrainIndexStride
        guard stride > 1 else {
            return indices
        }

        return edgePreservingIndices(stride: stride)
    }

    func triangleCount(for level: LODLevel) -> Int {
        indices(for: level).count / 3
    }

    private func edgePreservingIndices(stride: Int) -> [UInt32] {
        let cellCount = resolution - 1
        guard cellCount > 1 else {
            return indices
        }

        var lodIndices: [UInt32] = []
        let estimatedInteriorCells = ((cellCount - 2) / stride + 1) * ((cellCount - 2) / stride + 1)
        let borderCells = cellCount * 4 - 4
        lodIndices.reserveCapacity((estimatedInteriorCells + borderCells) * 6)

        for localZ in 0..<cellCount {
            for localX in 0..<cellCount where isBorderCell(localX: localX, localZ: localZ, cellCount: cellCount) {
                appendCellIndices(
                    localX: localX,
                    localZ: localZ,
                    nextX: localX + 1,
                    nextZ: localZ + 1,
                    to: &lodIndices
                )
            }
        }

        var localZ = 1
        while localZ < cellCount - 1 {
            let nextZ = min(localZ + stride, cellCount - 1)
            var localX = 1

            while localX < cellCount - 1 {
                let nextX = min(localX + stride, cellCount - 1)
                appendCellIndices(
                    localX: localX,
                    localZ: localZ,
                    nextX: nextX,
                    nextZ: nextZ,
                    to: &lodIndices
                )
                localX = nextX
            }

            localZ = nextZ
        }

        return lodIndices
    }

    private func isBorderCell(localX: Int, localZ: Int, cellCount: Int) -> Bool {
        localX == 0 || localZ == 0 || localX == cellCount - 1 || localZ == cellCount - 1
    }

    private func appendCellIndices(
        localX: Int,
        localZ: Int,
        nextX: Int,
        nextZ: Int,
        to indices: inout [UInt32]
    ) {
        let topLeft = vertexIndex(localX: localX, localZ: localZ)
        let topRight = vertexIndex(localX: nextX, localZ: localZ)
        let bottomLeft = vertexIndex(localX: localX, localZ: nextZ)
        let bottomRight = vertexIndex(localX: nextX, localZ: nextZ)

        indices.append(topLeft)
        indices.append(bottomLeft)
        indices.append(topRight)
        indices.append(topRight)
        indices.append(bottomLeft)
        indices.append(bottomRight)
    }

    private func vertexIndex(localX: Int, localZ: Int) -> UInt32 {
        UInt32(localZ * resolution + localX)
    }
}
