public struct ClimateSample: Equatable, Hashable, Codable, Sendable {
    public let elevation: Float
    public let moisture: Float
    public let temperature: Float
    public let continentalness: Float

    public init(
        elevation: Float,
        moisture: Float,
        temperature: Float,
        continentalness: Float
    ) {
        self.elevation = elevation
        self.moisture = moisture
        self.temperature = temperature
        self.continentalness = continentalness
    }
}
