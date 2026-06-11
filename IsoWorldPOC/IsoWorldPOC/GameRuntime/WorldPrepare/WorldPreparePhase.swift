import Foundation

enum WorldPreparePhaseID: String, CaseIterable, Codable, Sendable {
    case validateSeed
    case worldDNA
    case initializeRules
    case terrainFields
    case biomeFields
    case playerSpawn
    case initialChunks
    case renderPayloads
    case collisionBootstrap
    case rendererWarmup
    case openSession
}

struct WorldPreparePhase: Equatable, Sendable {
    let id: WorldPreparePhaseID
    let name: String
    let weight: Double
}

struct WorldPreparePhasePlan: Equatable, Sendable {
    static let v1 = WorldPreparePhasePlan(phases: [
        WorldPreparePhase(id: .validateSeed, name: "Validate seed", weight: 0.02),
        WorldPreparePhase(id: .worldDNA, name: "World DNA", weight: 0.05),
        WorldPreparePhase(id: .initializeRules, name: "World rules", weight: 0.08),
        WorldPreparePhase(id: .terrainFields, name: "Terrain fields", weight: 0.12),
        WorldPreparePhase(id: .biomeFields, name: "Biome fields", weight: 0.10),
        WorldPreparePhase(id: .playerSpawn, name: "Player spawn", weight: 0.10),
        WorldPreparePhase(id: .initialChunks, name: "Initial chunks", weight: 0.25),
        WorldPreparePhase(id: .renderPayloads, name: "Render payloads", weight: 0.10),
        WorldPreparePhase(id: .collisionBootstrap, name: "Collision bootstrap", weight: 0.08),
        WorldPreparePhase(id: .rendererWarmup, name: "Renderer warmup", weight: 0.05),
        WorldPreparePhase(id: .openSession, name: "Open session", weight: 0.05),
    ])

    let phases: [WorldPreparePhase]

    var firstPhase: WorldPreparePhase {
        phases[0]
    }

    func phase(for id: WorldPreparePhaseID) -> WorldPreparePhase {
        phases.first { $0.id == id } ?? firstPhase
    }

    func globalProgress(
        for phaseID: WorldPreparePhaseID,
        phaseProgress: Double?
    ) -> Double? {
        guard let phaseProgress else {
            return nil
        }

        var completedWeight = 0.0

        for phase in phases {
            if phase.id == phaseID {
                return clamped((completedWeight + phase.weight * clamped(phaseProgress)) / totalWeight)
            }

            completedWeight += phase.weight
        }

        return clamped(completedWeight / totalWeight)
    }

    private var totalWeight: Double {
        phases.reduce(0) { $0 + $1.weight }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
