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
    let workspace: ToolWorkspace

    init(
        id: ToolSessionID = ToolSessionID(),
        workspace: ToolWorkspace = ToolWorkspace()
    ) {
        self.id = id
        self.workspace = workspace
    }
}
