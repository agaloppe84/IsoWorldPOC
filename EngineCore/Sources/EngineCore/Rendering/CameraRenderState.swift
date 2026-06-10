public struct CameraRenderState: Equatable, Codable, Sendable {
    public let position: WorldPosition
    public let target: WorldPosition
    public let up: PropVector3
    public let fieldOfViewDegrees: Float
    public let nearClipDistance: Float
    public let farClipDistance: Float
    public let yaw: Float
    public let pitch: Float
    public let distance: Float

    public init(
        position: WorldPosition,
        target: WorldPosition,
        up: PropVector3 = PropVector3(x: 0, y: 1, z: 0),
        fieldOfViewDegrees: Float,
        nearClipDistance: Float = 0.05,
        farClipDistance: Float = 1_000,
        yaw: Float,
        pitch: Float,
        distance: Float
    ) {
        self.position = position
        self.target = target
        self.up = up
        self.fieldOfViewDegrees = fieldOfViewDegrees
        self.nearClipDistance = nearClipDistance
        self.farClipDistance = farClipDistance
        self.yaw = yaw
        self.pitch = pitch
        self.distance = distance
    }
}
