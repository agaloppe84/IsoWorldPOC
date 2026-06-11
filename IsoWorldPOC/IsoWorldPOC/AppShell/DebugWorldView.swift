import SwiftUI

struct DebugWorldView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameRootView(showsDebugOverlay: true, initialRunMode: .slowInspection)

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
