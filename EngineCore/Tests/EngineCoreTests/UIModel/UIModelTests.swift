import XCTest
@testable import EngineCore

final class UIModelTests: XCTestCase {
    func testUIWorldDNAIsDeterministicForSeedAndVersions() {
        let seed = WorldSeed(12_345)

        let first = UIWorldDNA.make(worldSeed: seed)
        let second = UIWorldDNA.make(worldSeed: seed)

        XCTAssertEqual(first, second)
        XCTAssertTrue(UIThemeID.allCases.contains(first.themeID))
        XCTAssertGreaterThanOrEqual(first.biomeReactivity, 0)
        XCTAssertLessThanOrEqual(first.biomeReactivity, 1)
    }

    func testThreeV1ThemesResolveWithBiomeModulation() {
        let biome = Biome.definition(for: .temperateForest)

        let themes = UIThemeID.allCases.map { id in
            UITheme.resolved(
                dna: UIWorldDNA(
                    seed: UInt64(id.rawValue.count),
                    themeID: id,
                    informationDensity: .standard,
                    diegeticLevel: .nonDiegetic,
                    materialLanguage: .neutralGlass,
                    shapeLanguage: .softRect,
                    biomeReactivity: 0.5,
                    motionIntensity: 0.2,
                    legibilityBias: 0.9
                ),
                biome: biome
            )
        }

        XCTAssertEqual(UIThemeID.allCases, [.neutral, .parchment, .sciFi])
        XCTAssertEqual(themes.map(\.id), UIThemeID.allCases)
        XCTAssertTrue(themes.allSatisfy { $0.palette.surface.alpha > 0 })
        XCTAssertTrue(themes.allSatisfy { $0.typography.labelPixelHeight > 0 })
    }

    func testUIFrameSnapshotCarriesMinimalHUDState() {
        let worldSeed = WorldSeed(77)
        let biome = Biome.definition(for: .marsh)
        let dna = UIWorldDNA(
            seed: 77,
            themeID: .sciFi,
            informationDensity: .compact,
            diegeticLevel: .semiDiegetic,
            materialLanguage: .holoGlass,
            shapeLanguage: .angularTech,
            biomeReactivity: 0.4,
            motionIntensity: 0.3,
            legibilityBias: 0.8
        )

        let snapshot = UIFrameSnapshot.make(
            worldSeed: worldSeed,
            simulationTime: 4.5,
            dna: dna,
            player: PlayerHUDState(
                health: 1.3,
                stamina: 0.42,
                fatigue: -0.2,
                wetness: 0.8,
                movementStance: .standing
            ),
            biome: biome,
            weather: WeatherHUDState(kind: .wet, severity: 0.7, label: "Wet"),
            terrainPrompt: "CLIMB"
        )

        XCTAssertEqual(snapshot.worldSeed, worldSeed)
        XCTAssertEqual(snapshot.theme.id, UIThemeID.sciFi)
        XCTAssertTrue(snapshot.hasVisibleHUD)
        XCTAssertEqual(snapshot.hud.player.health, 1)
        XCTAssertEqual(snapshot.hud.player.stamina, 0.42)
        XCTAssertEqual(snapshot.hud.player.fatigue, 0)
        XCTAssertEqual(snapshot.hud.weather.kind, UIWeatherKind.wet)
        XCTAssertEqual(snapshot.hud.biome.biomeType, biome.type)
        XCTAssertEqual(snapshot.hud.terrainPrompt, "CLIMB")
    }
}
