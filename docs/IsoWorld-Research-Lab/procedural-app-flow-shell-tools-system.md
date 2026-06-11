# IsoWorld — App Flow, Shell, Debug World et Hub d’outils procéduraux

**Nouveau step — Document dédié uniquement au flux d’application**  
**Projet :** IsoWorld / moteur procédural custom Swift + Metal sur macOS  
**Objectif :** définir un système moderne, robuste et versatile pour ouvrir l’application, choisir un mode, charger un monde réel depuis un seed, accéder à un monde debug restreint, et ouvrir tous les outils procéduraux/paramétriques du moteur.

---

## 0. Résumé exécutif

IsoWorld ne doit pas démarrer directement dans le monde. L’application doit être structurée comme un **shell moteur** capable de lancer plusieurs expériences :

1. **Main Menu** : écran d’accueil stable, léger, sans monde chargé.
2. **Debug World** : monde de test restreint, rapide à ouvrir, avec viewport à gauche et outils moteur à droite.
3. **Real World Generation** : génération d’un monde réel via seed, avec pré-calculs déterministes, barre de chargement et ouverture seulement quand les données minimales sont prêtes.
4. **Procedural Tools Hub** : environnement d’authoring pour assets, terrain, biomes, characters, nodes, audio, FX, UI, bâtiments, RPG rules, etc.

Le système recommandé est une architecture **hybride SwiftUI + Metal + EngineCore** :

- **SwiftUI/AppKit** pour le shell macOS, menus, navigation, formulaires, panneaux, inspectors, sauvegardes, préférences et outils non temps réel.
- **Metal / MTKView** pour le viewport monde, les previews haute qualité, les rendus d’assets et les overlays in-game.
- **EngineCore pur Swift** pour l’état moteur, les règles déterministes, le chargement, les jobs, les snapshots de simulation et les services.
- **State machine explicite** pour éviter les transitions implicites fragiles.
- **Loading orchestration** séparée du rendu, découpée en phases progressives et annulables.
- **Tool registry** pour que chaque système procédural expose ses outils, previews, validateurs et presets sans coupler le shell à chaque module.

Ce document recommande de **ne pas faire tout le shell en custom Metal**. Ce serait coûteux, peu accessible, peu productif pour les outils, et inutilement complexe. En revanche, le HUD in-game, les widgets visuels stylisés et les previews 3D doivent être rendus côté Metal quand la qualité/animation/performance l’exige.

---

## 1. Contraintes et objectifs IsoWorld

Le repo IsoWorldPOC est actuellement un POC macOS Swift avec ambition de monde 3D procédural, vue isométrique/orbitale, terrain vertical, génération par chunks autour du joueur, support manette PS5, architecture découplée et testable. Le repo contient aussi une organisation `EngineCore`, une app SwiftUI, des docs et un wrapper build local `xcodebuild-safe.sh`.

Cela implique que le flux d’app doit respecter plusieurs contraintes :

- **Le moteur ne doit pas dépendre de SwiftUI.** SwiftUI pilote l’expérience utilisateur, mais `EngineCore` doit rester testable hors UI.
- **Le monde réel ne doit pas être ouvert avant que les invariants soient prêts.** Le seed, le `WorldDNA`, les règles de monde, les premiers chunks, les caches essentiels et les paramètres de rendu doivent être validés.
- **Le debug world doit être instantané et reproductible.** Il doit permettre de tester un système sans dépendre d’un monde réel lourd.
- **Les outils doivent être accessibles sans lancer une simulation complète.** Un générateur de prop, un éditeur de biome ou un node graph doivent pouvoir fonctionner dans des previews isolées.
- **Les transitions doivent être annulables.** L’utilisateur peut revenir au menu pendant une génération.
- **Les erreurs doivent être lisibles.** Seed invalide, génération impossible, incohérence de règles, asset manquant, shader absent, cache corrompu, etc.
- **Le système doit préparer l’avenir.** Plus tard : sauvegardes, profils, benchmarks, capture/replay, scènes de test, packs de règles, worlds favoris, mods/data packs.

---

## 2. Décision architecturale principale

### 2.1 Recommandation

Utiliser une architecture **Shell SwiftUI/AppKit + Viewports Metal + EngineCore state machine**.

Concrètement :

```text
IsoWorldApp
└── AppShellFeature
    ├── MainMenuFeature
    ├── LoadingFeature
    ├── WorldRuntimeFeature
    │   ├── MetalWorldViewport
    │   ├── RuntimeHUDBridge
    │   └── Pause/Overlay/Diagnostics
    ├── DebugWorldFeature
    │   ├── MetalDebugViewport
    │   └── ToolSidebar
    └── ProceduralToolsFeature
        ├── ToolRegistry
        ├── NodeGraphWorkspace
        ├── AssetPreviewViewport
        ├── Inspectors
        └── Validators

EngineCore
├── WorldGeneration
├── ChunkStreaming
├── ProceduralSystems
├── RenderingBridge
├── ToolingProtocols
├── JobSystem
├── Persistence
└── Diagnostics
```

### 2.2 Pourquoi SwiftUI pour le shell ?

SwiftUI est adapté pour :

- l’écran menu,
- la navigation macOS,
- les formulaires seed/options,
- les listes d’outils,
- les inspecteurs,
- la barre de chargement,
- les panneaux de debug,
- la persistance de préférences,
- les raccourcis clavier,
- les thèmes du shell,
- les fenêtres multiples futures.

Apple documente `NavigationSplitView` comme un composant prévu pour des vues à deux ou trois colonnes, typiquement racine d’une scène d’application. Cela correspond très bien au debug world et au hub d’outils : sidebar, contenu central, inspector.  
Source : [Apple — NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)

### 2.3 Pourquoi Metal pour les viewports ?

