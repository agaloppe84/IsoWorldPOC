public extension GeneratorVersionTable {
    static var persistenceCurrent: GeneratorVersionTable {
        .current
    }

    var persistenceHash: StableHash {
        StableHash.make { builder in
            for entry in entries {
                builder.combine(entry.domain)
                builder.combine(entry.version)
            }
        }
    }
}
