import SwiftUI

struct ToolsHubView: View {
    @ObservedObject var store: AppStore
    private let registry: ToolRegistry
    private let documentStore = ToolDocumentStore()

    @State private var toolWorkspace: ToolWorkspace
    @State private var lastCommandMessage: String?

    init(store: AppStore, registry: ToolRegistry = .v2) {
        self.store = store
        self.registry = registry
        _toolWorkspace = State(initialValue: store.currentToolSession?.workspace ?? ToolWorkspace(
            registry: registry,
            seedText: store.seedInput
        ))
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            workspaceContent
            inspector
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label("Tools Hub V2", systemImage: "square.grid.2x2")
                    .font(.title2.weight(.semibold))

                Spacer()

                if toolWorkspace.isDirty {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    categoryList

                    Divider()

                    toolList

                    Divider()

                    recentProjectsList
                }
            }

            Button {
                store.showMainMenu()
            } label: {
                Label("Main Menu", systemImage: "house")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .frame(width: 292)
        .padding(22)
        .background(.quaternary)
    }

    private var workspaceContent: some View {
        let descriptor = toolWorkspace.selectedDescriptor(in: registry)
        let document = toolWorkspace.selectedDocument
        let preview = registry.makePreviewSnapshot(for: descriptor, document: document)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(descriptor.category.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(descriptor.name)
                            .font(.title2.weight(.semibold))
                        if toolWorkspace.isDirty(toolID: descriptor.id) {
                            Text("Unsaved")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                commandBar
            }

            if let lastCommandMessage {
                Label(lastCommandMessage, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Inspector")
                    .font(.title3.weight(.semibold))

                workspaceStatus

                Divider()

                capabilityList

                Divider()

                persistenceSummary

                Divider()

                ToolValidationPanel(report: registry.validate(document: toolWorkspace.selectedDocument))

                if let diagnostic = toolWorkspace.pendingDiagnostic {
                    Divider()
                    diagnosticSummary(diagnostic)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(22)
        }
        .frame(width: 336)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var categoryList: some View {
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
    }

    private var toolList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(visibleTools) { descriptor in
                toolButton(descriptor)
            }
        }
    }

    private var recentProjectsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.headline)

            ForEach(toolWorkspace.recentProjects) { project in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(project.displayName)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        if project.isAutosaveDraft {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(project.packagePath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var commandBar: some View {
        HStack(spacing: 8) {
            ForEach(ToolWorkspaceCommand.allCases) { command in
                Button {
                    run(command)
                } label: {
                    Label(command.displayName, systemImage: command.systemImage)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .keyboardShortcut(keyEquivalent(for: command), modifiers: modifiers(for: command))
                .help(command.displayName)
            }
        }
    }

    private var documentEditor: some View {
        let document = documentBinding

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Document")
                    .font(.headline)
                Spacer()
                Text(toolWorkspace.selectedDocument.revisionID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                GridRow {
                    Text("Seed")
                        .foregroundStyle(.secondary)
                    TextField("Seed", text: document.seedText)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Preset")
                        .foregroundStyle(.secondary)
                    TextField("Preset", text: document.presetName)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("Samples")
                        .foregroundStyle(.secondary)
                    Stepper(value: document.sampleCount, in: 1...256) {
                        Text("\(toolWorkspace.selectedDocument.sampleCount)")
                            .font(.system(.body, design: .monospaced))
                    }
                }

                GridRow {
                    Text("Packages")
                        .foregroundStyle(.secondary)
                    TextField("Package refs", text: packageReferencesBinding)
                        .textFieldStyle(.roundedBorder)
                }
            }

            TextEditor(text: document.notes)
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

    private var workspaceStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workspace")
                .font(.headline)

            metric("Dirty tools", "\(toolWorkspace.dirtyToolIDs.count)")
            metric("Open docs", "\(toolWorkspace.documents.count)")
            metric("Revisions", "\(toolWorkspace.revisionSnapshots.count)")
        }
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

    private var persistenceSummary: some View {
        let descriptor = selectedDescriptor
        let document = toolWorkspace.selectedDocument
        let project = documentStore.makeProjectPackage(
            for: document,
            descriptor: descriptor,
            registry: registry
        )
        let asset = documentStore.makeAssetPackage(
            for: document,
            descriptor: descriptor,
            registry: registry,
            graphPackage: project.graphPackage
        )

        return VStack(alignment: .leading, spacing: 8) {
            Text("Persistence")
                .font(.headline)

            metric("Project", project.relativePath)
            metric("Asset", asset.relativePath)
            if let graphPackage = project.graphPackage {
                metric("Graph", graphPackage.relativePath)
            }
            metric("Valid", project.validationReport.isValid && asset.validationReport.isValid ? "yes" : "no")
        }
    }

    private func diagnosticSummary(_ diagnostic: ToolDiagnosticExport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostic")
                .font(.headline)

            metric("Selected", diagnostic.selectedToolID)
            metric("Dirty", diagnostic.dirtyToolIDs.joined(separator: ", "))
            metric("Reports", "\(diagnostic.validationReports.count)")
        }
    }

    private var documentBinding: Binding<ToolDocument> {
        Binding(
            get: {
                toolWorkspace.selectedDocument
            },
            set: { newValue in
                toolWorkspace.updateSelectedDocument(newValue)
            }
        )
    }

    private var packageReferencesBinding: Binding<String> {
        Binding(
            get: {
                toolWorkspace.selectedDocument.packageReferences.joined(separator: ", ")
            },
            set: { newValue in
                var document = toolWorkspace.selectedDocument
                document.packageReferences = newValue
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                toolWorkspace.updateSelectedDocument(document)
            }
        )
    }

    private var selectedDescriptor: ToolDescriptor {
        toolWorkspace.selectedDescriptor(in: registry)
    }

    private var visibleTools: [ToolDescriptor] {
        toolWorkspace.visibleTools(in: registry)
    }

    private func categoryButton(
        title: String,
        systemImage: String,
        category: ToolCategory?
    ) -> some View {
        let isSelected = toolWorkspace.selectedCategory == category

        return Button {
            toolWorkspace.selectCategory(category, registry: registry)
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
        let isSelected = toolWorkspace.selectedToolID == descriptor.id

        return Button {
            toolWorkspace.selectTool(descriptor.id, registry: registry)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: descriptor.systemImage)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(descriptor.name)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        if toolWorkspace.isDirty(toolID: descriptor.id) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.orange)
                        }
                    }
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

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "none" : value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func run(_ command: ToolWorkspaceCommand) {
        let result = toolWorkspace.perform(
            command,
            registry: registry,
            seedText: store.seedInput
        )
        lastCommandMessage = result.message
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
        case .persistence:
            "externaldrive"
        case .diagnostics:
            "waveform.path.ecg.rectangle"
        }
    }

    private func keyEquivalent(for command: ToolWorkspaceCommand) -> KeyEquivalent {
        switch command {
        case .markSaved:
            "s"
        case .resetDocument:
            "r"
        case .snapshotRevision:
            "n"
        case .exportDiagnostics:
            "d"
        case .autosaveDraft:
            "a"
        case .nextTool:
            .rightArrow
        case .previousTool:
            .leftArrow
        }
    }

    private func modifiers(for command: ToolWorkspaceCommand) -> EventModifiers {
        switch command {
        case .nextTool, .previousTool:
            [.command, .shift]
        default:
            .command
        }
    }
}
