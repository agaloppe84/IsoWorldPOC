public struct ClimateSample: Equatable, Hashable, Codable, Sendable {
    public let elevation: Float
    public let moisture: Float
    public let temperature: Float
    public let continentalness: Float
    public let altitude: Float
    public let slope: Float
    public let distanceToWater: Float

    public var humidity: Float {
        moisture
    }

    public var continentality: Float {
        continentalness
    }

    public init(
        elevation: Float,
        moisture: Float,
        temperature: Float,
        continentalness: Float,
        altitude: Float? = nil,
        slope: Float = 0,
        distanceToWater: Float = 1
    ) {
        self.elevation = Self.clampedSigned(elevation)
        self.moisture = Self.clampedSigned(moisture)
        self.temperature = Self.clampedSigned(temperature)
        self.continentalness = Self.clampedSigned(continentalness)
        self.altitude = Self.clampedSigned(altitude ?? elevation)
        self.slope = Self.clamped01(slope)
        self.distanceToWater = Self.clamped01(distanceToWater)
    }

    private static func clampedSigned(_ value: Float) -> Float {
        min(max(value, -1), 1)
    }

    private static func clamped01(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
