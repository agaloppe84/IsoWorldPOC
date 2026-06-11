import Foundation

struct ToolSessionID: Hashable, Identifiable {
    let rawValue: UUID

    var id: UUID {
        rawValue
    }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct ToolSession: Equatable, Identifiable {
    let id: ToolSessionID

    init(id: ToolSessionID = ToolSessionID()) {
        self.id = id
    }
}
