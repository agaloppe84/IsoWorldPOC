import SwiftUI

struct RealWorldView: View {
    @ObservedObject var store: AppStore
    @StateObject private var runtimeHandle = WorldRuntimeHandle()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameRootView(
                showsDebugOverlay: false,
                initialRunMode: .liveGameplay,
                worldSession: store.currentWorldSession,
                runtimeHandle: runtimeHandle
            )

            HStack(spacing: 8) {
                Button {
                    store.saveCurrentWorld(runtime: runtimeHandle.runtime)
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Button {
                    store.showMainMenu()
                } label: {
                    Label("Main Menu", systemImage: "house")
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
        }
    }
}
