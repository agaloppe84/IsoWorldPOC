import EngineCore
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

                    if let runtimeSaveMessage = store.runtimeSaveMessage {
                        Divider()
                        Text(runtimeSaveMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                SaveSlotPanel(store: store)
            }
        }
        .task {
            await store.refreshSaveSlots()
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

private struct SaveSlotPanel: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Save", systemImage: "externaldrive")
                    .font(.headline)
                Spacer()
                Button {
                    Task {
                        await store.refreshSaveSlots()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh saves")
            }

            if let summary = store.latestSaveSlotSummary {
                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(summary.worldSeedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ShellStatusRow(label: "Saved", value: summary.lastSavedAt.formatted(date: .abbreviated, time: .shortened))
                    ShellStatusRow(label: "Region", value: "\(summary.playerRegion.x), \(summary.playerRegion.z)")
                }

                HStack(spacing: 8) {
                    Button {
                        store.openSavedWorld(slotID: summary.slotID)
                    } label: {
                        Label("Continue", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        Task {
                            await store.deleteSavedWorld(slotID: summary.slotID)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("No save")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 280, alignment: .leading)
        .padding(18)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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
