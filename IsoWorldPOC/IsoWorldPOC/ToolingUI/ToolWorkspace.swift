import Foundation

struct ToolRecentProject: Codable, Equatable, Identifiable {
    var id: String {
        packagePath
    }

    let toolID: String
    let displayName: String
    let packagePath: String
    let updatedAt: Date
    let isAutosaveDraft: Bool
}

struct ToolRevisionSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let toolID: String
    let documentID: UUID
    let createdAt: Date
    let dirtyToolCount: Int
}

struct ToolDiagnosticExport: Codable, Equatable, Identifiable {
    var id: String {
        "diagnostic-\(generatedAt.timeIntervalSince1970)"
    }

    let generatedAt: Date
    let selectedToolID: String
    let dirtyToolIDs: [String]
    let recentProjects: [ToolRecentProject]
    let revisionSnapshots: [ToolRevisionSnapshot]
    let validationReports: [ToolValidationReport]
}

enum ToolWorkspaceCommand: String, CaseIterable, Identifiable {
    case resetDocument
    case markSaved
    case autosaveDraft
    case snapshotRevision
    case exportDiagnostics
    case nextTool
    case previousTool

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .resetDocument:
            "Reset"
        case .markSaved:
            "Save"
        case .autosaveDraft:
            "Autosave"
        case .snapshotRevision:
            "Revision"
        case .exportDiagnostics:
            "Diagnostics"
        case .nextTool:
            "Next"
        case .previousTool:
            "Previous"
        }
    }

    var systemImage: String {
        switch self {
        case .resetDocument:
            "arrow.counterclockwise"
        case .markSaved:
            "square.and.arrow.down"
        case .autosaveDraft:
            "clock.badge.checkmark"
        case .snapshotRevision:
            "camera.metering.matrix"
        case .exportDiagnostics:
            "waveform.path.ecg.rectangle"
        case .nextTool:
            "chevron.right"
        case .previousTool:
            "chevron.left"
        }
    }
}

struct ToolWorkspaceCommandResult: Equatable {
    let command: ToolWorkspaceCommand
    let message: String
}

