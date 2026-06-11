struct EngineCoreFacade {
    func makeDebugWorldSession() -> DebugWorldSession {
        DebugWorldSession()
    }

    func makeToolSession() -> ToolSession {
        ToolSession()
    }
}
