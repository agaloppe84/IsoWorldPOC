public struct TerrainMesh: Equatable, Codable, Sendable {
    public let vertices: [Vertex]
    public let normals: [Normal]
    public let uvs: [UV]
    public let indices: [UInt32]

    public init(vertices: [Vertex], normals: [Normal], uvs: [UV], indices: [UInt32]) {
        precondition(vertices.count == normals.count, "TerrainMesh requires one normal per vertex.")
        precondition(vertices.count == uvs.count, "TerrainMesh requires one UV per vertex.")

        self.vertices = vertices
        self.normals = normals
        self.uvs = uvs
        self.indices = indices
    }
}

public extension TerrainMesh {
    struct Vertex: Equatable, Hashable, Codable, Sendable {
        public let x: Float
        public let y: Float
        public let z: Float

        public init(x: Float, y: Float, z: Float) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    struct Normal: Equatable, Hashable, Codable, Sendable {
        public let x: Float
        public let y: Float
        public let z: Float

        public init(x: Float, y: Float, z: Float) {
            let length = (x * x + y * y + z * z).squareRoot()

            if length == 0 {
                self.x = 0
                self.y = 1
                self.z = 0
            } else {
                self.x = x / length
                self.y = y / length
                self.z = z / length
            }
        }
    }

    struct UV: Equatable, Hashable, Codable, Sendable {
        public let u: Float
        public let v: Float

        public init(u: Float, v: Float) {
            self.u = u
            self.v = v
        }
    }
}