Le monde, les previews d’assets, les visualisations terrain/biome/FX et les outils graphiques avancés doivent utiliser Metal. `MTKView` fournit une vue Metal prête à rendre à l’écran, avec drawable, render pass descriptor, depth/stencil optionnels, antialiasing et `CAMetalLayer`.  
Source : [Apple — MTKView](https://developer.apple.com/documentation/metalkit/mtkview)

### 2.4 Pourquoi pas ImGui comme UI principale ?

Dear ImGui est excellent pour des outils debug rapides, mais moins adapté comme UI principale macOS : accessibilité limitée, style natif absent, intégration clavier/focus complexe, widgets app-level à reconstruire, localisation plus manuelle. Le docking/multi-viewports est puissant pour des outils moteur, et la branche docking est largement utilisée, mais cela reste plus pertinent comme couche debug interne que comme shell produit final.  
Source : [Dear ImGui Wiki — Docking](https://github.com/ocornut/imgui/wiki/Docking)

### 2.5 Position finale

| Zone | Technologie recommandée | Raison |
|---|---|---|
| Main menu | SwiftUI | Productivité, navigation, accessibilité, style macOS |
| Loading screen | SwiftUI + preview Metal optionnelle | Progress UI fiable, possibilité d’animation stylisée |
| World viewport | Metal / MTKView | Rendu moteur temps réel |
| Debug tools sidebar | SwiftUI | Inspectors, sliders, listes, toggles, graphes simples |
| Node graph avancé | SwiftUI Canvas au début, custom Metal plus tard | Démarrer vite, migrer si besoin performance/UX |
| Asset preview | Metal | Qualité rendu identique moteur |
| Tool windows futures | SwiftUI/AppKit multi-window | macOS natif |
| HUD in-game | Custom Metal ou système UI dédié | Style monde, animations, intégration renderer |
| Debug overlay ultra rapide | Option ImGui ou SwiftUI overlay | ImGui acceptable uniquement pour prototypage |

---

## 3. State machine globale de l’application

Le flux ne doit pas être une accumulation de booléens SwiftUI (`isLoading`, `showDebug`, `showTools`, etc.). Il faut une **state machine explicite**.

### 3.1 États principaux

```swift
enum AppMode: Equatable {
    case boot(BootState)
    case mainMenu(MainMenuState)
    case preparingDebugWorld(DebugWorldPrepareState)
    case debugWorld(DebugWorldState)
    case preparingRealWorld(WorldPrepareState)
    case realWorld(WorldRuntimeState)
    case proceduralTools(ToolsHubState)
    case fatalError(AppFatalErrorState)
}
```

### 3.2 Transitions autorisées

```text
boot
  -> mainMenu
  -> fatalError

mainMenu
  -> preparingDebugWorld
  -> preparingRealWorld
  -> proceduralTools

preparingDebugWorld
  -> debugWorld
  -> mainMenu
  -> fatalError

preparingRealWorld
  -> realWorld
  -> mainMenu
  -> fatalError

debugWorld
  -> mainMenu
  -> proceduralTools
  -> preparingDebugWorld

realWorld
  -> mainMenu
  -> proceduralTools? optionnel, via pause/dev mode
  -> preparingRealWorld? restart seed

proceduralTools
  -> mainMenu
  -> preparingDebugWorld
  -> preparingRealWorld? generate from tool preset
```

### 3.3 Règles importantes

- Un seul mode runtime actif à la fois.
- Un monde debug et un monde réel ne doivent pas partager les mêmes instances de simulation.
- Les tâches de génération doivent être annulées quand on revient au menu.
- Les ressources GPU doivent être libérées explicitement au changement de mode.
- Les caches peuvent survivre au changement de mode si leur clé est stable.
- Les erreurs récupérables retournent au menu avec diagnostic.
- Les erreurs fatales ouvrent une vue dédiée avec logs exportables.

---

## 4. Flux utilisateur complet

### 4.1 Boot

Au lancement :

1. Créer `AppEnvironment`.
2. Initialiser les services légers : logging, settings, file system, device capabilities, renderer capability probe.
3. Vérifier GPU/Metal.
4. Charger les préférences utilisateur.
5. Scanner les tool modules disponibles.
6. Vérifier les packs de règles/data assets.
7. Passer au menu.

Le boot ne doit pas charger un monde. Il ne doit charger que les informations nécessaires pour afficher le menu et valider que l’environnement moteur est viable.

### 4.2 Main Menu

Le menu affiche trois actions principales :

1. **Mode Debug**
2. **Générer un World réel**
3. **Outils procéduraux / paramétriques**

Il peut aussi afficher :

- version moteur,
- device/GPU,
- build type,
- dernier seed utilisé,
- presets favoris,
- raccourcis,
- statut de caches,
- bouton préférences,
- bouton documentation,
- bouton quitter.

### 4.3 Debug World

Le mode debug ouvre un monde restreint, configurable, fait pour tester le moteur.

Layout recommandé :

```text
┌──────────────────────────────────────────────────────────────┐
│ Toolbar: Back | Reload | Scenario | Capture | Stats | Search │
├───────────────────────────────────────────────┬──────────────┤
│                                               │ Tool Sidebar │
│              Metal Debug Viewport             │              │
│                                               │ - Systems    │
│                                               │ - Inspectors │
│                                               │ - Parameters │
│                                               │ - Logs       │
│                                               │ - DebugDraw  │
└───────────────────────────────────────────────┴──────────────┘
```

Le monde debug doit être :

- petit,
- stable,
- reproductible,
- chargé rapidement,
- configurable par scénario,
- riche en cas de test,
- instrumenté.

### 4.4 Générer un World réel

Le flux recommandé :

1. L’utilisateur clique **Générer un World réel**.
2. Vue seed/options.
3. L’utilisateur choisit : seed texte ou random, profil monde, difficulté, taille de preview, mode expérimental ou stable.
4. Clic **Générer**.
5. L’app passe en `preparingRealWorld`.
6. La barre de chargement affiche les phases.
7. Le monde ne s’ouvre que quand les données minimales sont prêtes.
8. Le joueur arrive dans le monde.

### 4.5 Hub d’outils procéduraux

Le hub d’outils est une app dans l’app. Il doit permettre de travailler sur :

- terrain,
- biomes,
- props,
- bâtiments,
- personnages,
- animations,
- particules/FX,
- audio,
- UI/HUD,
- RPG rules,
- materials/textures,
- lighting,
- LOD/virtual geometry,
- weather,
- world generation,
- debug visualizers,
- validation/benchmark.

Layout recommandé :

```text
┌──────────────────────────────────────────────────────────────┐
│ Top Bar: Tools | Project | Seed | Presets | Validate | Build │
├───────────────┬───────────────────────────────┬──────────────┤
│ Tool Library  │ Workspace                     │ Inspector    │
│ - Terrain     │ - Node graph                  │ - Params     │
│ - Props       │ - Preview viewport            │ - Rules      │
│ - Characters  │ - Timeline                    │ - Variants   │
│ - Audio       │ - Data table                  │ - Metrics    │
│ - FX          │                               │              │
└───────────────┴───────────────────────────────┴──────────────┘
```

---

## 5. Main Menu — design détaillé

### 5.1 Objectif

Le menu n’est pas seulement un écran de choix. C’est le **point de contrôle** du moteur :

- choisir une expérience,
- voir le statut moteur,
- lancer un monde,
- accéder aux outils,
- revenir proprement après une session,
- gérer les erreurs.

### 5.2 Contenu minimal

```text
IsoWorld
[ Mode Debug ]
[ Générer un World réel ]
[ Outils procéduraux / paramétriques ]

Dernier seed : NIGHT-FOREST-7132
Renderer : Metal / Apple GPU / OK
Build : Debug / Xcode wrapper safe
Docs : ouvrir dossier docs
Settings : préférences
```

### 5.3 Contenu avancé futur

- **Recent Worlds** : seeds récents avec snapshots.
- **Favorite Seeds** : seeds marqués.
- **World Profiles** : stable, chaos, exploration, RPG, benchmark.
- **Continue** : rouvrir une sauvegarde.
- **Benchmark Mode** : tester performance génération/rendu.
- **Replay Mode** : rejouer une capture déterministe.
- **Data Pack Manager** : activer/désactiver packs procéduraux.
- **Shader Warmup** : précompiler les pipelines importants.
- **Cache Manager** : purger caches terrain/props/textures.
- **Safe Mode** : démarrage sans outils expérimentaux.

### 5.4 Style

Le menu peut être semi-procédural :

- fond animé léger selon un seed de menu,
- preview stylisée du monde,
- petites silhouettes de biomes,
- rotation lente de props générés,
- bruit audio ambiant simple,
- thèmes UI cohérents avec le dernier monde.

Mais il doit rester léger. Aucun système lourd ne doit bloquer le menu.

---

## 6. Debug World — architecture détaillée

### 6.1 But

Le debug world est un laboratoire de test. Il doit permettre de tester un système isolé ou plusieurs systèmes ensemble.

Exemples :

- placement des pieds sur rochers,
- transition de biome,
- génération d’un arbre paramétrique,
- rivière qui traverse une falaise,
- bâtiment attaché à une pente,
- particules pluie + sol mouillé,
- audio pas sur boue vs pierre,
- lighting d’un biome enneigé,
- LOD de falaise,
- HUD adaptatif,
- PNJ généré et équipé.

### 6.2 Scénarios debug

Un scénario debug est une recette déterministe :

```swift
struct DebugScenario: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let seed: UInt64
    let worldBounds: DebugWorldBounds
    let systems: Set<EngineSystemID>
    let terrainPreset: TerrainPresetID
    let biomePreset: BiomePresetID?
    let spawnPreset: SpawnPresetID
    let toolLayout: ToolLayoutID
    let debugFlags: DebugFlagSet
}
```

### 6.3 Liste de scénarios à prévoir

#### Terrain / verticalité

- Flat Baseline
- Slope Ramp
- Cliff Climb Test
- Canyon Wall Test
- Stair Attached To Rock
- Rope Anchor Test
- Cave Entrance Test
- Overhang SDF Test
- River Cutting Cliff
- Wet Rock Slip Test
- Snow Slope Test
- Mud Deformation Test
- Micro Obstacles Foot IK

#### Biomes

- Hard Biome Border Test
- Smooth Ecotone Test
- Desert To Oasis
- Forest To Swamp
- Alpine Treeline
- Snowline Altitude
- Coastal Wetland
- Burned Forest Regrowth

#### Props

- Tree Variant Gallery
- Rock Scatter Stress
- Manufactured Props Grid
- Procedural Furniture
- Lamp Post On Slope
- Asset Material Aging
- Collision Proxy Debug

#### Characters / animation

- Foot Placement Rocks
- Shoe Material Friction
- Wet Ground Walk
- Heavy Armor Walk
- Missing Limb State
- Aging Body State
- Climb Rope Test
- Stumble Recovery
- Active Ragdoll Contact

#### FX / audio

- Rain + Surface Wetness
- Snow Particles + Footprints
- Dust Wind Gust
- Fire Smoke Low Cost
- Footstep Audio Matrix
- Animal Call Generator

#### Buildings / settlements

- Village On Hillside
- Camp On Uneven Ground
- Cliffside Stair Structure
- Factory On Terraces
- Bridge Attachment Test
- Interior Streaming Test

#### UI/HUD

- Minimal Exploration HUD
- Debug Overlay Stress
- World Mood Theme Switch
- Accessibility Contrast Test
- Gamepad Navigation Test

### 6.4 Debug panels

Le panneau droit du debug world doit être modulaire.

Modules recommandés :

- **World Inspector** : seed, chunk, biome, altitude, weather, time.
- **Renderer Stats** : FPS, frame time, draw calls, triangles, clusters, textures, GPU memory.
- **Generation Inspector** : jobs actifs, chunks queued, caches hits/misses.
- **Entity Inspector** : joueur, PNJ, props, collisions.
- **Terrain Debug** : normals, slope, material, wetness, navigability, climbable, support map.
- **Biome Debug** : weights, ecotone width, rules, sub-biome id.
- **Animation Debug** : foot targets, IK weights, contact normals, friction.
- **Audio Debug** : emitters, buses, procedural synth parameters.
- **FX Debug** : particle counts, overdraw, emitters, LOD.
- **AI/RPG Debug** : rules, factions, objectives, storylets.
- **Profiler** : CPU/GPU budget by system.
- **Console** : commands.
- **Capture** : snapshots deterministic replay.

### 6.5 Navigation retour menu

Le bouton retour menu doit :

1. Pauser simulation.
2. Demander confirmation si des changements d’outil non sauvegardés existent.
3. Annuler les jobs debug.
4. Sauvegarder layout outil.
5. Libérer ressources runtime non partagées.
6. Revenir à `mainMenu`.

---

## 7. Génération d’un World réel — pipeline de loading

### 7.1 Principe

Un monde réel IsoWorld ne doit pas être ouvert immédiatement après saisie du seed. Il faut une phase `WorldPreparePipeline` qui fabrique le minimum viable :

- `WorldDNA`,
- règles globales,
- profil RPG,
- carte macro climatique/géologique légère,
- spawn player valide,
- chunks initiaux,
- caches critiques,
- premières ressources visuelles,
- world runtime session.

### 7.2 Barre de chargement

Apple recommande les progress indicators pour montrer la progression d’une tâche, et `ProgressView` peut être déterminé ou indéterminé. Pour IsoWorld, il faut préférer une progression **déterminée par phases pondérées** quand c’est possible.  
Sources : [Apple HIG — Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators), [Apple — ProgressView](https://developer.apple.com/documentation/swiftui/progressview)

### 7.3 Phases recommandées

```text
0. Validate seed and options                  2%
1. Create WorldDNA                           5%
2. Generate rule constitution                8%
3. Build macro climate/geology fields       12%
4. Resolve biomes/ecotones                  10%
5. Resolve RPG world profile                10%
6. Find valid player spawn                  10%
7. Generate initial terrain chunks          15%
8. Generate initial props/buildings         10%
9. Prepare renderer resources               8%
10. Warm up shaders/pipelines               5%
11. Build collision/nav initial data         3%
12. Commit session and enter world           2%
```

Les pourcentages ne doivent pas être mensongers. Il vaut mieux afficher :

- phase courante,
- sous-tâche,
- progression déterminée quand disponible,
- indicateur indéterminé pour tâches non mesurables,
- bouton annuler.

### 7.4 Modèle de progression

```swift
struct LoadingProgress: Equatable, Sendable {
    var title: String
    var currentPhase: LoadingPhaseID
    var phaseName: String
    var phaseProgress: Double?       // nil = indeterminate
    var globalProgress: Double?      // nil = indeterminate
    var detail: String
    var warnings: [LoadingWarning]
    var canCancel: Bool
}
```

### 7.5 Phases annulables

Swift concurrency utilise un modèle de cancellation coopératif : une tâche vérifie si elle a été annulée et répond aux points appropriés. C’est important pour la génération de monde : chaque étape longue doit vérifier la cancellation, fermer proprement ses ressources et retourner un état cohérent.  
Source : [Swift.org — Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)

### 7.6 Pré-calculs à faire avant ouverture

#### Obligatoires

- Normalisation seed texte → seed numérique stable.
- Création `WorldDNA`.
- Choix rulesets : biome, terrain, RPG, météo, audio, UI thème.
- Validation des règles incompatibles.
- Détermination époque/genre/objectif global si mode RPG.
- Détermination position spawn.
- Génération des chunks dans un rayon initial.
- Génération collision minimale autour du spawn.
- Préparation renderer session.
- Chargement/compilation pipeline Metal critique.
- Préparation player entity.

#### Recommandés

- Preview miniature de monde.
- Mini-carte macro.
- Estimation de difficulté/ambiance.
- Pré-chargement des matériaux dominants.
- Pré-chargement des sons d’ambiance dominants.
- Pré-chargement des props fréquents du biome spawn.
- Pré-calcul navmesh local ou nav sampling local.
- Pré-calcul des zones dangereuses proches.

#### Optionnels

- Génération plus large en arrière-plan après ouverture.
- Cache de texture terrain locale.
- Pré-calcul occlusion/probes légers.
- Pré-génération de quêtes initiales.
- Pré-génération de colonies proches.
- Pré-génération de PNJ proches.

### 7.7 WorldPreparePipeline

```swift
actor WorldPreparePipeline {
    func prepareWorld(
        request: WorldPrepareRequest,
        progress: @Sendable @escaping (LoadingProgress) async -> Void
    ) async throws -> PreparedWorldSession {
        try Task.checkCancellation()
        let seed = try SeedParser.parse(request.seedText)
        await progress(.phase(.worldDNA, 0.0, "Création du WorldDNA"))
        let dna = try WorldDNAGenerator(seed: seed, options: request.options).generate()

        try Task.checkCancellation()
        let rules = try WorldRuleCompiler.compile(dna)

        try Task.checkCancellation()
        let macro = try await MacroWorldBuilder(rules).build(progress: progress)

        try Task.checkCancellation()
        let spawn = try SpawnResolver.resolve(macro, rules)

        try Task.checkCancellation()
        let initialChunks = try await InitialChunkBuilder(
            rules: rules,
            spawn: spawn,
            radius: request.initialChunkRadius
        ).build(progress: progress)

        try Task.checkCancellation()
        let renderSession = try await RenderSessionPreparer().prepare(
            rules: rules,
            chunks: initialChunks
        )

        return PreparedWorldSession(
            seed: seed,
            dna: dna,
            rules: rules,
            macro: macro,
            spawn: spawn,
            initialChunks: initialChunks,
            renderSession: renderSession
        )
    }
}
```

### 7.8 Éviter le faux loading

La barre de loading doit refléter un vrai état moteur. À éviter :

- sleep artificiel,
- pourcentage linéaire arbitraire,
- chargement bloqué main thread,
- compilation shader pendant la première frame sans feedback,
- génération de chunks synchrones dans la vue SwiftUI,
- ouverture d’un monde partiellement invalide.

### 7.9 Échec de génération

Une génération peut échouer. Exemples :

- seed génère un spawn dans un océan inaccessible,
- règles RPG incompatibles,
- biome dominant sans assets nécessaires,
- shader manquant,
- génération de settlement impossible,
- collision player invalide,
- world profile expérimental cassé.

Il faut une vue d’erreur :

```text
Impossible de générer le monde
Seed : RED-MOON-421
Phase : ResolvePlayerSpawn
Raison : aucun point de spawn sûr dans le rayon initial.

[ Réessayer ] [ Changer Options ] [ Copier Diagnostic ] [ Retour Menu ]
```

---

## 8. Hub d’outils procéduraux / paramétriques

### 8.1 Objectif

Le hub d’outils doit devenir le centre de production du moteur. Il doit permettre de créer, tester, valider et visualiser tous les systèmes procéduraux sans ouvrir un vrai monde complet.

### 8.2 Tool Registry

Chaque système moteur expose un module outil via un protocole.

```swift
protocol IsoWorldToolModule: Sendable {
    var id: ToolID { get }
    var name: String { get }
    var category: ToolCategory { get }
    var icon: ToolIcon { get }
    var capabilities: ToolCapabilities { get }

    func makeDefaultDocument(seed: UInt64) -> ToolDocument
    func makePreviewSession(document: ToolDocument) async throws -> ToolPreviewSession
    func validate(document: ToolDocument) async -> [ToolDiagnostic]
    func export(document: ToolDocument) async throws -> ToolExportArtifact
}
```

### 8.3 Catégories d’outils

#### World

- WorldDNA Editor
- Seed Explorer
- Rule Constitution Editor
- World Profile Browser
- Macro Map Preview
- Spawn Resolver Debugger
- Chunk Streaming Debugger
- Determinism Replay Tool

#### Terrain

- Terrain Node Graph
- Heightfield Preview
- SDF Cave Tool
- Cliff Attachment Tool
- River Basin Tool
- Erosion Preview
- Material Layer Painter procédural
- Collision/Navigability Viewer

#### Biomes

- Biome Graph Editor
- Ecotone Designer
- Sub-biome Rule Table
- Climate Field Viewer
- Vegetation Density Tool
- Biome Material Mixer

#### Props

- Prop Recipe Editor
- Tree Generator
- Rock Generator
- Plant Generator
- Furniture Generator
- Manufactured Object Generator
- Collision Proxy Builder
- LOD Preview

#### Buildings / settlements

- Building Grammar Editor
- Parcel Generator
- Village Layout Tool
- City District Tool
- Camp Generator
- Factory Generator
- Interior Room Tool
- Terrain Adaptation Visualizer

#### Characters

- CharacterDNA Editor
- Body Morph Preview
- Face Generator
- Clothing Layer Tool
- Accessory/Weapon Tool
- Injury/Aging State Tool
- Groom/Hair Preview
- LOD Character Preview

#### Animation

- Motion Matching Preview
- Foot IK Debugger
- Terrain Contact Tool
- Climbing/Rope Test Tool
- Ragdoll Response Tool
- Animation State Graph

#### Audio

- Procedural Footstep Synth
- Biome Ambience Composer
- Wind/Rain Generator
- Animal Voice Generator
- Interactive Music Graph
- Audio Occlusion Preview

#### FX

- Particle Graph Editor
- Weather FX Tool
- Impact FX Tool
- Decal FX Tool
- Trail/Ribbon Tool
- GPU Particle Budget Viewer

#### Rendering

- Material Graph
- Texture Layer Preview
- Lighting Probe Tool
- Shadow Debugger
- LOD/Virtual Geometry Debugger
- Post-Process Tuner

#### UI/HUD

- HUD Theme Generator
- UI Token Editor
- World Mood Theme Preview
- Gamepad Navigation Tester
- Accessibility Contrast Checker

#### RPG

- WorldRPGDNA Editor
- Quest Rule Graph
- Faction Generator
- Objective Generator
- Storylet Browser
- Economy Rule Tool
- Reputation Matrix Tool

### 8.4 Tool documents

Chaque outil manipule un document sérialisable.

```swift
struct ToolDocument: Identifiable, Codable, Sendable {
    let id: UUID
    var toolID: ToolID
    var name: String
    var seed: UInt64
    var schemaVersion: Int
    var graph: NodeGraph?
    var parameters: [ParameterID: ParameterValue]
    var metadata: ToolDocumentMetadata
}
```

### 8.5 Previews isolées

Un outil ne doit pas dépendre d’un monde complet. Il peut demander :

- un viewport 3D isolé,
- un mini-terrain,
- un patch biome,
- un mannequin character,
- une scène de test,
- une simulation audio offline,
- une simulation FX courte,
- une preview image.

### 8.6 Validation

Chaque outil doit fournir des diagnostics :

- erreur bloquante,
- warning,
- info,
- performance risk,
- determinism risk,
- asset dependency missing,
- GPU budget risk,
- gameplay inconsistency.

Exemple :

```text
[Warning] PropRecipe.Tree.OakHeavy utilise 18 matériaux différents : risque batching.
[Error] BuildingGrammar.CliffHouse génère une porte non accessible sur pente > 67°.
[Perf] ParticleFX.MagicStorm dépasse 40k particules dans le preset Ultra.
[Determinism] Node RandomFloat utilise un RNG non seedé.
```

---

## 9. Architecture d’état moderne

### 9.1 Besoin

L’application aura beaucoup d’écrans et d’états imbriqués. Il faut éviter :

- états UI dispersés,
- singleton global incontrôlé,
- logique moteur dans les Views,
- tâches async lancées depuis trop d’endroits,
- navigation impossible à tester,
- erreurs invisibles.

### 9.2 Option simple recommandée au départ

Créer une architecture interne inspirée des principes de state/reducer/effects sans forcément dépendre d’une librairie externe.

```swift
@Observable
final class AppStore {
    private(set) var state: AppState
    private let environment: AppEnvironment

    func send(_ action: AppAction) {
        // reducer sync
        // launch effects
    }
}
```

Apple Observation fournit un modèle d’observation type-safe et performant pour Swift, et SwiftUI peut observer les modèles via cette infrastructure.  
Source : [Apple — Observation](https://developer.apple.com/documentation/observation)

### 9.3 Option avancée possible

The Composable Architecture propose une approche structurée pour gérer state management, composition, navigation, side effects et tests. C’est pertinent si le shell devient très grand, mais ajouter une dépendance doit rester un choix maîtrisé.  
Source : [pointfreeco/swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture)

### 9.4 Recommandation finale

- **Phase 1** : architecture interne minimaliste `AppStore + Reducer + Effects`.
- **Phase 2** : si complexité forte, évaluer TCA.
- **Toujours** : garder `EngineCore` indépendant.

---

## 10. Navigation UI

### 10.1 Root view

```swift
struct AppRootView: View {
    @Bindable var store: AppStore

    var body: some View {
        switch store.state.mode {
        case .boot(let state):
            BootView(state: state)
        case .mainMenu(let state):
            MainMenuView(state: state, send: store.send)
        case .preparingDebugWorld(let state):
            LoadingView(state: state, send: store.send)
        case .debugWorld(let state):
            DebugWorldView(state: state, send: store.send)
        case .preparingRealWorld(let state):
            LoadingView(state: state, send: store.send)
        case .realWorld(let state):
            WorldRuntimeView(state: state, send: store.send)
        case .proceduralTools(let state):
            ToolsHubView(state: state, send: store.send)
        case .fatalError(let state):
            FatalErrorView(state: state, send: store.send)
        }
    }
}
```

### 10.2 DebugWorldView

Utiliser `NavigationSplitView` ou un layout custom split.

```swift
struct DebugWorldView: View {
    var body: some View {
        HSplitView {
            MetalWorldViewport(session: state.viewportSession)
                .frame(minWidth: 640)

            DebugToolSidebar(state: state.sidebar)
                .frame(minWidth: 320, idealWidth: 420)
        }
        .toolbar {
            Button("Menu") { send(.debugWorld(.backToMenuTapped)) }
            Button("Reload") { send(.debugWorld(.reloadScenarioTapped)) }
            Picker("Scenario", selection: ... ) { ... }
        }
    }
}
```

### 10.3 ToolsHubView

```swift
struct ToolsHubView: View {
    var body: some View {
        NavigationSplitView {
            ToolLibraryView(...)
        } content: {
            ToolWorkspaceView(...)
        } detail: {
            ToolInspectorView(...)
        }
    }
}
```

---

## 11. Gestion des tâches async et jobs moteur

### 11.1 Règle centrale

Les tâches longues ne doivent pas être lancées directement depuis une View. Elles doivent être déclenchées par une action, orchestrées par un service, et refléter leur état dans `AppState`.

### 11.2 Types de tâches

- Boot tasks
- Tool scanning
- Debug world preparation
- Real world preparation
- Shader warmup
- Chunk generation
- Preview rendering
- Tool validation
- Cache cleanup
- Export
- Screenshot/capture

### 11.3 JobSystem

```swift
protocol EngineJob: Sendable {
    associatedtype Output: Sendable
    var id: JobID { get }
    var priority: JobPriority { get }
    func run(context: JobContext) async throws -> Output
}
```

### 11.4 Priorités

| Priorité | Usage |
|---|---|
| Critical | ouvrir monde, renderer setup, spawn |
| High | chunks proches, collision proche, player systems |
| Normal | previews, validation, tools |
| Low | caches, thumbnails, distant world pregen |
| Background | nettoyage, stats, indexing |

### 11.5 Cancellation

Toutes les tâches doivent être annulables :

- retour menu,
- changement seed,
- fermeture app,
- changement d’outil,
- reload scenario,
- erreur fatale.

---

## 12. Persistance et données utilisateur

### 12.1 À persister

- derniers seeds,
- favoris,
- préférences renderer,
- préférences input,
- layouts outils,
- documents outils,
- presets générateurs,
- captures debug,
- logs récents,
- cache metadata,
- profils monde.

### 12.2 SwiftData ou fichiers JSON ?

Apple présente SwiftData comme un framework de persistance intégré permettant de définir des modèles persistables via des classes de modèle et de les gérer via un contexte.  
Source : [Apple — SwiftData](https://developer.apple.com/documentation/swiftdata)

Recommandation :

- **SwiftData** pour préférences structurées, seeds récents, index de documents, profils utilisateur.
- **Fichiers JSON/YAML/TOML versionnés** pour presets moteur, rulesets, graphes procéduraux, docs exportables.
- **Fichiers binaires cache** pour chunks précompilés, thumbnails, données accélérées.
- **Manifestes versionnés** pour migration.

### 12.3 Structure de dossiers

```text
~/Library/Application Support/IsoWorld/
├── Settings/
│   ├── app-settings.json
│   ├── renderer-settings.json
│   └── input-settings.json
├── Worlds/
│   ├── recent-worlds.json
│   └── saves/
├── ToolDocuments/
│   ├── terrain/
│   ├── props/
│   ├── characters/
│   ├── audio/
│   └── rpg/
├── Presets/
├── Cache/
│   ├── chunks/
│   ├── shaders/
│   ├── thumbnails/
│   └── previews/
├── Captures/
├── Logs/
└── Diagnostics/
```

---

## 13. Architecture des services

### 13.1 AppEnvironment

```swift
struct AppEnvironment: Sendable {
    let engine: EngineCoreFacade
    let rendererFactory: RendererFactory
    let worldPreparePipeline: WorldPreparePipeline
    let debugWorldFactory: DebugWorldFactory
    let toolRegistry: ToolRegistry
    let persistence: PersistenceService
    let settings: SettingsService
    let diagnostics: DiagnosticsService
    let cache: CacheService
    let clock: ClockService
    let idGenerator: IDGenerator
}
```

### 13.2 EngineCoreFacade

Le shell ne parle pas directement à tous les sous-systèmes. Il utilise une façade.

```swift
protocol EngineCoreFacade: Sendable {
    func boot() async throws -> EngineBootReport
    func prepareDebugWorld(_ request: DebugWorldRequest) async throws -> DebugWorldSession
    func prepareRealWorld(_ request: WorldPrepareRequest) async throws -> PreparedWorldSession
    func shutdownSession(_ sessionID: EngineSessionID) async
}
```

### 13.3 RendererFactory

```swift
protocol RendererFactory: Sendable {
    func makeWorldRenderer(session: WorldRuntimeSession) throws -> WorldRendererHandle
    func makePreviewRenderer(config: PreviewRendererConfig) throws -> PreviewRendererHandle
    func release(_ handle: RendererHandle) async
}
```

---

## 14. Mode Debug — world à gauche, outils à droite

### 14.1 Composition recommandée

```text
DebugWorldState
├── scenario
├── worldSession
├── viewportState
├── selectedToolPanel
├── sidebarState
├── debugDrawFlags
├── selectedEntity
├── consoleState
├── profilerState
└── dirtyToolDocuments
```

### 14.2 Interaction viewport → outils

Exemples :

- cliquer sur un prop sélectionne son `EntityID` dans l’inspector,
- cliquer sur un chunk affiche génération/caches,
- cliquer sur terrain affiche biome/material/slope/wetness,
- cliquer sur joueur affiche animation contacts/IK/collision,
- dessiner une zone permet d’isoler un test.

### 14.3 Interaction outils → viewport

Exemples :

- activer debug normals,
- afficher foot IK targets,
- afficher chunks bounds,
- forcer météo pluie,
- changer matériau de sol,
- spawn prop,
- changer seed local,
- reload shader,
- téléporter joueur,
- isoler biomes,
- capturer frame.

### 14.4 Command palette

Prévoir une palette type `Cmd+K` :

- `Open Terrain Debugger`
- `Spawn Tree Variant`
- `Toggle Biome Weights`
- `Reload Current Scenario`
- `Capture Deterministic Replay`
- `Teleport To Cliff Test`
- `Open Material Inspector`
- `Export Diagnostics`

---

## 15. Real World — ouverture après loading

### 15.1 Runtime world view

Le monde réel doit être plus minimal que debug :

- viewport plein écran ou quasi plein écran,
- HUD in-game,
- menu pause,
- overlay diagnostics optionnel en dev,
- aucun outil lourd visible par défaut.

### 15.2 Pause menu

```text
Resume
World Info
Settings
Diagnostics
Return To Main Menu
Quit
```

### 15.3 Retour menu depuis monde réel

- sauvegarder si nécessaire,
- confirmer perte de session si non sauvegardée,
- flush logs,
- arrêter streaming chunks,
- arrêter audio/FX,
- libérer renderer session,
- retour `mainMenu`.

---

## 16. Génération seed/options — UX détaillée

### 16.1 Écran seed

Champs :

- seed texte,
- bouton random,
- profil monde,
- complexité procédurale,
- qualité rendu initiale,
- mode RPG rules,
- densité de settlements,
- présence ennemis,
- époque dominante,
- biome bias,
- mode stable/expérimental,
- rayon initial de génération,
- preset performance.

### 16.2 Profils de monde

- Exploration stable
- Debug realistic
- High fantasy wilderness
- Low tech survival
- Modern procedural earthlike
- Far future alien world
- No enemies contemplative
- Harsh survival hostile
- Dense settlements
- Mostly wilderness
- Extreme verticality
- Water world
- Frozen world
- Desert planet
- Underground civilization
- Procedural benchmark

### 16.3 Preview avant génération complète

Option future : générer une preview macro en 1–3 secondes :

- palette de biomes,
- époque,
- règles RPG majeures,
- niveau de danger,
- type de spawn,
- miniature carte macro.

Cela permet à l’utilisateur de relancer un seed avant de charger le monde complet.

---

## 17. Outils procéduraux — architecture de workspace

### 17.1 Workspace universel

Un outil peut contenir :

- viewport,
- node graph,
- inspector,
- timeline,
- data table,
- console,
- validation panel,
- documentation contextuelle,
- preset browser.

### 17.2 Types de workspace

| Type | Exemples |
|---|---|
| Preview 3D | props, characters, buildings |
| Preview 2D | biome maps, terrain masks, UI themes |
| Node graph | terrain, FX, audio, materials, RPG rules |
| Timeline | animation, audio, weather |
| Data table | biome rules, assets, loot, stats |
| Split compare | comparer deux seeds/variantes |
| Gallery | variantes générées en grille |
| Inspector live | debug d’un système runtime |

### 17.3 Node graph

Le node graph doit être commun à plusieurs systèmes :

- Terrain graph
- Prop graph
- Material graph
- FX graph
- Audio graph
- RPG rule graph
- Biome transition graph
- UI theme graph

Mais chaque domaine doit avoir ses types de nœuds propres.

### 17.4 Graph execution

```text
Authoring Graph
  -> Validation
  -> Intermediate Representation
  -> Runtime Recipe
  -> Deterministic Evaluation
  -> Preview / Runtime
```

---

## 18. Qualité, diagnostics et observabilité

### 18.1 Pourquoi c’est critique

Un moteur procédural peut échouer de manière subtile :

- génération incohérente,
- monde non navigable,
- seed non déterministe,
- cache incorrect,
- performance variable,
- spikes CPU,
- ressources GPU non libérées,
- mémoire qui gonfle après plusieurs retours menu.

Il faut donc intégrer les diagnostics au flux app.

### 18.2 Diagnostics globaux

- FPS / frame time CPU-GPU
- draw calls
- triangles / clusters
- mémoire CPU
- mémoire GPU estimée
- chunks actifs
- jobs actifs
- temps génération par phase
- cache hit/miss
- shader pipelines prêts
- nombre d’entités
- nombre de collisions
- audio voices
- particules actives
- erreurs/warnings par système

### 18.3 Export diagnostic

Bouton : **Export Diagnostics**

Contenu :

```text
IsoWorldDiagnostics-YYYY-MM-DD-HHMM.zip
├── app-state.json
├── engine-state.json
├── seed.txt
├── world-dna.json
├── logs.txt
├── frame-stats.csv
├── generation-timeline.json
├── tool-documents-summary.json
├── screenshot.png
└── replay-capture.isoreplay
```

---

## 19. Déterminisme et replay

### 19.1 Règle

Le flux app doit préserver le déterminisme. Le debug world et le real world doivent pouvoir être relancés avec le même seed et obtenir les mêmes résultats pour les systèmes déterministes.

### 19.2 À enregistrer

- seed global,
- version de rulesets,
- version de générateurs,
- options monde,
- actions utilisateur,
- inputs player,
- time step simulation,
- RNG streams utilisés,
- chunks générés,
- warnings de génération.

### 19.3 Replay debug

Le debug world doit pouvoir capturer :

- scénario,
- seed,
- position caméra,
- flags debug,
- inputs,
- état initial,
- événements.

Cela permet de reproduire un bug.

---

## 20. Gestion des ressources au changement de mode

### 20.1 Problème

Changer de mode peut créer des leaks : renderer, textures, buffers, audio, jobs, caches, sessions.

### 20.2 Solution

Chaque mode possède une session explicitement fermable :

```swift
protocol AppModeSession: Sendable {
    var id: SessionID { get }
    func suspend() async
    func resume() async
    func shutdown() async
}
```

### 20.3 Ressources partagées vs locales

| Ressource | Partagée ? | Notes |
|---|---:|---|
| Device Metal | Oui | unique |
| Shader library | Oui | cache global |
| Pipeline cache | Oui | mais invalidable |
| World chunks | Non | par session monde |
| Debug scenario | Non | par session debug |
| Tool document | Oui | persistant |
| Preview renderer | Non | par outil |
| Audio device | Oui | backend global |
| Audio voices | Non | par session |
| Texture cache | Oui | clés versionnées |

---

## 21. Erreurs, warnings et recovery

### 21.1 Niveaux d’erreur

- `Info` : visible dans logs.
- `Warning` : visible dans diagnostics.
- `RecoverableError` : utilisateur peut réessayer ou changer option.
- `ModeError` : retour menu nécessaire.
- `FatalError` : moteur doit redémarrer.

### 21.2 Écran erreur génération

Doit inclure :

- seed,
- phase,
- message humain,
- détails techniques repliables,
- actions recommandées,
- bouton copier diagnostic,
- bouton retour menu.

### 21.3 Auto-recovery

Exemples :

- spawn invalide → essayer 32 candidats alternatifs,
- biome asset absent → fallback biome material,
- shader pipeline absent → fallback material simple,
- cache corrompu → purge cache et retry,
- tool layout corrompu → reset layout.

---

## 22. Système de préférences

### 22.1 Catégories

- General
- Display
- Renderer
- Input
- Audio
- Debug
- Tools
- Performance
- Accessibility
- Experimental

### 22.2 Préférences importantes

```text
Renderer:
- qualité par défaut
- VSync
- résolution interne
- limite FPS
- budget GPU particles
- shadows on/off
- debug overlays

Generation:
- rayon initial chunks
- threads/jobs max
- cache agressif
- mode deterministic strict

Tools:
- layout sauvegardé
- autosave documents
- preview quality
- node graph grid

Debug:
- afficher stats par défaut
- logs verbose
- capture replay automatique sur erreur

Accessibility:
- taille texte
- contraste
- réduction mouvement
- gamepad navigation
```

---

## 23. Raccourcis clavier et manette

### 23.1 Raccourcis shell

- `Cmd+1` : Menu
- `Cmd+2` : Debug World
- `Cmd+3` : Tools Hub
- `Cmd+K` : Command Palette
- `Cmd+R` : Reload scenario/tool preview
- `Cmd+S` : Save tool document
- `Cmd+Shift+S` : Save As
- `Cmd+E` : Export diagnostics
- `Cmd+,` : Settings
- `Esc` : Pause/back selon contexte

### 23.2 Gamepad

Même si le shell est macOS, il faut prévoir :

- navigation menu manette,
- lancement world,
- pause menu,
- debug quick overlay,
- sélection d’options basique.

Les outils complexes peuvent rester clavier/souris.

---

## 24. Sécurité de l’environnement local

Le README du repo demande d’utiliser le wrapper local `./scripts/xcodebuild-safe.sh` pour fixer `DEVELOPER_DIR` localement et éviter toute modification globale de l’environnement Xcode.

Le hub d’outils ne doit jamais :

- modifier globalement Xcode,
- écrire hors dossier app/support sans autorisation,
- lancer scripts arbitraires sans sandbox interne,
- écraser des documents sans backup,
- supprimer caches sans confirmation.

---

## 25. Design data-driven

### 25.1 Pourquoi

Le flux app doit être extensible sans réécrire la navigation à chaque nouveau système.

### 25.2 Registries

- `ModeRegistry`
- `ToolRegistry`
- `DebugScenarioRegistry`
- `WorldProfileRegistry`
- `SettingsRegistry`
- `CommandRegistry`
- `DiagnosticRegistry`

### 25.3 Exemple ToolRegistry

```swift
struct ToolRegistry: Sendable {
    private var modules: [ToolID: any IsoWorldToolModule]

    func allTools() -> [ToolDescriptor]
    func module(for id: ToolID) throws -> any IsoWorldToolModule
}
```

### 25.4 Exemple DebugScenarioRegistry

```swift
struct DebugScenarioRegistry: Sendable {
    var scenarios: [DebugScenario]

    func scenarios(for system: EngineSystemID) -> [DebugScenario]
    func defaultScenario() -> DebugScenario
}
```

---

## 26. UI theming du shell

Même si le HUD procédural est un step séparé, le shell doit supporter des thèmes :

- thème clair/sombre système,
- thème moteur sombre,
- accent couleur par monde,
- icônes par catégorie,
- badges expérimentaux,
- warning color coding,
- mode high contrast.

Important : le shell ne doit pas sacrifier lisibilité/accessibilité pour le style procédural.

---

## 27. Architecture package recommandée

```text
IsoWorldPOC/
├── IsoWorldPOCApp.swift
├── AppShell/
│   ├── AppRootView.swift
│   ├── AppStore.swift
│   ├── AppState.swift
│   ├── AppAction.swift
│   ├── AppEnvironment.swift
│   └── AppReducer.swift
├── Features/
│   ├── MainMenu/
│   ├── Loading/
│   ├── DebugWorld/
│   ├── RealWorld/
│   ├── ProceduralTools/
│   ├── Settings/
│   └── Diagnostics/
├── MetalViews/
│   ├── MetalWorldView.swift
│   ├── MetalPreviewView.swift
│   └── MTKViewRepresentable.swift
├── Tooling/
│   ├── ToolRegistry.swift
│   ├── ToolModule.swift
│   ├── ToolDocument.swift
│   ├── NodeGraph/
│   └── Inspectors/
└── Resources/
    ├── DebugScenarios/
    ├── WorldProfiles/
    └── ToolPresets/

EngineCore/
├── Sources/
│   ├── EngineCore/
│   ├── WorldGeneration/
│   ├── DebugWorld/
│   ├── ProceduralSystems/
│   ├── RenderingBridge/
│   ├── Jobs/
│   ├── Diagnostics/
│   └── PersistenceContracts/
└── Tests/
```

---

## 28. Modèles Swift proposés

### 28.1 AppState

```swift
struct AppState: Equatable, Sendable {
    var mode: AppMode
    var settings: AppSettings
    var diagnostics: DiagnosticsState
    var recentWorlds: [RecentWorld]
    var toolRegistrySnapshot: ToolRegistrySnapshot
}
```

### 28.2 Actions

```swift
enum AppAction: Sendable {
    case boot(BootAction)
    case mainMenu(MainMenuAction)
    case loading(LoadingAction)
    case debugWorld(DebugWorldAction)
    case realWorld(RealWorldAction)
    case tools(ToolsHubAction)
    case settings(SettingsAction)
    case diagnostics(DiagnosticsAction)
}
```

### 28.3 MainMenuAction

```swift
enum MainMenuAction: Sendable {
    case openDebugTapped
    case generateWorldTapped
    case openToolsTapped
    case seedTextChanged(String)
    case randomSeedTapped
    case settingsTapped
    case quitTapped
}
```

### 28.4 LoadingAction

```swift
enum LoadingAction: Sendable {
    case progressUpdated(LoadingProgress)
    case cancelTapped
    case completed(PreparedSessionKind)
    case failed(LoadingFailure)
}
```

---

## 29. Testing strategy

### 29.1 Tests state machine

- boot → menu
- menu → debug → menu
- menu → real loading → world
- loading cancel → menu
- loading failure → error view
- tools → menu
- debug reload scenario
- world return menu releases session

### 29.2 Tests déterminisme

- même seed → même `WorldDNA`
- même debug scenario → mêmes chunks initiaux
- même tool document → même preview artifact
- cancellation ne laisse pas cache partiellement valide

### 29.3 Tests UI

- navigation clavier,
- progression loading,
- affichage erreurs,
- sauvegarde/restauration layout,
- tools registry vide,
- tool module qui échoue,
- renderer indisponible.

### 29.4 Tests performance

- temps boot,
- temps menu interactif,
- temps debug world,
- temps loading réel par phase,
- mémoire après plusieurs cycles monde/menu,
- fuite ressources GPU,
- freeze main thread.

Apple Instruments recommande explicitement de déplacer le travail nécessaire mais coûteux hors du main thread pour éviter les blocages d’interaction.  
Source : [Apple Instruments — Executing work asynchronously](https://developer.apple.com/tutorials/instruments/executing-work-asynchronously)

---

## 30. Liste longue de modules/outils à prévoir dans le hub

### 30.1 World / Seed

- Seed Explorer
- Seed Comparator
- WorldDNA Viewer
- WorldDNA Diff Tool
- World Constitution Editor
- Rule Conflict Resolver
- World Profile Browser
- Macro World Preview
- Spawn Finder
- World Difficulty Estimator
- World Mood Analyzer
- Determinism Replay Browser
- World Snapshot Gallery
- Save/Load Inspector
- World Migration Tool

### 30.2 Terrain

- Heightfield Generator
- Terrain Noise Graph
- Erosion Simulator
- River Network Editor
- Lake/Ocean Basin Tool
- Cliff Generator
- Canyon Generator
- Mountain Range Tool
- Cave SDF Tool
- Overhang Tool
- Slope Material Tool
- Terrain Collision Preview
- Terrain Traversability Map
- Climbable Surface Tagger
- Rope Anchor Candidate Viewer
- Stair Attachment Planner
- Terrain LOD Debugger
- Terrain Material Layer Viewer
- Snowline Viewer
- Wetness Accumulation Viewer

### 30.3 Biomes

- Climate Field Editor
- Biome Rule Table
- Biome Graph Editor
- Sub-biome Library
- Ecotone Width Editor
- Biome Transition Preview
- Vegetation Density Map
- Soil Rule Tool
- Fauna Habitat Tool
- Weather Bias Tool
- Biome Audio Ambience Tool
- Biome Color Palette Tool
- Biome Material Set Editor
- Biome Prop Scatter Tool

### 30.4 Props

- Prop Recipe Editor
- Prop Variant Gallery
- Tree Generator
- Rock Generator
- Plant Generator
- Object Generator
- Furniture Generator
- Industrial Object Generator
- Wear/Aging Tool
- Damage State Tool
- Material Variation Tool
- Collision Proxy Tool
- LOD Chain Preview
- Instancing Batch Analyzer

### 30.5 Characters

- CharacterDNA Editor
- Body Morph Tool
- Face Generator
- Skin Material Tool
- Hair/Groom Tool
- Clothing Layer Tool
- Equipment Tool
- Injury State Tool
- Aging Preview
- Voice Parameter Tool
- Animation Set Binder
- LOD Character Viewer
- NPC Archetype Generator
- Faction Appearance Tool

### 30.6 Animation

- Motion Matching Database Browser
- Foot IK Visualizer
- Contact Solver Debugger
- Terrain Awareness Tool
- Climb Animation Tool
- Rope Interaction Tool
- Ragdoll Blend Tool
- Procedural Gesture Tool
- Animal Locomotion Tool
- Physics Reaction Preview

### 30.7 Audio

- Footstep Synth Matrix
- Material Impact Synth
- Weather Ambience Generator
- Animal Call Synth
- Wind Model Tool
- Procedural Music Composer
- Chord Progression Generator
- World Theme Browser
- Spatial Audio Debugger
- Reverb Zone Tool
- Audio LOD Profiler

### 30.8 FX

- Particle System Graph
- GPU Particle Budget Tool
- Weather FX Generator
- Impact FX Tool
- Fire/Smoke Tool
- Magic/Tech FX Tool
- Trail/Ribbon Tool
- Decal Projection Tool
- Flipbook Preview
- Overdraw Heatmap

### 30.9 Buildings / Settlements

- Building Grammar Tool
- Facade Generator
- Interior Layout Tool
- Roof Generator
- Parcel Tool
- Village Layout Tool
- Camp Tool
- Factory Layout Tool
- City District Tool
- Road Network Tool
- Terrain Adaptation Tool
- Vertical Attachment Tool
- Bridge Generator
- Settlement LOD Tool

### 30.10 Rendering

- Material Graph
- Texture Pipeline Tool
- Light Probe Tool
- Reflection Probe Tool
- Shadow Debug Tool
- Post-process Tool
- Atmosphere/Fog Tool
- Virtual Texture Viewer
- LOD/Cluster Viewer
- Renderer Capability Viewer

### 30.11 UI/HUD

- UI Theme Generator
- HUD Layout Tool
- Design Token Editor
- Gamepad UI Navigation Tool
- Accessibility Checker
- Procedural Icon Generator
- World Mood HUD Preview
- Debug Overlay Editor

### 30.12 RPG

- RPG Rules Editor
- Objective Generator
- Quest Storylet Tool
- Faction Generator
- Economy Simulator
- Reputation Matrix
- Skill Tree Generator
- Loot Rule Tool
- Myth Generator
- Culture Generator
- Encounter Director Tool
- World Ending Browser

---

## 31. Roadmap d’implémentation

### Phase 0 — Nettoyage base

- Identifier où sont actuellement App, renderer, world generation.
- S’assurer que `EngineCore` reste indépendant de SwiftUI.
- Ajouter `AppShell` minimal.
- Ajouter `AppMode` state machine.

### Phase 1 — Main menu

- Créer `MainMenuView`.
- Trois boutons : Debug, Generate World, Tools.
- Afficher build/GPU/renderer status.
- Ajouter seed text field simple.
- Ajouter navigation stable.

### Phase 2 — Loading générique

- Créer `LoadingView`.
- Créer `LoadingProgress`.
- Créer `WorldPreparePipeline` mock.
- Support annulation.
- Support erreur récupérable.

### Phase 3 — Debug World

- Créer `DebugWorldFeature`.
- Layout viewport gauche + sidebar droite.
- Charger un mini monde test.
- Ajouter toolbar retour menu.
- Ajouter premiers panneaux : stats, terrain, chunks.

### Phase 4 — Real World Generation

- Brancher seed/options réels.
- Générer `WorldDNA`.
- Générer chunks initiaux.
- Préparer renderer session.
- Ouvrir monde seulement quand prêt.

### Phase 5 — Tools Hub minimal

- Créer `ToolRegistry`.
- Créer `ToolsHubView` en split 3 colonnes.
- Ajouter outils stub : Terrain, Props, Character, Audio, FX.
- Ajouter preview Metal générique.
- Ajouter persistence des tool docs.

### Phase 6 — Diagnostics

- Logs visibles.
- Export diagnostics.
- Frame stats.
- Generation timeline.
- Memory/resource leak checks.

### Phase 7 — Production polish

- Layouts sauvegardés.
- Command palette.
- Recent seeds.
- Presets monde.
- World preview macro.
- Thumbnails.
- Multi-window tools optionnel.
- Replay/capture déterministe.

---

## 32. Checklist de qualité

### Menu

- [ ] ouvre sans charger de monde
- [ ] trois choix principaux visibles
- [ ] seed récent affiché
- [ ] renderer status affiché
- [ ] navigation clavier/manette minimale
- [ ] préférences accessibles

### Debug World

- [ ] monde restreint rapide
- [ ] viewport gauche
- [ ] outils droite
- [ ] retour menu fiable
- [ ] reload scénario
- [ ] panneaux modulaires
- [ ] debug draw
- [ ] capture diagnostic

### Génération World réel

- [ ] seed validé
- [ ] options validées
- [ ] phases progressives
- [ ] barre de chargement
- [ ] annulation
- [ ] erreurs récupérables
- [ ] ouverture seulement quand prêt
- [ ] session runtime nettoyable

### Tools Hub

- [ ] tool registry
- [ ] liste catégories
- [ ] workspace
- [ ] inspector
- [ ] preview
- [ ] documents sauvegardables
- [ ] validation
- [ ] export

### Architecture

- [ ] state machine explicite
- [ ] EngineCore indépendant UI
- [ ] services injectés
- [ ] async annulable
- [ ] ressources libérées
- [ ] tests state machine
- [ ] diagnostics exportables

---

## 33. Décisions finales recommandées

1. **Créer un AppShell central** avec `AppMode` explicite.
2. **SwiftUI pour menu, loading, tools, panels**.
3. **Metal/MTKView pour monde et previews 3D**.
4. **Ne pas ouvrir de monde réel sans `PreparedWorldSession` valide**.
5. **Créer un `WorldPreparePipeline` progressif, pondéré et annulable**.
6. **Créer un Debug World séparé du Real World**, avec scénarios et outils.
7. **Créer un Tools Hub data-driven**, alimenté par `ToolRegistry`.
8. **Garder `EngineCore` découplé**, testable sans SwiftUI.
9. **Persister documents/outils/layouts avec formats versionnés**.
10. **Ajouter diagnostics/replay dès le début**, sinon les bugs procéduraux deviendront impossibles à reproduire.

---

## 34. Sources principales

- Apple Developer Documentation — `NavigationSplitView` : https://developer.apple.com/documentation/swiftui/navigationsplitview
- Apple Developer Documentation — `ProgressView` : https://developer.apple.com/documentation/swiftui/progressview
- Apple Human Interface Guidelines — Progress indicators : https://developer.apple.com/design/human-interface-guidelines/progress-indicators
- Apple Developer Documentation — `MTKView` : https://developer.apple.com/documentation/metalkit/mtkview
- Apple Developer Documentation — SwiftData : https://developer.apple.com/documentation/swiftdata
- Apple Developer Documentation — Observation : https://developer.apple.com/documentation/observation
- Swift.org — Concurrency : https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/
- Apple Instruments Tutorial — Executing work asynchronously : https://developer.apple.com/tutorials/instruments/executing-work-asynchronously
- Point-Free — Swift Composable Architecture : https://github.com/pointfreeco/swift-composable-architecture
- Dear ImGui Wiki — Docking : https://github.com/ocornut/imgui/wiki/Docking
- IsoWorldPOC GitHub repository : https://github.com/agaloppe84/IsoWorldPOC

---

## 35. Nom de fichier recommandé

`procedural-app-flow-shell-tools-system.md`

