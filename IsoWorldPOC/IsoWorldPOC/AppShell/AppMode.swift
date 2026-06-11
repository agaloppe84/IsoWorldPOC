import Foundation

enum AppMode: Equatable {
    case boot
    case mainMenu
    case debugWorld(DebugWorldSessionID)
    case preparingWorld(LoadingSessionID)
    case realWorld(WorldSessionID)
    case toolsHub(ToolSessionID)
    case error(AppErrorState)
}

struct LoadingSessionID: Hashable, Identifiable {
    let rawValue: UUID

    var id: UUID {
        rawValue
    }

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct AppErrorState: Equatable {
    let title: String
    let message: String
}
