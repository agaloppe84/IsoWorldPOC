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

                Text(progress.phaseName)
                    .foregroundStyle(.secondary)

                if let globalProgress = progress.globalProgress {
                    ProgressView(value: globalProgress)
                        .frame(width: 420)
                } else {
                    ProgressView()
                        .frame(width: 420)
                }

                Text(progress.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.showMainMenu()
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!progress.canCancel)
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
