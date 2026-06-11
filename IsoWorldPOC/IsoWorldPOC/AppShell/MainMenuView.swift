import SwiftUI

struct MainMenuView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("IsoWorld")
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Text("Engine Shell")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    ShellButton(
                        title: "Debug World",
                        systemImage: "wrench.and.screwdriver",
                        role: .primary
                    ) {
                        store.openDebugWorld()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Seed", text: $store.seedInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 280)

                        ShellButton(
                            title: "Generate World",
                            systemImage: "sparkles",
                            role: .secondary
                        ) {
                            store.prepareWorldFromSeed()
                        }
                    }
                    .padding(.top, 4)

                    ShellButton(
                        title: "Tools Hub",
                        systemImage: "square.grid.2x2",
                        role: .secondary
                    ) {
                        store.openToolsHub()
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    ShellStatusRow(label: "Renderer", value: "Idle")
                    ShellStatusRow(label: "World", value: "Unloaded")
                    ShellStatusRow(label: "Toolchain", value: "Xcode 26.5")
                }
                .padding(18)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ShellButton: View {
    enum Role {
        case primary
        case secondary
    }

    let title: String
    let systemImage: String
    let role: Role
    let action: () -> Void

    @ViewBuilder
    var body: some View {
        switch role {
        case .primary:
            button
                .buttonStyle(.borderedProminent)
        case .secondary:
            button
                .buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(width: 220, alignment: .leading)
        }
        .controlSize(.large)
    }
}

private struct ShellStatusRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 24)
            Text(value)
                .fontWeight(.medium)
        }
        .frame(width: 220)
    }
}
