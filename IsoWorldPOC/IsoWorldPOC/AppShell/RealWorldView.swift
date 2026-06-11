import SwiftUI

struct RealWorldView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameRootView(showsDebugOverlay: false, initialRunMode: .liveGameplay)

            HStack(spacing: 12) {
                if let seed = store.currentWorldSession?.seed {
                    Text(seed)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

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
