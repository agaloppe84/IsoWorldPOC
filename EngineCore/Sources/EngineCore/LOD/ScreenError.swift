import Foundation

public struct ScreenError: Equatable, Comparable, Codable, Sendable {
    public let projectedPixels: Float

    public init(projectedPixels: Float) {
        self.projectedPixels = max(projectedPixels, 0)
    }

    public static func < (lhs: ScreenError, rhs: ScreenError) -> Bool {
        lhs.projectedPixels < rhs.projectedPixels
    }

    public static func estimateProjectedPixels(
        worldExtent: Float,
        distance: Float,
        fieldOfViewDegrees: Float,
        viewportHeightPixels: Float
    ) -> ScreenError {
        let safeDistance = max(distance, 0.001)
        let safeFieldOfView = max(fieldOfViewDegrees, 1)
        let halfFieldOfViewRadians = safeFieldOfView * .pi / 360
        let projected = (worldExtent / safeDistance) *
            (max(viewportHeightPixels, 1) / (2 * tan(halfFieldOfViewRadians)))

        return ScreenError(projectedPixels: projected)
    }
}
