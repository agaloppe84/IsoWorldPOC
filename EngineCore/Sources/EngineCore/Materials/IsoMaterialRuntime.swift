public struct IsoMaterialRuntime: Equatable, Hashable, Codable, Sendable {
    public let descriptor: SurfaceDescriptor
    public let surfaceState: SurfaceState

    public var materialID: MaterialID {
        descriptor.materialID
    }

    public var shadingModel: SurfaceShadingModel {
        descriptor.shadingModel
    }

    public var resolvedParameters: MaterialParameterBlock {
        surfaceState.applying(to: descriptor.parameters)
    }

    public init(
        descriptor: SurfaceDescriptor,
        surfaceState: SurfaceState = .dry
    ) {
        self.descriptor = descriptor
        self.surfaceState = surfaceState
    }

    public static func terrain(
        _ material: TerrainMaterialDescriptor,
        surfaceState: SurfaceState = .dry
    ) -> IsoMaterialRuntime {
        IsoMaterialRuntime(
            descriptor: .terrain(material),
            surfaceState: surfaceState
        )
    }
}
