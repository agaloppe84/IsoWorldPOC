import SwiftUI

struct RealWorldView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameRootView(
                showsDebugOverlay: false,
                initialRunMode: .liveGameplay,
                worldSession: store.currentWorldSession
            )

            Button {
                store.showMainMenu()
            } label: {
                Label("Main Menu", systemImage: "house")
            }
            .buttonStyle(.bordered)
            .padding(12)
        }
    }
}
