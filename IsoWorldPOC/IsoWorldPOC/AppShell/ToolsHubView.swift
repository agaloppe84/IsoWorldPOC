import SwiftUI

struct ToolsHubView: View {
    @ObservedObject var store: AppStore
    private let registry: ToolRegistry

    @State private var selectedCategory: ToolCategory?
    @State private var selectedToolID: String
    @State private var document: ToolDocument

    init(store: AppStore, registry: ToolRegistry = .v1) {
        self.store = store
        self.registry = registry
        let descriptor = registry.defaultDescriptor
        _selectedToolID = State(initialValue: descriptor.id)
        _document = State(initialValue: registry.makeDefaultDocument(
            for: descriptor,
            seedText: store.seedInput
        ))
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            workspace
            inspector
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Tools Hub", systemImage: "square.grid.2x2")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                categoryButton(title: "All", systemImage: "tray.full", category: nil)

                ForEach(registry.categories) { category in
                    categoryButton(
                        title: category.displayName,
                        systemImage: category.systemImage,
                        category: category
                    )
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(visibleTools) { descriptor in
                    toolButton(descriptor)
                }
            }

            Spacer()

            Button {
                store.showMainMenu()
            } label: {
                Label("Main Menu", systemImage: "house")
            }
            .buttonStyle(.bordered)
        }
        .frame(width: 280)
        .padding(22)
        .background(.quaternary)
    }

    private var workspace: some View {
        let descriptor = selectedDescriptor
        let preview = registry.makePreviewSnapshot(for: descriptor, document: document)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(descriptor.category.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(descriptor.name)
                        .font(.title2.weight(.semibold))
                }

                Spacer()

                Button {
                    document = registry.makeDefaultDocument(
                        for: descriptor,
                        seedText: document.seedText
                    )
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }

            ToolPreviewView(
                descriptor: descriptor,
                document: document,
                preview: preview
            )

            documentEditor

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Inspector")
                .font(.title3.weight(.semibold))

            capabilityList

            Divider()

            ToolValidationPanel(report: registry.validate(document: document))

            Spacer()
        }
        .frame(width: 320)
        .padding(22)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var documentEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Document")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Text("Seed")
                        .foregroundStyle(.secondary)
                    TextField("Seed", text: $document.seedText)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Preset")
                        .foregroundStyle(.secondary)
                    TextField("Preset", text: $document.presetName)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Samples")
                        .foregroundStyle(.secondary)
                    Stepper(value: $document.sampleCount, in: 1...256) {
                        Text("\(document.sampleCount)")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }

            TextEditor(text: $document.notes)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 86)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.18))
                }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var capabilityList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capabilities")
                .font(.headline)

            ForEach(selectedDescriptor.capabilities, id: \.self) { capability in
                Label(capability.displayName, systemImage: capabilitySystemImage(capability))
                    .font(.callout)
            }
        }
    }

    private var selectedDescriptor: ToolDescriptor {
        registry.descriptor(for: selectedToolID) ?? registry.defaultDescriptor
    }

    private var visibleTools: [ToolDescriptor] {
        registry.tools(in: selectedCategory)
    }

    private func categoryButton(
        title: String,
        systemImage: String,
        category: ToolCategory?
    ) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            selectedCategory = category
            if let nextTool = registry.tools(in: category).first {
                select(nextTool)
            }
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func toolButton(_ descriptor: ToolDescriptor) -> some View {
        let isSelected = selectedToolID == descriptor.id

        return Button {
            select(descriptor)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: descriptor.systemImage)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(descriptor.name)
                        .font(.callout.weight(.medium))
                    Text(descriptor.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func select(_ descriptor: ToolDescriptor) {
        let seed = document.seedText.isEmpty ? store.seedInput : document.seedText
        selectedToolID = descriptor.id
        document = registry.makeDefaultDocument(for: descriptor, seedText: seed)
    }

    private func capabilitySystemImage(_ capability: ToolCapability) -> String {
        switch capability {
        case .preview:
            "eye"
        case .validation:
            "checkmark.seal"
        case .presets:
            "slider.horizontal.3"
        case .export:
            "square.and.arrow.up"
        }
    }
}
