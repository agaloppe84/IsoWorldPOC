import Foundation

struct WorldSessionID: Hashable, Identifiable {
    let rawValue: UUID

    var id: UUID {
        rawValue
    }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct WorldSession: Equatable, Identifiable {
    let id: WorldSessionID
    let seed: String

    init(id: WorldSessionID = WorldSessionID(), seed: String) {
        self.id = id
        self.seed = seed
    }
}
