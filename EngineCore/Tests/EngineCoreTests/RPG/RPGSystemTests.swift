import XCTest
@testable import EngineCore

final class RPGSystemTests: XCTestCase {
    func testWorldRPGDNAIsDeterministicCodableAndPrintable() throws {
        let seed = WorldSeed(21_001)

        let first = WorldRPGDNA.make(worldSeed: seed)
        let second = WorldRPGDNA.make(worldSeed: seed)
        let data = try JSONEncoder().encode(first)
        let decoded = try JSONDecoder().decode(WorldRPGDNA.self, from: data)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first, decoded)
        XCTAssertTrue(first.debugSummary.contains(first.archetype.displayName))
        XCTAssertTrue(first.debugSummary.contains(first.mainObjective.title))
        XCTAssertFalse(first.worldTags.isEmpty)
    }

    func testWorldRPGDNAChangesOnlyWhenRPGVersionChanges() {
        let seed = WorldSeed(21_002)
        let current = GeneratorVersionTable.current
        let terrainV2 = current.setting(GeneratorVersion(major: 2), for: .terrain)
        let rpgV2 = current.setting(GeneratorVersion(major: 2), for: .rpgDNA)

        let base = WorldDNA.make(worldSeed: seed, generatorVersions: current)
        let terrainChanged = WorldDNA.make(worldSeed: seed, generatorVersions: terrainV2)
        let rpgChanged = WorldDNA.make(worldSeed: seed, generatorVersions: rpgV2)

        XCTAssertEqual(base.rpg, terrainChanged.rpg)
        XCTAssertNotEqual(base.rpg, rpgChanged.rpg)
    }

    func testWorldRulesetBuildsExecutableContractsFromDNA() throws {
        let worldSeed = WorldSeed(21_003)
        let dna = WorldRPGDNA.make(worldSeed: worldSeed)
        let ruleset = WorldRuleset.make(worldSeed: worldSeed, dna: dna)

        XCTAssertEqual(ruleset.worldSeed, worldSeed)
        XCTAssertEqual(ruleset.dna, dna)
        XCTAssertEqual(ruleset.primaryObjective.kind, dna.mainObjective)
        XCTAssertFalse(ruleset.enabledSystems.isEmpty)
        XCTAssertFalse(ruleset.factions.isEmpty)
        XCTAssertFalse(ruleset.questSeeds.isEmpty)
        XCTAssertTrue(ruleset.validationReport.isPlayable, ruleset.validationReport.issues.joined(separator: ", "))
        XCTAssertTrue(ruleset.debugSummary.contains("ruleset systems"))

        let decoded = try JSONDecoder().decode(
            WorldRuleset.self,
            from: JSONEncoder().encode(ruleset)
        )
        XCTAssertEqual(decoded, ruleset)
    }

    func testRulesetSubdomainVersionsChangeStableGeneratedIDs() {
        let worldSeed = WorldSeed(21_005)
        let dna = WorldRPGDNA.make(worldSeed: worldSeed)
        let current = GeneratorVersionTable.current
        let factionV2 = current.setting(GeneratorVersion(major: 2), for: .rpgFactions)
        let questV2 = current.setting(GeneratorVersion(major: 2), for: .rpgQuests)
        let currentRules = WorldRuleset.make(
            worldSeed: worldSeed,
            dna: dna,
            generatorVersions: current
        )
        let factionRules = WorldRuleset.make(
            worldSeed: worldSeed,
            dna: dna,
            generatorVersions: factionV2
        )
        let questRules = WorldRuleset.make(
            worldSeed: worldSeed,
            dna: dna,
            generatorVersions: questV2
        )

        XCTAssertNotEqual(currentRules.factions.map(\.id), factionRules.factions.map(\.id))
        XCTAssertEqual(currentRules.questSeeds.map(\.id), factionRules.questSeeds.map(\.id))
        XCTAssertEqual(currentRules.factions.map(\.id), questRules.factions.map(\.id))
        XCTAssertNotEqual(currentRules.questSeeds.map(\.id), questRules.questSeeds.map(\.id))
    }

    func testWorldRulesetKeepsEnemyFreeWorldsOutOfCombatSystems() {
        let dna = WorldRPGDNA(
            seed: 1,
            historySeed: 2,
            factionSeed: 3,
            questSeed: 4,
            directorSeed: 5,
            archetype: .contemplativeExploration,
            era: .prehistory,
            techLevel: .naturalTools,
            magic: .none,
            threat: .none,
            enemyPresence: .none,
            mainObjective: .mapWorld,
            progression: .cartography,
            tone: .pastoral,
            factionDensity: 0.1,
            questDensity: 0.5,
            violenceLevel: 0,
            wonderLevel: 0.2,
            ecologyPressure: 0.2,
            economyImportance: 0.1,
            worldTags: [.exploration, .nonViolent, .lowThreat]
        )

        let ruleset = WorldRuleset.make(worldSeed: WorldSeed(99), dna: dna)

        XCTAssertEqual(ruleset.violencePolicy, .forbidden)
        XCTAssertFalse(ruleset.enabledSystems.contains(.combat))
        XCTAssertTrue(ruleset.validationReport.isPlayable)
    }

    func testTwentyReferenceSeedsProducePlayableRPGRulesets() {
        for seed in Self.referenceSeeds {
            let dna = WorldRPGDNA.make(worldSeed: seed)
            let ruleset = WorldRuleset.make(worldSeed: seed, dna: dna)
            let factionIDs = Set(ruleset.factions.map(\.id))
            let questIDs = Set(ruleset.questSeeds.map(\.id))

            XCTAssertTrue(ruleset.validationReport.isPlayable, "Seed \(seed.value): \(ruleset.validationReport.issues)")
            XCTAssertEqual(factionIDs.count, ruleset.factions.count)
            XCTAssertEqual(questIDs.count, ruleset.questSeeds.count)
            XCTAssertGreaterThanOrEqual(ruleset.questSeeds.count, 3)
            XCTAssertTrue(ruleset.questSeeds.contains { $0.kind == .main })
            XCTAssertFalse(ruleset.debugSummary.isEmpty)
        }
    }

    func testWorldStateLedgerRecordsAndCompactsFactsDeterministically() throws {
        let seed = WorldSeed(21_004)
        let ledger = WorldStateLedger(worldSeed: seed)
            .recording(
                kind: .questActivated,
                tag: .exploration,
                timeIndex: 2,
                note: "first map clue"
            )
            .recording(
                kind: .objectiveProgress,
                tag: .exploration,
                value: 3,
                timeIndex: 3,
                note: "mapped valley"
            )
            .recording(
                kind: .objectiveProgress,
                tag: .exploration,
                value: 5,
                timeIndex: 4,
                note: "mapped ridge"
            )

        let decoded = try JSONDecoder().decode(
            WorldStateLedger.self,
            from: JSONEncoder().encode(ledger)
        )

        XCTAssertEqual(decoded, ledger)
        XCTAssertTrue(ledger.contains(tag: .exploration))
        XCTAssertEqual(ledger.totalValue(for: .exploration), 9)
        XCTAssertEqual(ledger.compacted.facts.count, 2)
        XCTAssertEqual(ledger.compacted.totalValue(for: .exploration), 6)
    }

    private static let referenceSeeds: [WorldSeed] = [
        101, 202, 303, 404, 505,
        606, 707, 808, 909, 1_010,
        1_111, 1_212, 1_313, 1_414, 1_515,
        1_616, 1_717, 1_818, 1_919, 2_020,
    ]
}
