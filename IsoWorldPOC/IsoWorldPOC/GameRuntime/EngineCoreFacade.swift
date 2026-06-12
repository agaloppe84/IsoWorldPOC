struct EngineCoreFacade {
    func makeDebugWorldSession() -> DebugWorldSession {
        DebugWorldSession()
    }

    func makeToolSession(seedText: String) -> ToolSession {
        ToolSession(workspace: ToolWorkspace(seedText: seedText))
    }
}