struct ToolWorkspace: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var selectedCategory: ToolCategory?
    var selectedToolID: String
    private(set) var documents: [String: ToolDocument]
    private(set) var savedDocuments: [String: ToolDocument]
    private(set) var recentProjects: [ToolRecentProject]
    private(set) var revisionSnapshots: [ToolRevisionSnapshot]
    private(set) var pendingDiagnostic: ToolDiagnosticExport?

    init(
        id: UUID = UUID(),
        registry: ToolRegistry = .v2,
        seedText: String = ToolRegistry.defaultSeedText,
        now: Date = Date()
    ) {
        let descriptors = registry.descriptors
        let documents = Dictionary(uniqueKeysWithValues: descriptors.map { descriptor in
            (
                descriptor.id,
                registry.makeDefaultDocument(
                    for: descriptor,
                    seedText: seedText
                )
            )
        })
        let defaultDescriptor = registry.defaultDescriptor

        self.id = id
        self.createdAt = now
        self.updatedAt = now
        self.selectedCategory = nil
        self.selectedToolID = defaultDescriptor.id
        self.documents = documents
        self.savedDocuments = documents
        self.recentProjects = [
            ToolRecentProject(
                toolID: defaultDescriptor.id,
                displayName: defaultDescriptor.name,
                packagePath: "projects/\(defaultDescriptor.id)/initial.isoproj",
                updatedAt: now,
                isAutosaveDraft: false
            )
        ]
        self.revisionSnapshots = []
        self.pendingDiagnostic = nil
    }

    var selectedDocument: ToolDocument {
        documents[selectedToolID] ?? documents.values.sorted { $0.toolID < $1.toolID }[0]
    }

    var dirtyToolIDs: [String] {
        documents.keys
            .filter { documents[$0] != savedDocuments[$0] }
            .sorted()
    }

    var isDirty: Bool {
        !dirtyToolIDs.isEmpty
    }

    func selectedDescriptor(in registry: ToolRegistry) -> ToolDescriptor {
        registry.descriptor(for: selectedToolID) ?? registry.defaultDescriptor
    }

    func visibleTools(in registry: ToolRegistry) -> [ToolDescriptor] {
        registry.tools(in: selectedCategory)
    }

    func isDirty(toolID: String) -> Bool {
        documents[toolID] != savedDocuments[toolID]
    }

    func validationReports(in registry: ToolRegistry) -> [ToolValidationReport] {
        documents.keys.sorted().compactMap { toolID in
            documents[toolID].map(registry.validate(document:))
        }
    }

    func diagnosticExport(in registry: ToolRegistry, now: Date = Date()) -> ToolDiagnosticExport {
        ToolDiagnosticExport(
            generatedAt: now,
            selectedToolID: selectedToolID,
            dirtyToolIDs: dirtyToolIDs,
            recentProjects: recentProjects,
            revisionSnapshots: revisionSnapshots,
            validationReports: validationReports(in: registry)
        )
    }

    mutating func selectCategory(_ category: ToolCategory?, registry: ToolRegistry) {
        selectedCategory = category
        if let nextTool = registry.tools(in: category).first {
            selectTool(nextTool.id, registry: registry)
        }
    }

    mutating func selectTool(_ toolID: String, registry: ToolRegistry) {
        guard registry.descriptor(for: toolID) != nil else {
            return
        }

        selectedToolID = toolID
        ensureDocument(for: toolID, registry: registry)
    }

    mutating func updateSelectedDocument(_ document: ToolDocument, now: Date = Date()) {
        var updatedDocument = document
        updatedDocument.toolID = selectedToolID
        documents[selectedToolID] = updatedDocument
        updatedAt = now
    }

    mutating func resetSelectedDocument(registry: ToolRegistry, seedText: String, now: Date = Date()) {
        let descriptor = selectedDescriptor(in: registry)
        documents[selectedToolID] = registry.makeDefaultDocument(
            for: descriptor,
            seedText: seedText
        )
        updatedAt = now
    }

    mutating func markSelectedSaved(registry: ToolRegistry, now: Date = Date()) {
        let descriptor = selectedDescriptor(in: registry)
        let document = selectedDocument
        savedDocuments[selectedToolID] = document
        pushRecentProject(
            ToolRecentProject(
                toolID: descriptor.id,
                displayName: descriptor.name,
                packagePath: "projects/\(descriptor.id)/\(document.id).isoproj",
                updatedAt: now,
                isAutosaveDraft: false
            )
        )
        updatedAt = now
    }

    mutating func makeAutosaveDraft(registry: ToolRegistry, now: Date = Date()) {
        let descriptor = selectedDescriptor(in: registry)
        pushRecentProject(
            ToolRecentProject(
                toolID: descriptor.id,
                displayName: "\(descriptor.name) Draft",
                packagePath: "drafts/\(descriptor.id)/\(selectedDocument.id).isoproj",
                updatedAt: now,
                isAutosaveDraft: true
            )
        )
        updatedAt = now
    }

    mutating func snapshotRevision(now: Date = Date()) -> ToolRevisionSnapshot {
        var document = selectedDocument
        let revisionID = "\(selectedToolID)-r\(revisionSnapshots.count + 1)"
        document.revisionID = revisionID
        documents[selectedToolID] = document

        let snapshot = ToolRevisionSnapshot(
            id: revisionID,
            toolID: selectedToolID,
            documentID: document.id,
            createdAt: now,
            dirtyToolCount: dirtyToolIDs.count
        )
        revisionSnapshots.insert(snapshot, at: 0)
        updatedAt = now
        return snapshot
    }

    mutating func perform(
        _ command: ToolWorkspaceCommand,
        registry: ToolRegistry,
        seedText: String,
        now: Date = Date()
    ) -> ToolWorkspaceCommandResult {
        switch command {
        case .resetDocument:
            resetSelectedDocument(registry: registry, seedText: seedText, now: now)
            return ToolWorkspaceCommandResult(command: command, message: "Document reset.")
        case .markSaved:
            markSelectedSaved(registry: registry, now: now)
            return ToolWorkspaceCommandResult(command: command, message: "Document marked saved.")
        case .autosaveDraft:
            makeAutosaveDraft(registry: registry, now: now)
            return ToolWorkspaceCommandResult(command: command, message: "Draft autosaved.")
        case .snapshotRevision:
            let snapshot = snapshotRevision(now: now)
            return ToolWorkspaceCommandResult(command: command, message: "Revision \(snapshot.id) captured.")
        case .exportDiagnostics:
            pendingDiagnostic = diagnosticExport(in: registry, now: now)
            return ToolWorkspaceCommandResult(command: command, message: "Diagnostic export staged.")
        case .nextTool:
            selectAdjacentTool(offset: 1, registry: registry)
            return ToolWorkspaceCommandResult(command: command, message: "Next tool selected.")
        case .previousTool:
            selectAdjacentTool(offset: -1, registry: registry)
            return ToolWorkspaceCommandResult(command: command, message: "Previous tool selected.")
        }
    }

    private mutating func ensureDocument(for toolID: String, registry: ToolRegistry) {
        guard documents[toolID] == nil, let descriptor = registry.descriptor(for: toolID) else {
            return
        }

        let seed = selectedDocument.seedText
        let document = registry.makeDefaultDocument(for: descriptor, seedText: seed)
        documents[toolID] = document
        savedDocuments[toolID] = document
    }

    private mutating func selectAdjacentTool(offset: Int, registry: ToolRegistry) {
        let tools = visibleTools(in: registry)
        guard
            let currentIndex = tools.firstIndex(where: { $0.id == selectedToolID }),
            !tools.isEmpty
        else {
            return
        }

        let nextIndex = (currentIndex + offset + tools.count) % tools.count
        selectTool(tools[nextIndex].id, registry: registry)
    }

    private mutating func pushRecentProject(_ project: ToolRecentProject) {
        recentProjects.removeAll { $0.packagePath == project.packagePath }
        recentProjects.insert(project, at: 0)
        recentProjects = Array(recentProjects.prefix(6))
    }
}
