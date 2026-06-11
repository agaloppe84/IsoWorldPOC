import SwiftUI

struct LoadingView: View {
    @ObservedObject var store: AppStore

    private var progress: LoadingProgress {
        store.loadingProgress ?? .initial(seed: store.seedInput)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("Preparing World", systemImage: "clock.arrow.circlepath")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Text(progress.seed)
                    .font(.headline)

                Text(progress.phase)
                    .foregroundStyle(.secondary)

                ProgressView(value: progress.progress)
                    .frame(width: 420)
            }

            Button {
                store.showMainMenu()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
