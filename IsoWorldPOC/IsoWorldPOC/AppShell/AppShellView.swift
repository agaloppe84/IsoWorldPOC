import SwiftUI

struct AppShellView: View {
    @StateObject private var store = AppStore()

    var body: some View {
        Group {
            switch store.mode {
            case .boot, .mainMenu:
                MainMenuView(store: store)
            case .debugWorld:
                DebugWorldView(store: store)
            case .preparingWorld:
                LoadingView(store: store)
            case .realWorld:
                RealWorldView(store: store)
            case .toolsHub:
                ToolsHubView(store: store)
            case let .error(error):
                AppErrorView(error: error, store: store)
            }
        }
        .frame(minWidth: 1024, minHeight: 720)
    }
}

private struct AppErrorView: View {
    let error: AppErrorState
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.orange)

            Text(error.title)
                .font(.title2.weight(.semibold))

            Text(error.message)
                .foregroundStyle(.secondary)

            Button {
                store.showMainMenu()
            } label: {
                Label("Main Menu", systemImage: "house")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
