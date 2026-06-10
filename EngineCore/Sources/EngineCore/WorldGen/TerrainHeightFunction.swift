public struct TerrainHeightFunction: Sendable {
    public let seed: WorldSeed

    public init(seed: WorldSeed) {
        self.seed = seed
    }

    public func heightAt(worldX: Int, worldZ: Int, verticalChunk: Int = 0) -> Float {
        let broad = valueNoise(worldX: worldX, worldZ: worldZ, cellSize: 32, salt: 0xA11C_E001) * 5.0
        let medium = valueNoise(worldX: worldX, worldZ: worldZ, cellSize: 16, salt: 0xB22D_E002) * 2.0
        let detail = valueNoise(worldX: worldX, worldZ: worldZ, cellSize: 8, salt: 0xC33E_D003) * 0.75
        let verticalOffset = Float(verticalChunk) * 6.0

        return broad + medium + detail + verticalOffset
    }

    private func valueNoise(worldX: Int, worldZ: Int, cellSize: Int, salt: UInt64) -> Float {
        let cellX = floorDiv(worldX, by: cellSize)
        let cellZ = floorDiv(worldZ, by: cellSize)
        let fractionX = Float(positiveRemainder(worldX, by: cellSize)) / Float(cellSize)
        let fractionZ = Float(positiveRemainder(worldZ, by: cellSize)) / Float(cellSize)

        let v00 = latticeValue(cellX: cellX, cellZ: cellZ, salt: salt)
        let v10 = latticeValue(cellX: cellX + 1, cellZ: cellZ, salt: salt)
        let v01 = latticeValue(cellX: cellX, cellZ: cellZ + 1, salt: salt)
        let v11 = latticeValue(cellX: cellX + 1, cellZ: cellZ + 1, salt: salt)
        let smoothX = smoothStep(fractionX)
        let smoothZ = smoothStep(fractionZ)

        return lerp(
            lerp(v00, v10, smoothX),
            lerp(v01, v11, smoothX),
            smoothZ
        )
    }

    private func latticeValue(cellX: Int, cellZ: Int, salt: UInt64) -> Float {
        var random = SeededRandom(seedValue: latticeSeed(cellX: cellX, cellZ: cellZ, salt: salt))
        let value = random.next() >> 40
        let unit = Float(value) / Float(0x00ff_ffff)

        return unit * 2.0 - 1.0
    }

    private func latticeSeed(cellX: Int, cellZ: Int, salt: UInt64) -> UInt64 {
        var value = seed.value ^ salt
        value = mix(value, with: cellX)
        value = mix(value, with: cellZ)
        return value
    }

    private func mix(_ current: UInt64, with value: Int) -> UInt64 {
        var mixed = current ^ UInt64(bitPattern: Int64(value))
        mixed &*= 0x9E37_79B9_7F4A_7C15
        mixed ^= mixed >> 30
        mixed &*= 0xBF58_476D_1CE4_E5B9
        mixed ^= mixed >> 27
        mixed &*= 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    private func floorDiv(_ value: Int, by divisor: Int) -> Int {
        let quotient = value / divisor
        let remainder = value % divisor

        if remainder < 0 {
            return quotient - 1
        }

        return quotient
    }

    private func positiveRemainder(_ value: Int, by divisor: Int) -> Int {
        let remainder = value % divisor

        if remainder < 0 {
            return remainder + divisor
        }

        return remainder
    }

    private func smoothStep(_ value: Float) -> Float {
        value * value * (3.0 - 2.0 * value)
    }

    private func lerp(_ start: Float, _ end: Float, _ amount: Float) -> Float {
        start + (end - start) * amount
    }
}
