import Foundation

struct DebugWorldSessionID: Hashable, Identifiable {
    let rawValue: UUID

    var id: UUID {
        rawValue
    }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct DebugWorldSession: Equatable, Identifiable {
    let id: DebugWorldSessionID

    init(id: DebugWorldSessionID = DebugWorldSessionID()) {
        self.id = id
    }
}
