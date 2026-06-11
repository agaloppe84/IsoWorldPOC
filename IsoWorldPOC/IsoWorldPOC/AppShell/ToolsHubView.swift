import SwiftUI

struct ToolsHubView: View {
    @ObservedObject var store: AppStore

    private let tools = [
        "Terrain Lab",
        "Biome Lab",
        "Material Lab",
        "LOD Debugger",
        "Seed Lab",
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Tools Hub", systemImage: "square.grid.2x2")
                    .font(.title2.weight(.semibold))

                ForEach(tools, id: \.self) { tool in
                    HStack {
                        Image(systemName: "hammer")
                            .foregroundStyle(.secondary)
                        Text(tool)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Spacer()

                Button {
                    store.showMainMenu()
                } label: {
                    Label("Main Menu", systemImage: "house")
                }
                .buttonStyle(.bordered)
            }
            .frame(width: 260)
            .padding(24)
            .background(.quaternary)

            VStack(spacing: 14) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Select a tool")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
