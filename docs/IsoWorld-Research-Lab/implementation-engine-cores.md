# IsoWorld — implementation-engine-cores

**Type :** document de synthèse et de pilotage d’implémentation  
**But :** donner à Codex un plan d’action global, ordonné, dépendancé et exploitable pour implémenter les systèmes centraux d’IsoWorld à partir des documents de référence `.md`.  
**Cible actuelle :** moteur procédural custom en Swift/Metal sur macOS, Apple Silicon, monde déterministe généré par chunks autour du joueur.  
**Priorités ajoutées :** corriger les problèmes de performances du mode debug rendu à 60 Hz, puis mettre à jour proprement le projet Xcode/Swift avant d’empiler les systèmes ambitieux.

---

## 0. Documents de référence utilisés

Ce document ne remplace pas les documents détaillés. Il les organise dans un ordre d’implémentation cohérent.

| Domaine | Document de référence |
|---|---|
| Rendu procédural moderne | `procedural-modern-rendering.md` |
| Props procéduraux / paramétriques | `procedural-parametric-props-system.md` |
| Animations procédurales / physique | `procedural-physics-driven-animation-system.md` |
| Terrain procédural versatile | `procedural-versatile-terrain-generation.md` |
| Biomes et transitions | `procedural-biome-transition-system.md` |
| RPG procédural déterministe | `procedural-deterministic-rpg-system.md` |
| Textures / lumières sans ray tracing | `modern-texture-lighting-pipeline.md` |
| LOD / Nanite-inspired | `nanite-inspired-lod-system.md` |
| Particules / FX | `procedural-parametric-particles-fx-pipeline.md` |
| UI / HUD procédural | `procedural-parametric-ui-hud-system.md` |
| Audio procédural / paramétrique | `procedural-parametric-audio-engine.md` |
| Bâtiments / villages / villes | `procedural-parametric-buildings-settlements-system.md` |
| Personnages procéduraux / paramétriques | `procedural-parametric-character-system.md` |
| Flux app / menu / debug world / tools hub | `procedural-app-flow-shell-tools-system.md` |
| Sauvegardes jeu et outils | `procedural-save-system.md` |

---

## 1. Résumé exécutif

IsoWorld ne doit pas être implémenté système par système dans l’ordre des idées créatives. Le bon ordre est celui des **dépendances moteur** : build stable, boucle de frame maîtrisée, profiling, contrats de données, déterminisme, chunks, terrain, biomes, rendu de base, LOD, persistance, puis les systèmes de gameplay, d’assets et d’outils.

La priorité absolue est donc :

1. **Stabiliser le projet Xcode/Swift/Metal** après mise à jour macOS/Xcode.
2. **Corriger le coût du mode debug rendu à 60 Hz** avant d’ajouter de nouveaux systèmes.
3. **Créer un App Shell clair** : menu principal, debug world, génération de monde réel avec loading, hub d’outils.
4. **Séparer strictement EngineCore, renderer, UI et tools**.
5. **Mettre en place les fondations déterministes** : seed, RNG stable, IDs stables, `WorldDNA`, `GenerationContext`, versions de générateurs.
6. **Mettre en place le socle runtime** : job system, resource registry, frame snapshots, profiling, debug overlays, save minimal.
7. **Implémenter terrain + biomes + matériaux comme base de tout le reste**.
8. **Ajouter props + LOD + instancing** pour donner une densité visuelle sans exploser le CPU/GPU.
9. **Ajouter personnages, animation, FX, audio et UI procédurale** sur des snapshots de gameplay propres.
10. **Ajouter RPG, settlements, outils avancés et systèmes profonds** une fois les contrats fondamentaux stables.

La règle centrale : **chaque système doit produire des données inspectables, versionnées, déterministes et testables avant d’être rendu beau**.

---

## 2. État de départ supposé du repo

D’après le README du repo et les documents existants, IsoWorldPOC est actuellement :

- une app macOS SwiftUI ;
- un POC de monde procédural 3D ;
- avec objectif de vue isométrique/orbitale ;
- terrain vertical ;
- génération par chunks autour du joueur ;
- support manette PS5 via GameController ;
- architecture découplée/testable ;
- présence d’un `EngineCore` ;
- présence de Metal dans le repo ;
- build recommandé via `./scripts/xcodebuild-safe.sh` pour éviter de modifier globalement l’environnement Xcode.

Conséquence : le plan ci-dessous suppose qu’on ne repart pas de zéro. On consolide d’abord la base, puis on remplace les parties ad hoc par des systèmes nommés, testables et versionnés.

---

## 3. Principes non négociables

### 3.1 EngineCore ne dépend pas de SwiftUI

`EngineCore` doit rester pur, testable, sans import SwiftUI/AppKit/Metal si possible. Les dépendances vers Metal doivent passer par des payloads ou snapshots neutres.

À viser :

```text
SwiftUI/AppKit Shell
  -> EngineCoreFacade
      -> EngineCore Systems
  -> MetalRenderer
      -> RenderPayloads produits par EngineCore
```

À éviter :

```text
SwiftUI View appelle directement TerrainGenerator puis manipule des buffers Metal.
```

### 3.2 Le seed ne doit jamais dépendre de l’ordre de chargement

Tout résultat procédural doit dépendre de :

```text
worldSeed + domain + coordinate + recipeVersion + stableID
```

Jamais de :

```text
nombre d’appels RNG déjà consommés dans cette session
ordre d’arrivée des chunks
framerate
thread scheduling
état de l’UI
```

### 3.3 Les systèmes doivent être debuggables avant d’être beaux

Chaque système doit avoir :

- debug overlay ;
- stats CPU/GPU/mémoire ;
- seed de test ;
- snapshot exportable ;
- validation report ;
- tests de déterminisme ;
- budget explicite.

### 3.4 Les caches ne sont pas la source de vérité

La source de vérité est :

- seed ;
- `WorldDNA` ;
- versions de générateurs ;
- recettes ;
- deltas persistés ;
- décisions du joueur ;
- état RPG.

Les meshes générés, previews, HLOD, light probes, textures dérivées, buffers et thumbnails sont des caches rebuildables.

### 3.5 Le debug ne doit pas coûter comme le jeu final

Le mode debug doit pouvoir observer le moteur, pas l’étouffer. S’il rend à 60 Hz sans nécessité, il fausse toutes les mesures et rend les optimisations impossibles.

---

## 4. Problème prioritaire : mode debug rendu à 60 Hz

### 4.1 Diagnostic probable

Le mode debug actuel semble coûteux notamment parce que :

- le viewport debug est rendu à 60 Hz même quand rien ne bouge ;
- les panels SwiftUI peuvent provoquer des recalculs fréquents ;
- les snapshots moteur peuvent être produits trop souvent ;
- les overlays debug peuvent forcer des allocations ou conversions par frame ;
- le rendu debug et la simulation semblent probablement trop couplés ;
- les métriques peuvent être collectées à chaque frame au lieu d’être agrégées ;
- le monde debug charge peut-être trop de systèmes par défaut.

### 4.2 Objectif de correction

Créer un **Debug Runtime Throttling Layer**.

Le mode debug doit avoir plusieurs cadences :

| Sous-système | Cadence recommandée |
|---|---:|
| Simulation jouable active | 30 à 60 Hz selon mode |
| Viewport debug statique | rendu à la demande |
| Viewport debug inspecteur | 5 à 15 Hz |
| Graphes de stats | 2 à 10 Hz |
| Logs | événementiel |
| Panels SwiftUI | sur changement d’état |
| Snapshots lourds | 1 à 5 Hz ou manuel |
| Validation batch | hors frame, job async |
| Mini-previews outils | à la demande ou 15/30 Hz selon interaction |

### 4.3 Actions immédiates

#### Action P0.1 — Séparer `DebugWorldMode` et `PlayDebugMode`

Créer deux modes :

```swift
enum DebugWorldRunMode {
    case pausedInspection       // rendu à la demande
    case slowInspection         // 5-15 Hz
    case liveGameplay           // 30/60 Hz
    case benchmark              // cadence forcée, aucun panel lourd
}
```

Le mode par défaut doit être `pausedInspection` ou `slowInspection`, pas `liveGameplay`.

#### Action P0.2 — Contrôler explicitement la cadence du viewport

Pour une vue Metal, prévoir une politique :

```swift
struct RenderCadencePolicy {
    var mode: RenderCadenceMode
    var maxFPS: Int
    var renderOnlyWhenDirty: Bool
    var allowContinuousAnimation: Bool
}

enum RenderCadenceMode {
    case onDemand
    case throttled(fps: Int)
    case displayLinked
    case benchmarkFixedStep
}
```

Règles :

- menu principal : aucun monde chargé, aucun rendu 60 Hz ;
- loading : pas de renderer monde actif ;
- debug paused : `draw()` seulement quand caméra, outil, sélection, chunk ou overlay change ;
- debug slow : timer bas débit ;
- debug live : 60 Hz uniquement sur demande ;
- benchmark : panels désactivés, métriques agrégées.

#### Action P0.3 — Créer un `DebugSnapshotCache`

Les panels ne doivent pas lire directement l’état moteur vivant à chaque refresh SwiftUI.

```swift
actor DebugSnapshotCache {
    private var latest: EngineDebugSnapshot?

    func publish(_ snapshot: EngineDebugSnapshot) { ... }
    func readLatest() -> EngineDebugSnapshot? { ... }
}
```

Le moteur publie des snapshots à cadence contrôlée. SwiftUI lit le dernier snapshot disponible.

#### Action P0.4 — Découpler overlay debug et renderer principal

Chaque overlay doit déclarer son coût :

```swift
enum DebugOverlayCost {
    case cheapPerFrame
    case moderateThrottled
    case expensiveManual
}
```

Exemples :

- bounds de chunk : cheap ;
- heatmap matériaux : moderate ;
- validation complète des biomes : expensive manual ;
- affichage de tous les IDs de props : expensive manual ;
- raycasts de contact pied : moderate, seulement quand personnage visible.

#### Action P0.5 — Ajouter un HUD de perf minimal avant tout nouveau système

À afficher :

- CPU frame time ;
- GPU frame time si disponible ;
- simulation time ;
- generation jobs time ;
- render encoding time ;
- nombre de chunks actifs ;
- draw calls ;
- triangles ;
- instances ;
- buffers uploadés ;
- textures résidentes ;
- mémoire estimée ;
- cadence réelle viewport ;
- mode cadence actuel.

### 4.4 Definition of Done du fix perf/debug

Le chantier est terminé quand :

- le menu principal ne rend pas de monde ;
- le debug world peut rester ouvert immobile sans consommer une frame 60 Hz continue ;
- on peut basculer entre `pausedInspection`, `slowInspection`, `liveGameplay`, `benchmark` ;
- les panels ne déclenchent pas de génération de chunks ;
- les stats sont lisibles mais throttled ;
- un benchmark peut être lancé sans UI lourde ;
- Codex peut lancer une commande de build + tests sans dépendance à un état global Xcode.

---

## 5. Mise à jour Xcode / Swift / projet

### 5.1 Objectif

Le projet a été créé avec une ancienne version de Xcode. Après mise à jour macOS/Xcode/Swift, il faut migrer proprement sans mélanger migration IDE et refactor moteur.

Règle : **faire une branche dédiée uniquement à la migration toolchain**.

Nom conseillé :

```text
chore/update-xcode-toolchain
```

### 5.2 Commandes de diagnostic à lancer avant modification

À exécuter à la racine du repo :

```bash
xcodebuild -version
swift --version
xcode-select -p
xcrun --find swift
xcrun --find metal
./scripts/xcodebuild-safe.sh -project IsoWorldPOC/IsoWorldPOC.xcodeproj -scheme IsoWorldPOC -destination 'platform=macOS' build
```

Conserver la sortie dans un fichier de diagnostic :

```bash
mkdir -p diagnostics/toolchain
{
  date
  xcodebuild -version
  swift --version
  xcode-select -p
  xcrun --find swift
  xcrun --find metal
} > diagnostics/toolchain/xcode-swift-before.txt
```

### 5.3 Garder le wrapper `xcodebuild-safe.sh`

Le README indique que le projet doit être compilé via :

```bash
./scripts/xcodebuild-safe.sh -project IsoWorldPOC/IsoWorldPOC.xcodeproj -scheme IsoWorldPOC -destination 'platform=macOS' build
```

Il faut conserver cette discipline. Le wrapper évite de modifier globalement l’environnement Xcode.

À faire :

- vérifier que le wrapper pointe vers le bon Xcode ;
- ne pas imposer `sudo xcode-select -s ...` dans les scripts du repo ;
- documenter comment override localement `DEVELOPER_DIR` si besoin ;
- ajouter un `scripts/doctor.sh` qui affiche les versions sans modifier la machine.

### 5.4 Ouvrir dans Xcode et accepter les migrations recommandées

Procédure :

1. Créer un commit propre avant ouverture Xcode.
2. Ouvrir `IsoWorldPOC.xcodeproj` dans la nouvelle version de Xcode.
3. Laisser Xcode proposer les “recommended settings”.
4. Lire les changements avant acceptation.
5. Accepter uniquement les migrations cohérentes.
6. Rebuild.
7. Commit séparé : `chore: update Xcode project recommended settings`.

### 5.5 Réglages projet à vérifier

Dans le projet Xcode :

| Réglage | Recommandation |
|---|---|
| Project format | Mettre au format recommandé par la version actuelle de Xcode |
| Base SDK | Latest macOS SDK |
| macOS deployment target | Décider explicitement : compatibilité large ou moteur local dernière version |
| Swift Language Version | Dernière version stable disponible dans Xcode, probablement Swift 6.x |
| Strict Concurrency Checking | Commencer par `Targeted` ou équivalent, passer à `Complete` plus tard |
| Warnings | Garder strict mais ne pas bloquer toute migration sur un seul PR |
| Metal language version | Latest compatible, avec fallback si nécessaire |
| Dead code stripping | Activé en Release |
| Optimization Level | Debug non optimisé, Release optimisé |
| Build settings custom | Réduire au minimum documenté |

### 5.6 Stratégie Swift Concurrency

Ne pas activer brutalement le mode le plus strict partout si le projet n’est pas prêt.

Ordre recommandé :

1. Identifier les états globaux non isolés.
2. Mettre `EngineCore` en APIs synchrones pures quand possible.
3. Utiliser des `actor` pour services async : jobs, snapshots, saves, asset cache.
4. Éviter de mettre toute la simulation sur `MainActor`.
5. Introduire des snapshots immutables entre simulation et UI.
6. Activer progressivement les warnings de concurrence.
7. Ajouter tests de non-régression.

### 5.7 Ce qu’il ne faut pas faire pendant la migration

Ne pas faire dans le même PR :

- migration Xcode ;
- refonte renderer ;
- refactor terrain ;
- nouveau système de save ;
- passage Swift Concurrency complet ;
- changement de structure de repo ;
- remplacement massif RealityKit/Metal si encore présent.

La migration doit être vérifiable seule.

### 5.8 Definition of Done migration toolchain

- build Debug OK via wrapper ;
- build Release OK via wrapper ;
- tests OK ;
- warnings critiques listés ;
- `diagnostics/toolchain/xcode-swift-after.txt` généré ;
- Xcode project diff relu ;
- README mis à jour si la commande de build change ;
- aucun nouveau système moteur ajouté dans ce PR.

---

## 6. Architecture cible globale

### 6.1 Découpage haut niveau

```text
IsoWorldPOC/
  AppShell/                 # SwiftUI/AppKit shell
  MetalRenderer/            # rendu Metal, frame graph, GPU resources
  GameRuntime/              # orchestration runtime app + engine sessions
  ToolingUI/                # outils procéduraux SwiftUI

EngineCore/
  Foundation/               # RNG, IDs, math, coordinates, versions
  Diagnostics/              # stats, logs, profiling, snapshots
  Jobs/                     # job system, priorities, cancellation
  World/                    # WorldDNA, WorldState, chunks, regions
  Terrain/                  # TerrainSystem
  Biomes/                   # BiomeSystem
  Materials/                # material runtime neutral data
  Props/                    # PropSystem
  LOD/                      # LOD policies + selection
  VirtualGeometry/          # futur IVDS
  Characters/               # CharacterDNA, skeleton neutral data
  Animation/                # motion, IK, contact data
  FX/                       # FX definitions/events/context
  Audio/                    # audio events/recipes/context
  RPG/                      # WorldRPGDNA, rulesets, quests
  Settlements/              # buildings/villages/cities
  Persistence/              # save/tools formats
  UIModel/                  # UI/HUD snapshots/tokens neutral data

Docs/
  reference/                # documents détaillés déjà produits
  implementation-engine-cores.md
```

### 6.2 Contrats de données à créer tôt

Ces types doivent exister rapidement, même minimalistes :

```swift
struct WorldSeed: Hashable, Codable { ... }
struct SeedDomain: Hashable, Codable { ... }
struct StableID: Hashable, Codable { ... }
struct GeneratorVersion: Hashable, Codable { ... }
struct WorldDNA: Codable { ... }
struct GenerationContext { ... }
struct ChunkID: Hashable, Codable { ... }
struct ChunkCoord: Hashable, Codable { ... }
struct RegionCoord: Hashable, Codable { ... }
struct EngineFrameSnapshot: Sendable { ... }
struct RenderWorldSnapshot: Sendable { ... }
struct DebugSnapshot: Sendable { ... }
```

### 6.3 Contrats chunk

Un chunk ne doit pas être seulement un mesh. Il doit devenir un paquet de données multi-domaines :

```swift
struct WorldChunkData {
    let id: ChunkID
    let coord: ChunkCoord
    let terrain: TerrainChunkData
    let biomes: BiomeChunkData
    let surfaces: SurfaceChunkData
    let props: PropChunkData
    let traversal: TraversalChunkData
    let collision: CollisionChunkData
    let render: ChunkRenderPayload
    let validation: ChunkValidationReport
}
```

### 6.4 Pipeline chunk recommandé

```text
WorldSeed + WorldDNA
  -> Global fields bas coût
  -> Terrain fields
  -> Terrain feature graph
  -> Hydrology
  -> Biome weights
  -> Surface/material weights
  -> Traversal/collision candidates
  -> Prop placement candidates
  -> Render payloads
  -> LOD/culling metadata
  -> Persistence dirty tracking
```

---

## 7. Ordre global recommandé

### 7.1 Vue d’ensemble

| Ordre | Step | Pourquoi maintenant | Dépend de |
|---:|---|---|---|
| 0 | Toolchain Xcode/Swift + build stable | Toute implémentation dépend d’un build fiable | rien |
| 1 | Perf debug 60 Hz + profiling | Sans métriques fiables, chaque ajout empire le moteur | 0 |
| 2 | AppShell + state machine + menu | Structure l’usage : debug, world réel, tools | 0-1 |
| 3 | EngineCore Foundation | Déterminisme, IDs, snapshots, jobs | 0-2 |
| 4 | Save minimal + manifests | Seeds, versions, slots, tool docs futurs | 3 |
| 5 | Renderer baseline + frame graph minimal | Rendu contrôlé, debug, payloads | 1-3 |
| 6 | Terrain fields propres | Base de monde, collision, biomes, props | 3-5 |
| 7 | Biome fields minimalistes | Matériaux, props, RPG, météo | 6 |
| 8 | Materials/PBR terrain layered V1 | Qualité visuelle et surface data | 5-7 |
| 9 | LOD baseline + culling + instancing | Corrige coût avant densité props | 5-8 |
| 10 | Props naturels simples | Densité monde visible | 6-9 |
| 11 | Tools Hub minimal | Authoring et debug des systèmes | 2-4, 6-10 |
| 12 | World generation loading réel | Prépare WorldDNA + chunks initiaux | 2-10 |
| 13 | Terrain hydrologie + verticalité V1 | Gameplay d’exploration et traversal | 6-10 |
| 14 | Character base + customization minimal | Joueur/PNJ, corps, équipement | 4-9 |
| 15 | Animation contact terrain V1 | Pieds, sol, collisions fines | 6-8, 14 |
| 16 | FX V1 data-driven | Footsteps, impacts, weather visuel | 8, 10, 15 |
| 17 | Audio V1 data-driven | Footsteps, ambiances, musique légère | 8, 15 |
| 18 | UI/HUD procedural V1 | Snapshots gameplay et thème monde | 2-5, 7, 14 |
| 19 | RPG DNA V1 | Règles de monde, objectifs, factions | 3-4, 7, 10 |
| 20 | Buildings/settlements V1 | Villages/camps adaptés terrain | 6-10, 19 |
| 21 | Save avancée chunks/entities/tools | Persister monde vivant et outils | 4, 10, 14, 19-20 |
| 22 | Lighting avancé + probes + weather surfaces | Qualité monde | 8, 13, 16 |
| 23 | LOD/IVDS avancé | Densité AAA scalable | 9, 10, 20, 22 |
| 24 | Systems avancés : animation, audio, FX, RPG | Profondeur et polish | 13-23 |
| 25 | Production tools + validation batch | Qualité, régression, galerie seeds | tous |

### 7.2 Ce qu’il faut absolument éviter

Ne pas implémenter :

- les villes avant le terrain + props + LOD ;
- les animations de contact avancées avant les matériaux de sol + collision terrain ;
- l’audio procédural de pas avant les événements d’animation/contact ;
- le HUD procédural complet avant les snapshots gameplay ;
- le RPG profond avant `WorldRPGDNA` + persistence ;
- les meshlets/IVDS avant un LOD baseline ;
- les virtual textures avant un PBR/layering robuste ;
- les outils avancés avant un `ToolRegistry` et une persistence de projet.

---

## 8. Plan d’implémentation détaillé

# Phase A — Stabilisation technique immédiate

## Step 0 — Migration toolchain Xcode/Swift

**But :** rendre le projet fiable avec la dernière version officielle installée localement.

**Livrables :**

- `scripts/doctor.sh` ;
- `diagnostics/toolchain/xcode-swift-before.txt` ;
- `diagnostics/toolchain/xcode-swift-after.txt` ;
- README build mis à jour si nécessaire ;
- commit dédié aux “recommended settings” Xcode ;
- build Debug/Release OK ;
- tests OK.

**Dépendances :** aucune.

**Détails :** voir section 5.

---

## Step 1 — Perf baseline et correction du debug 60 Hz

**But :** rendre les mesures fiables et supprimer le coût debug inutile.

**Livrables :**

```text
EngineCore/Diagnostics/
  EngineStats.swift
  FrameTiming.swift
  DebugSnapshot.swift
  PerformanceBudget.swift

GameRuntime/Debug/
  DebugWorldRunMode.swift
  DebugSnapshotCache.swift
  DebugCadenceController.swift

MetalRenderer/Diagnostics/
  RendererStats.swift
  GPUMetrics.swift
```

**Actions :**

1. Ajouter `DebugWorldRunMode`.
2. Ajouter `RenderCadencePolicy`.
3. Désactiver le rendu continu dans menu/loading/debug paused.
4. Throttler les panels debug.
5. Ajouter un benchmark mode sans panels lourds.
6. Ajouter des métriques CPU/render/generation.
7. Ajouter un overlay minimal de stats.

**Definition of Done :**

- debug mode immobile ne rend plus à 60 Hz ;
- le mode 60 Hz existe mais doit être explicite ;
- les stats affichent la cadence réelle ;
- on peut comparer perf avant/après.

---

## Step 2 — AppShell minimal : menu, debug, generate, tools

**Référence :** `procedural-app-flow-shell-tools-system.md`

**But :** ne plus démarrer directement dans le monde. Créer un shell clair avec trois entrées.

**Livrables :**

```text
IsoWorldPOC/AppShell/
  AppMode.swift
  AppStore.swift
  AppShellView.swift
  MainMenuView.swift
  LoadingView.swift
  DebugWorldView.swift
  ToolsHubView.swift

GameRuntime/
  EngineCoreFacade.swift
  WorldSession.swift
  DebugWorldSession.swift
  ToolSession.swift
  WorldPreparePipeline.swift
```

**Modes :**

```swift
enum AppMode {
    case boot
    case mainMenu
    case debugWorld(DebugWorldSessionID)
    case preparingWorld(LoadingSessionID)
    case realWorld(WorldSessionID)
    case toolsHub(ToolSessionID)
    case error(AppErrorState)
}
```

**Actions :**

1. Menu principal léger.
2. Bouton Debug World.
3. Bouton Generate World avec seed.
4. Bouton Tools Hub.
5. `LoadingProgress` avec phases mockées.
6. Retour menu depuis chaque mode.
7. Aucun monde rendu dans le menu.

**Dépend de :** Step 0, Step 1.

---

## Step 3 — EngineCore Foundation

**But :** créer les fondations stables pour tous les systèmes procéduraux.

**Livrables :**

```text
EngineCore/Foundation/
  StableRNG.swift
  StableHash.swift
  StableID.swift
  SeedDomain.swift
  WorldSeed.swift
  GeneratorVersion.swift
  EngineVersion.swift
  ChunkCoord.swift
  RegionCoord.swift
  WorldCoordinate.swift
  DeterminismTests.swift
```

**Types prioritaires :**

```swift
struct GenerationContext {
    let worldSeed: WorldSeed
    let worldDNA: WorldDNA
    let generatorVersions: GeneratorVersionTable
    let domain: SeedDomain
}

struct WorldDNA: Codable, Hashable {
    var terrain: WorldTerrainDNA
    var biomes: WorldBiomeDNA
    var render: WorldRenderDNA
    var rpg: WorldRPGDNA
    var style: WorldStyleGenome
}
```

**Actions :**

1. Remplacer tout RNG ad hoc par `StableRNG`.
2. Créer un test : même seed + même coord = même résultat.
3. Créer des golden seeds : plaine, montagne, rivière, désert, forêt dense, transition biome, hauteur extrême.
4. Ajouter versions de générateurs.
5. Ajouter `StableID` pour chunks, props, entités persistantes.

**Dépend de :** Step 0.

---

## Step 4 — Job system minimal + snapshots

**But :** organiser génération, loading, previews outils et debug sans bloquer le main thread.

**Livrables :**

```text
EngineCore/Jobs/
  EngineJob.swift
  JobPriority.swift
  JobHandle.swift
  JobScheduler.swift
  CancellationToken.swift

EngineCore/Snapshots/
  EngineFrameSnapshot.swift
  RenderWorldSnapshot.swift
  ToolPreviewSnapshot.swift
  DebugSnapshot.swift
```

**Règles :**

- UI sur MainActor ;
- génération chunk en jobs cancellables ;
- renderer lit des snapshots immutables ;
- tools peuvent lancer des previews isolées ;
- loading affiche progression réelle.

**Dépend de :** Step 2, Step 3.

---

## Step 5 — Save minimal : seed, profil, slots, manifests

**Référence :** `procedural-save-system.md`

**But :** persister le minimum avant d’accumuler des systèmes.

**Livrables :**

```text
EngineCore/Persistence/
  SaveSlotManager.swift
  SaveManifest.swift
  AtomicFileWriter.swift
  SaveVersion.swift
  GeneratorVersionTable.swift
  PlayerProfile.swift
```

**À persister V1 :**

- profil joueur ;
- liste des seeds récentes ;
- save slot ;
- manifest JSON ;
- seed ;
- `WorldDNA` ;
- versions de générateurs ;
- position joueur minimale ;
- préférences debug/app.

**À ne pas persister V1 :**

- chunks non modifiés ;
- meshes générés ;
- light probes ;
- thumbnails ;
- buffers GPU.

**Dépend de :** Step 3.

---

# Phase B — Rendu et monde de base

## Step 6 — Renderer baseline + FrameGraph simple

**Références :** `procedural-modern-rendering.md`, `modern-texture-lighting-pipeline.md`

**But :** avoir un renderer stable, instrumenté, extensible, sans sur-architecture.

**Livrables :**

```text
MetalRenderer/Core/
  MetalRenderer.swift
  RenderFrameContext.swift
  FrameGraph.swift
  RenderPass.swift
  GPUResourceRegistry.swift
  RenderPayloadUploader.swift

MetalRenderer/Passes/
  DepthPrepass.swift
  OpaquePass.swift
  DebugOverlayPass.swift
  HUDOverlayPass.swift
```

**Fonctions V1 :**

- clear + camera ;
- terrain simple ;
- un material PBR minimal ;
- une directional light ;
- stats draw calls ;
- debug bounds chunks ;
- upload buffers contrôlé.

**Dépend de :** Step 1, Step 3, Step 4.

---

## Step 7 — Terrain fields propres

**Référence :** `procedural-versatile-terrain-generation.md`

**But :** remplacer les décisions terrain ad hoc par des fields inspectables.

**Livrables :**

```text
EngineCore/Terrain/
  TerrainSystem.swift
  TerrainSample.swift
  TerrainSampleGrid.swift
  TerrainFieldProvider.swift
  TerrainChunkGenerator.swift
  TerrainDebugLayers.swift
  TerrainValidationReport.swift
```

**`TerrainSample` V1 :**

```swift
struct TerrainSample {
    var height: Float
    var normal: SIMD3<Float>
    var slope: Float
    var curvature: Float
    var roughness: Float
    var moisture: Float
    var temperature: Float
    var materialWeights: MaterialWeights
    var walkability: Float
    var climbability: Float
}
```

**Actions :**

1. Sampling world-space déterministe.
2. Height/slope/normal/curvature.
3. Seams robustes entre chunks.
4. Debug layers.
5. Matériaux par slope/height placeholder.
6. Tests golden seeds.

**Dépend de :** Step 3, Step 6.

---

## Step 8 — Biome fields minimalistes

**Référence :** `procedural-biome-transition-system.md`

**But :** obtenir des transitions naturelles dès le début, même avec peu de biomes.

**Livrables :**

```text
EngineCore/Biomes/
  BiomeSystem.swift
  ClimateSample.swift
  BiomeDefinition.swift
  BiomeWeights.swift
  SubBiomeDefinition.swift
  EcotoneRule.swift
  BiomeChunkData.swift
```

**V1 :**

- température ;
- humidité ;
- altitude ;
- continentalité simple ;
- distance eau placeholder ;
- top-2 biome weights ;
- 8 biomes initiaux ;
- debug overlay.

**8 biomes initiaux recommandés :**

1. forêt tempérée ;
2. prairie ;
3. désert ;
4. montagne ;
5. marais ;
6. taïga ;
7. côte ;
8. eau douce.

**Dépend de :** Step 7.

---

## Step 9 — Matériaux/PBR terrain V1

**Référence :** `modern-texture-lighting-pipeline.md`

**But :** créer une base visuelle crédible sans ray tracing/path tracing.

**Livrables :**

```text
EngineCore/Materials/
  MaterialID.swift
  IsoMaterialRuntime.swift
  MaterialParameterBlock.swift
  SurfaceDescriptor.swift
  SurfaceState.swift

MetalRenderer/Materials/
  PBRShader.metal
  TerrainLayeredShader.metal
  MaterialBindingTable.swift
```

**V1 :**

- `OpaquePBR` ;
- baseColor/normal/ORM ;
- directional light ;
- IBL sky simple ;
- tone mapping ;
- debug views baseColor/roughness/normal ;
- terrain slope/height/biome blending ;
- triplanar sur falaises.

**Dépend de :** Step 6, Step 7, Step 8.

---

## Step 10 — LOD baseline + culling + instancing

**Référence :** `nanite-inspired-lod-system.md`

**But :** sécuriser les performances avant d’ajouter props, forêt, bâtiments et foule.

**Livrables :**

```text
EngineCore/LOD/
  LODPolicy.swift
  LODSelection.swift
  ScreenError.swift
  Hysteresis.swift
  LODBudget.swift

MetalRenderer/GPUDriven/
  InstanceBuffer.swift
  InstanceCulling.swift
  IndirectDrawSupport.swift
```

**V1 :**

- LOD distance/screen size ;
- hysteresis ;
- chunk culling CPU ;
- instancing par archetype ;
- collision LOD séparée ;
- debug overlay ;
- budget de draw calls.

**À ne pas faire encore :** meshlets complets, virtual geometry, visibility buffer.

**Dépend de :** Step 6, Step 9.

---

## Step 11 — Props naturels simples

**Référence :** `procedural-parametric-props-system.md`

**But :** obtenir de la densité visuelle et tester le pipeline terrain/biome/material/LOD.

**Livrables :**

```text
EngineCore/Props/
  PropSystem.swift
  PropCatalog.swift
  PropRecipe.swift
  PropContext.swift
  PropPlacementRule.swift
  PropVariantGenome.swift
  PropChunkData.swift
```

**V1 :**

- rochers ;
- cailloux ;
- herbes/cards ;
- arbres simples ;
- bois mort ;
- placement par biome/slope/moisture ;
- IDs stables ;
- instancing ;
- LOD distance ;
- debug placement.

**Dépend de :** Step 7, Step 8, Step 9, Step 10.

---

## Step 12 — WorldPreparePipeline réel

**Référence :** `procedural-app-flow-shell-tools-system.md`

**But :** le bouton “Generate World” doit faire un vrai préchargement utile avant d’ouvrir le monde.

**Livrables :**

```text
GameRuntime/WorldPrepare/
  WorldPreparePipeline.swift
  WorldPreparePhase.swift
  LoadingProgress.swift
  WorldOpenRequirements.swift
```

**Phases recommandées :**

```text
1. Validate seed/options
2. Generate WorldDNA
3. Initialize world rules
4. Prepare terrain global fields
5. Prepare biome fields
6. Generate initial chunks around spawn
7. Build render payloads
8. Build collision/traversal minimal
9. Warm renderer resources
10. Open WorldSession
```

**Definition of Done :**

- barre de chargement par phases ;
- annulation possible ;
- erreur récupérable ;
- le monde ne s’ouvre pas avant les chunks initiaux ;
- le menu ne rend pas en arrière-plan.

**Dépend de :** Step 2 à Step 11.

---

# Phase C — Tools, verticalité et systèmes gameplay basiques

## Step 13 — Tools Hub minimal

**Référence :** `procedural-app-flow-shell-tools-system.md`

**But :** permettre de tester les générateurs sans ouvrir un monde complet.

**Livrables :**

```text
ToolingUI/
  ToolRegistry.swift
  ToolDescriptor.swift
  ToolDocument.swift
  ToolsHubView.swift
  ToolPreviewView.swift
  ToolValidationPanel.swift
```

**Outils stub initiaux :**

- Terrain Viewer ;
- Biome Viewer ;
- Prop Gallery ;
- Material Viewer ;
- LOD Debugger ;
- Seed Explorer.

**Dépend de :** Step 2, Step 5, Step 7-11.

---

## Step 14 — Terrain FeatureGraph + hydrologie V1

**Référence :** `procedural-versatile-terrain-generation.md`

**But :** passer d’un terrain bruité à un terrain structuré.

**Livrables :**

```text
EngineCore/Terrain/Features/
  TerrainFeatureGraph.swift
  TerrainFeature.swift
  RiverFeature.swift
  LakeFeature.swift
  MountainRangeFeature.swift
  CliffBandFeature.swift
```

**V1 :**

- mountain ranges ;
- rivières simples continues ;
- lacs simples ;
- bandes de falaises ;
- query par chunk ;
- carving basique ;
- water masks ;
- shore materials.

**Dépend de :** Step 7-9.

---

## Step 15 — Verticalité gameplay V1

**Références :** `procedural-versatile-terrain-generation.md`, `procedural-physics-driven-animation-system.md`

**But :** rendre la verticalité lisible par le gameplay avant d’ajouter escalade complète.

**Livrables :**

```text
EngineCore/Traversal/
  TraversalSurfaceClass.swift
  TraversalChunkData.swift
  ClimbabilityMap.swift
  VerticalTraversalCandidate.swift
  RopeAnchorCandidate.swift
  StairAttachCandidate.swift
  LedgeCandidate.swift
```

**V1 :**

- classification pente/paroi ;
- `walkable`, `steep`, `climbable`, `dangerous`, `blocked` ;
- candidats corde ;
- candidats escalier attaché ;
- candidats corniche ;
- debug overlay.

**Dépend de :** Step 14, Step 10.

---

## Step 16 — Character base procédural minimal

**Référence :** `procedural-parametric-character-system.md`

**But :** avoir un personnage joueur humanoïde paramétrique, même simple, qui peut porter des équipements et servir aux animations.

**Livrables :**

```text
EngineCore/Characters/
  CharacterDNA.swift
  CharacterBodyParameters.swift
  CharacterAppearance.swift
  EquipmentSlot.swift
  WearableItem.swift
  CharacterRuntimeState.swift
  CharacterCustomizationSave.swift
```

**V1 :**

- squelette humanoïde canonique ;
- skinned mesh simple ;
- sliders taille/corpulence/visage simples ;
- vêtements modulaires simples ;
- sockets armes/outils ;
- PBR peau/vêtement ;
- LOD simple ;
- sauvegarde customisation.

**Dépend de :** Step 5, Step 9, Step 10.

---

## Step 17 — Animation base + contact terrain fin V1

**Référence :** `procedural-physics-driven-animation-system.md`

**But :** adapter le personnage au terrain, aux matériaux, aux petits obstacles.

**Livrables :**

```text
EngineCore/Animation/
  Skeleton.swift
  Pose.swift
  AnimationClip.swift
  AnimationSampler.swift
  CharacterMotor.swift
  ContactPatch.swift
  FootIKSolver.swift
  FootstepEvent.swift
  SurfaceContactResolver.swift
```

**V1 :**

- sampler clip ;
- blend simple ;
- character motor capsule ;
- terrain height/normal query ;
- foot IK simple ;
- footstep events ;
- matériau/friction/wetness ;
- foot locking ;
- pelvis compensation ;
- small obstacle avoidance ;
- slope warping minimal.

**Dépend de :** Step 7-9, Step 15, Step 16.

---

## Step 18 — FX V1 data-driven

**Référence :** `procedural-parametric-particles-fx-pipeline.md`

**But :** relier terrain/matériaux/animation à des effets visibles.

**Livrables :**

```text
EngineCore/FX/
  FXDefinition.swift
  FXEvent.swift
  FXContext.swift
  FXRecipe.swift
  FXBudget.swift

MetalRenderer/FX/
  BillboardParticlePass.swift
  DecalPass.swift
```

**V1 :**

- sprites billboards ;
- burst simple ;
- color/size/lifetime over life ;
- poussière de pas ;
- splash de pas ;
- sparks d’impact ;
- decals basiques ;
- seed stable.

**Dépend de :** Step 9, Step 11, Step 17.

---

## Step 19 — Audio V1 procédural / paramétrique

**Référence :** `procedural-parametric-audio-engine.md`

**But :** créer un moteur audio minimal mais extensible, relié aux matériaux et aux événements.

**Livrables :**

```text
EngineCore/Audio/
  IsoAudioEvent.swift
  AudioContext.swift
  AudioRecipe.swift
  AudioBus.swift
  AudioParameterSet.swift
  AudioSurfaceResponse.swift

AudioRuntime/
  IsoAudioEngine.swift
  AudioEventQueue.swift
  SamplePlayer.swift
  NoiseSynth.swift
```

**V1 :**

- bus master/music/ambience/foley/world/ui ;
- event queue ;
- deterministic RNG ;
- sample player ;
- simple noise synth ;
- debug meters ;
- footstep material switching.

**Dépend de :** Step 9, Step 17.

---

## Step 20 — UI/HUD procédural minimal

**Référence :** `procedural-parametric-ui-hud-system.md`

**But :** introduire un HUD paramétrique sans remplacer tout SwiftUI.

**Livrables :**

```text
EngineCore/UIModel/
  UIFrameSnapshot.swift
  UIWorldDNA.swift
  UIToken.swift
  UITheme.swift
  HUDState.swift

MetalRenderer/UI/
  UIMetalRenderer.swift
  UIDrawCommand.swift
  UIAtlas.swift
  UILabelRenderer.swift
```

**V1 :**

- SwiftUI conservé pour menus/tools ;
- `UIFrameSnapshot` ;
- 3 thèmes : neutral, parchment, sci-fi ;
- HUD Metal minimal : label, icon, panel, progress bar ;
- snapshot health/stamina/weather/biome ;
- batching draw commands.

**Dépend de :** Step 2, Step 6, Step 8, Step 16.

---

# Phase D — Monde systémique : RPG, settlements, persistence avancée

## Step 21 — RPG DNA V1

**Référence :** `procedural-deterministic-rpg-system.md`

**But :** faire du seed une “constitution” de monde, pas seulement un générateur de terrain.

**Livrables :**

```text
EngineCore/RPG/
  WorldRPGDNA.swift
  WorldRuleset.swift
  GameplayTag.swift
  RPGArchetype.swift
  WorldObjective.swift
  FactionDefinition.swift
  QuestSeed.swift
  WorldStateLedger.swift
```

**V1 :**

- archétype de monde ;
- époque ;
- niveau tech ;
- magie/absence de magie ;
- présence menace/ennemis ;
- objectif global ;
- progression ;
- debug print du monde généré ;
- 20 seeds de test.

**Dépend de :** Step 3, Step 5, Step 8, Step 11.

---

## Step 22 — Buildings / settlements V1

**Référence :** `procedural-parametric-buildings-settlements-system.md`

**But :** générer des structures adaptées au terrain sans aplatir artificiellement le monde.

**Livrables :**

```text
EngineCore/Settlements/
  StructureRecipe.swift
  SettlementRecipe.swift
  BuildingIntent.swift
  FootprintGenerator.swift
  MassingGenerator.swift
  TerrainSupportMap.swift
  SettlementSiteSelector.swift
```

**V1 :**

- maisons simples ;
- footprints ;
- massing ;
- adaptation pente légère ;
- foundations stepped/stilts/retaining walls basiques ;
- chemins simples ;
- matériaux biome ;
- rendu instancié.

**Dépend de :** Step 7-11, Step 14, Step 21.

---

## Step 23 — Save avancée : chunks, entités, outils

**Référence :** `procedural-save-system.md`

**But :** persister le monde vivant et les projets outils.

**Livrables :**

```text
EngineCore/Persistence/
  RegionDeltaStore.swift
  EntityPersistence.swift
  DirtyTracking.swift
  EventJournal.swift
  SnapshotStore.swift
  MigrationManager.swift
  ToolProjectPackage.swift
  AssetPackage.swift
  GraphPackage.swift
```

**V2 :**

- dirty tracking chunks ;
- fichiers région simples ;
- deltas props/terrain ;
- entités persistantes ;
- autosave incrémentale ;
- `state.sqlite` plus tard ;
- WAL plus tard ;
- `.isoproj`, `.isoasset`, `.isograph`.

**Dépend de :** Step 5, Step 11, Step 16, Step 21, Step 22.

---

## Step 24 — Tools Hub production V2

**But :** rendre les systèmes modifiables et validables.

**Outils à ajouter :**

- Terrain Recipe Editor ;
- Biome Graph Viewer ;
- Prop Gallery ;
- Material Viewer ;
- LOD Debugger ;
- Character Customization Lab ;
- Animation Contact Lab ;
- FX Preview Editor ;
- Audio Graph Preview ;
- RPG World DNA Browser ;
- Settlement Viewer ;
- Save Inspector ;
- Performance HUD ;
- Seed Gallery ;
- Snapshot Diff.

**Dépend de :** Step 13, Step 23.

---

# Phase E — Qualité haute, densité et systèmes avancés

## Step 25 — Lighting avancé + weather surfaces

**Référence :** `modern-texture-lighting-pipeline.md`

**But :** monter la qualité sans ray tracing/path tracing.

**Livrables :**

- Forward+ ou clustered lighting ;
- point/spot lights ;
- CSM ;
- shadow atlas ;
- wetness ;
- snow ;
- dust ;
- moss ;
- reflection probes ;
- irradiance probes chunkées ;
- fog/atmosphere/water.

**Dépend de :** Step 9, Step 14, Step 18.

---

## Step 26 — LOD avancé / IVDS Nanite-inspired

**Référence :** `nanite-inspired-lod-system.md`

**But :** préparer un monde dense sans coût CPU/GPU ingérable.

**Phases :**

1. HLOD par chunk.
2. Terrain LOD/quadtree simple.
3. Impostors arbres lointains.
4. Meshlets/clusters offline.
5. Cluster culling compute.
6. Geometry pages.
7. Streaming pages.
8. Mesh shader path si disponible.
9. Visibility buffer optionnel.

**Dépend de :** Step 10, Step 11, Step 22, Step 25.

---

## Step 27 — Props avancés et manufacturés

**Référence :** `procedural-parametric-props-system.md`

**But :** passer des props naturels simples à des familles procédurales riches.

**À ajouter :**

- registry + règles JSON/YAML ;
- scoring system ;
- `PropVariantGenome` ;
- weathering masks ;
- biome overlays ;
- props manufacturés ;
- sockets ;
- collisions composées ;
- interactive props ;
- articulated props ;
- WFC local pour objets composés.

**Dépend de :** Step 11, Step 23, Step 26.

---

## Step 28 — Animation avancée

**Référence :** `procedural-physics-driven-animation-system.md`

**But :** passer du contact terrain basique au mouvement AAA-ish.

**À ajouter :**

- locomotion planner ;
- footstep planner ;
- chaussures ;
- fatigue/charge ;
- support polygon approximatif ;
- glissades/trébuchements ;
- hand IK ;
- climb mode ;
- rope/ladder/stair affordances ;
- motion warping ;
- motion matching V1 ;
- active ragdoll partiel.

**Dépend de :** Step 15-17, Step 16, Step 25.

---

## Step 29 — FX avancés GPU

**Référence :** `procedural-parametric-particles-fx-pipeline.md`

**À ajouter :**

- GPU particles Metal ;
- spawn/update compute ;
- alive/dead lists ;
- indirect draw args ;
- depth collision ;
- soft particles ;
- flipbooks ;
- ribbons/trails ;
- beams ;
- distortion ;
- low-res particles ;
- volumetric lite ;
- weather macro FX.

**Dépend de :** Step 18, Step 25, Step 26.

---

## Step 30 — Audio avancé

**Référence :** `procedural-parametric-audio-engine.md`

**À ajouter :**

- graphes procéduraux ;
- physical footsteps ;
- wind/rain/water synth ;
- biome ambience manager ;
- musique générative ;
- harmony generator ;
- additive pads ;
- granular beds ;
- arrangement director ;
- spatialization ;
- occlusion ;
- reverb zones ;
- modal impact synth ;
- friction synth ;
- creature voice synth.

**Dépend de :** Step 19, Step 21, Step 25.

---

## Step 31 — Character avancé

**Référence :** `procedural-parametric-character-system.md`

**À ajouter :**

- génération PNJ par seed ;
- cultures/factions ;
- règles vêtements/climat ;
- hair cards ;
- cicatrices/tatouages/saleté ;
- yeux avancés ;
- peau subsurface approximée ;
- morphs visage ;
- expressions ;
- vêtements refit ;
- chaussures gameplay ;
- vieillissement ;
- blessures visibles ;
- prothèses ;
- membres manquants ;
- crowd LOD.

**Dépend de :** Step 16, Step 17, Step 21, Step 23, Step 28.

---

## Step 32 — RPG avancé

**Référence :** `procedural-deterministic-rpg-system.md`

**À ajouter :**

- factions ;
- générateur d’objectifs ;
- storylets ;
- quest graph ;
- lieux narratifs ;
- rumeurs locales ;
- director ;
- tension/pacing ;
- économie ;
- réputation ;
- métiers ;
- connaissance ;
- mythes ;
- endgames multiples ;
- transformations joueur.

**Dépend de :** Step 21, Step 22, Step 23, Step 31.

---

## Step 33 — Settlements avancés

**Référence :** `procedural-parametric-buildings-settlements-system.md`

**À ajouter :**

- villages complets ;
- quartiers ;
- routes/chemins ;
- façades procédurales ;
- roof grammar ;
- weathering ;
- trim sheets ;
- falaises habitées ;
- passerelles ;
- camps ;
- usines ;
- mines ;
- rails ;
- intérieurs partiels ;
- HLOD bâtiments/blocs/quartiers.

**Dépend de :** Step 22, Step 26, Step 32.

---

## Step 34 — UI/HUD avancé

**Référence :** `procedural-parametric-ui-hud-system.md`

**À ajouter :**

- retained-mode layout ;
- stack/grid/anchor/radial ;
- input router ;
- focus graph manette ;
- JSON themes ;
- token resolver ;
- modulation biome/weather/faction ;
- inventory stylisé ;
- map ;
- quest log ;
- dialogue ;
- crafting ;
- SDF/MSDF text ;
- procedural icons ;
- accessibility bridge.

**Dépend de :** Step 20, Step 21, Step 32.

---

## Step 35 — Validation production et seed lab

**But :** rendre le moteur robuste face aux changements.

**Livrables :**

```text
EngineCore/Validation/
  SeedTestSuite.swift
  DeterminismValidator.swift
  ChunkSeamValidator.swift
  BiomeTransitionValidator.swift
  PropPlacementValidator.swift
  PerformanceBudgetValidator.swift
  SaveMigrationValidator.swift
```

**À valider automatiquement :**

- déterminisme ;
- seams chunks ;
- collisions terrain ;
- poids biomes ;
- chunks sans NaN ;
- budgets props ;
- budgets draw calls ;
- sauvegarde/chargement ;
- migration saves ;
- snapshots visuels ;
- framerate debug non continu.

**Dépend de :** tous les systèmes.

---

## 9. Dépendances système par système

### 9.1 Terrain

**Dépend de :** Foundation, Renderer baseline, Jobs.  
**Débloque :** biomes, props, animation contact, settlements, RPG local, FX/audio de surfaces.

Implémenter dans cet ordre :

1. `TerrainSample` ;
2. debug layers ;
3. seams ;
4. material weights ;
5. FeatureGraph ;
6. hydrologie ;
7. verticalité ;
8. patches volumétriques ;
9. LOD/streaming.

### 9.2 Biomes

**Dépend de :** Terrain fields.  
**Débloque :** materials, props, weather, RPG world style, audio/FX, UI themes.

Implémenter dans cet ordre :

1. climate fields ;
2. top-2 weights ;
3. 8 biomes ;
4. sub-biomes ;
5. ecotones ;
6. hydrology corridors ;
7. `WorldBiomeDNA` ;
8. seasonal/RPG states.

### 9.3 Materials / lighting

**Dépend de :** Renderer, terrain, biomes.  
**Débloque :** high quality terrain, character materials, props, FX/audio surface response.

Implémenter dans cet ordre :

1. OpaquePBR ;
2. terrain layered ;
3. triplanar ;
4. debug views ;
5. Forward+ ;
6. shadows ;
7. surface states ;
8. probes ;
9. virtual textures.

### 9.4 LOD

**Dépend de :** Renderer baseline.  
**Débloque :** props massifs, settlements, foliage, world scale.

Implémenter dans cet ordre :

1. LODPolicy ;
2. hysteresis ;
3. chunk culling ;
4. instancing ;
5. HLOD ;
6. meshlets ;
7. geometry pages ;
8. mesh shaders path ;
9. visibility buffer.

### 9.5 Props

**Dépend de :** terrain, biomes, materials, LOD.  
**Débloque :** monde vivant, settlements, FX impacts, RPG tags.

Implémenter dans cet ordre :

1. rochers/cailloux ;
2. herbes ;
3. arbres ;
4. registry/rules ;
5. variants ;
6. props manufacturés ;
7. interactive props ;
8. advanced generation.

### 9.6 Characters

**Dépend de :** materials, LOD, save minimal.  
**Débloque :** animation, RPG player state, audio/FX contacts, HUD.

Implémenter dans cet ordre :

1. skeleton canonique ;
2. mesh simple ;
3. `CharacterDNA` ;
4. sliders ;
5. équipements ;
6. save customization ;
7. PNJ ;
8. states persistants ;
9. crowds.

### 9.7 Animation

**Dépend de :** terrain collision/materials, character base.  
**Débloque :** footstep audio/FX, vertical traversal, combat/interactions.

Implémenter dans cet ordre :

1. sampler ;
2. motor ;
3. terrain query ;
4. foot IK ;
5. contact patches ;
6. small obstacle avoidance ;
7. traversal vertical ;
8. motion matching ;
9. active ragdoll.

### 9.8 FX

**Dépend de :** materials, events, animation contacts.  
**Débloque :** feedback monde, weather, combat, ambiance.

Implémenter dans cet ordre :

1. events ;
2. billboards ;
3. burst ;
4. decals ;
5. footstep/impact ;
6. GPU particles ;
7. ribbons/trails ;
8. volumetric lite ;
9. world style FX.

### 9.9 Audio

**Dépend de :** material surface events, animation contacts, world/biome state.  
**Débloque :** feedback immersion, ambiances, musique procédurale.

Implémenter dans cet ordre :

1. event queue ;
2. bus ;
3. sample player ;
4. simple synth ;
5. footsteps ;
6. ambience ;
7. procedural graph ;
8. generative music ;
9. spatial/acoustic.

### 9.10 RPG

**Dépend de :** Foundation, WorldDNA, Save, biomes/props minimal.  
**Débloque :** monde radicalement différent par seed, factions, settlements, UI narratives.

Implémenter dans cet ordre :

1. tags ;
2. ruleset ;
3. macro world archetype ;
4. objectives ;
5. factions ;
6. storylets ;
7. director ;
8. economy/reputation ;
9. endgames.

### 9.11 Settlements

**Dépend de :** terrain, biomes, props, LOD, RPG.  
**Débloque :** villages, villes, camps, usines, lieux narratifs.

Implémenter dans cet ordre :

1. structure recipe ;
2. footprint ;
3. massing ;
4. terrain support ;
5. villages ;
6. façades ;
7. verticality ;
8. industrial/camps ;
9. interiors/HLOD.

### 9.12 UI/HUD

**Dépend de :** AppShell, snapshots, world/character/rpg states.  
**Débloque :** lisibilité joueur, debug tooling, thèmes de monde.

Implémenter dans cet ordre :

1. SwiftUI menus ;
2. UI snapshots ;
3. HUD Metal minimal ;
4. layout retained ;
5. themes ;
6. in-game menus ;
7. accessibility ;
8. iconography procedural.

### 9.13 Save

**Dépend de :** Foundation.  
**Débloque :** world slots, tools, player customization, deltas.

Implémenter dans cet ordre :

1. manifest ;
2. atomic writes ;
3. profile/slot ;
4. world seed/DNA ;
5. dirty chunks ;
6. region deltas ;
7. SQLite/WAL ;
8. tools packages ;
9. migrations.

---

## 10. Roadmap “vertical slice” recommandée

Cette roadmap permet d’obtenir rapidement un monde jouable minimal, mesurable et extensible.

### Milestone VS0 — Le projet compile proprement

- Xcode migré ;
- wrapper build OK ;
- scripts doctor ;
- tests base ;
- aucun système nouveau.

### Milestone VS1 — L’app ne chauffe plus en debug idle

- menu principal léger ;
- debug render throttled ;
- perf overlay ;
- benchmark mode ;
- debug snapshot cache.

### Milestone VS2 — Générer et ouvrir un mini monde réel

- AppShell ;
- seed input ;
- loading phases ;
- `WorldDNA` ;
- chunks initiaux ;
- terrain fields ;
- biome weights ;
- render payload.

### Milestone VS3 — Monde visible crédible

- PBR minimal ;
- terrain layered ;
- 8 biomes ;
- rochers/herbes/arbres ;
- instancing ;
- LOD baseline ;
- debug overlays.

### Milestone VS4 — Monde jouable minimal

- personnage simple ;
- motor capsule ;
- foot IK simple ;
- footstep events ;
- FX pas poussière/splash ;
- audio pas selon matériau ;
- sauvegarde slot minimal.

### Milestone VS5 — Outils utiles

- Tools Hub ;
- Terrain Viewer ;
- Biome Viewer ;
- Prop Gallery ;
- Material Viewer ;
- Save Inspector ;
- Seed Gallery.

### Milestone VS6 — Exploration verticale

- FeatureGraph ;
- rivières/lacs ;
- falaises ;
- climbability ;
- rope/stair candidates ;
- traversal debug ;
- premières structures attachées.

### Milestone VS7 — Identité procédurale du monde

- RPG DNA V1 ;
- world archetypes ;
- thèmes UI/audio/FX ;
- génération PNJ simple ;
- settlements V1 ;
- sauvegardes de deltas.

---

## 11. Organisation des PRs pour Codex

### 11.1 Taille des PRs

Chaque PR doit être petit et vérifiable.

Bon PR :

```text
feat(engine-foundation): add StableRNG and deterministic seed domains
```

Mauvais PR :

```text
feat: add terrain, biomes, props, save, new UI and renderer refactor
```

### 11.2 Format de PR recommandé

Chaque PR doit contenir :

- objectif ;
- fichiers modifiés ;
- dépendances ;
- tests ajoutés ;
- procédure de validation ;
- captures si rendu ;
- impact perf si runtime ;
- décision docs si architecture.

### 11.3 Branches suggérées

```text
chore/update-xcode-toolchain
perf/debug-render-cadence
feat/app-shell-state-machine
feat/engine-foundation-determinism
feat/save-manifest-minimal
feat/render-framegraph-baseline
feat/terrain-fields-v1
feat/biome-fields-v1
feat/pbr-terrain-materials-v1
feat/lod-culling-instancing-v1
feat/props-natural-v1
feat/world-prepare-pipeline
feat/tools-hub-v1
feat/terrain-featuregraph-hydrology
feat/traversal-verticality-v1
feat/character-base-v1
feat/animation-contact-v1
feat/fx-events-v1
feat/audio-events-v1
feat/hud-procedural-v1
feat/rpg-dna-v1
feat/settlements-v1
feat/save-deltas-v2
```

---

## 12. Tests à créer très tôt

### 12.1 Tests de déterminisme

```swift
func testSameSeedSameChunkProducesSameTerrain()
func testSameSeedSameBiomeWeights()
func testStableIDDoesNotDependOnGenerationOrder()
func testPropPlacementStableAcrossChunkLoadOrder()
func testWorldDNASerializesAndRestores()
```

### 12.2 Tests de seams

```swift
func testTerrainChunkEdgesMatchNeighbors()
func testBiomeWeightsContinuousAcrossChunkEdges()
func testMaterialWeightsDoNotJumpAtChunkBoundary()
```

### 12.3 Tests de performance

```swift
func testDebugIdleDoesNotRenderContinuously()
func testChunkGenerationBudget()
func testPropPlacementBudget()
func testRendererDoesNotAllocatePerFrameForStaticScene()
```

### 12.4 Tests de sauvegarde

```swift
func testSaveManifestAtomicWrite()
func testSaveSlotRoundtrip()
func testWorldDNAHashChangesWhenGeneratorVersionChanges()
func testCacheIsNotRequiredToLoadSave()
```

### 12.5 Tests de snapshots

```swift
func testRenderSnapshotIsImmutable()
func testDebugSnapshotThrottling()
func testToolPreviewDoesNotMutateWorldSession()
```

---

## 13. Debug views indispensables

À ajouter progressivement :

| Debug view | Dès quelle phase |
|---|---|
| Frame timing | Step 1 |
| Render cadence | Step 1 |
| Chunk bounds | Step 6 |
| Terrain height | Step 7 |
| Terrain slope | Step 7 |
| Terrain normals | Step 7 |
| Biome weights | Step 8 |
| Material weights | Step 9 |
| Draw calls / instances | Step 10 |
| Prop placement density | Step 11 |
| Loading phases | Step 12 |
| Hydrology graph | Step 14 |
| Climbability | Step 15 |
| Character contacts | Step 17 |
| Footstep material | Step 17-19 |
| FX budget | Step 18 |
| Audio meters | Step 19 |
| HUD layout bounds | Step 20 |
| RPG WorldDNA print | Step 21 |
| Settlement support map | Step 22 |
| Save dirty chunks | Step 23 |

---

## 14. Données de référence communes

### 14.1 Golden seeds

Créer un fichier :

```text
docs/golden-seeds.md
```

Seeds recommandées :

```text
seed_plain
seed_mountain
seed_river
seed_desert
seed_dense_forest
seed_transition_biome
seed_extreme_height
seed_cliff_vertical
seed_swamp
seed_coastal
seed_snow
seed_volcanic
seed_settlement_slope
seed_debug_perf_dense_props
seed_debug_animation_rocks
```

### 14.2 Budgets initiaux M1

Budgets de départ, à ajuster par profiling réel :

| Domaine | Budget V1 |
|---|---:|
| Frame cible jeu | 16.6 ms si 60 FPS, sinon 33.3 ms si 30 FPS |
| Debug paused | on demand |
| Debug slow | 5-15 FPS |
| Chunk generation sync | 0 ms sur main thread |
| Chunk generation job | budgeté/cancellable |
| Draw calls V1 | le plus bas possible, mesurer avant fixer |
| Props visibles V1 | instancing obligatoire |
| SwiftUI panels stats | 2-10 Hz |
| Heavy validation | manuel/job async |

---

## 15. Ce que Codex doit faire en premier

### PR 1 — Toolchain doctor

Créer :

```text
scripts/doctor.sh
```

Le script doit afficher :

- Xcode version ;
- Swift version ;
- xcode-select path ;
- DEVELOPER_DIR si défini ;
- Metal compiler path ;
- scheme list ;
- commande de build recommandée.

### PR 2 — Debug cadence

Créer :

- `DebugWorldRunMode` ;
- `RenderCadencePolicy` ;
- stats cadence ;
- mode paused/slow/live/benchmark ;
- aucun rendu monde en menu.

### PR 3 — AppShell

Créer :

- `AppMode` ;
- `MainMenuView` ;
- `LoadingView` ;
- `DebugWorldView` ;
- `ToolsHubView` stub ;
- transitions propres.

### PR 4 — Engine foundation

Créer :

- `StableRNG` ;
- `StableHash` ;
- `SeedDomain` ;
- `StableID` ;
- `WorldDNA` minimal ;
- tests déterminisme.

### PR 5 — Save manifest minimal

Créer :

- `SaveSlotManager` ;
- `SaveManifest` ;
- atomic write ;
- save/load d’un seed + world DNA.

### PR 6 — TerrainSample V1

Créer :

- `TerrainSample` ;
- grid par chunk ;
- debug height/slope ;
- seams tests.

---

## 16. Règles de décision importantes

### 16.1 Apple UI ou custom UI ?

- SwiftUI/AppKit pour : menu, tools, inspectors, préférences, loading, file dialogs.
- Metal custom pour : HUD in-game stylisé, world-space UI, previews 3D, overlays haute performance.

### 16.2 SQLite ou fichiers ?

- JSON pour manifests/presets/debug.
- Fichiers région pour deltas spatiaux.
- SQLite/WAL pour état structuré volumineux plus tard.
- CAS blobs pour assets/caches lourds.

### 16.3 Tout procédural au runtime ?

Non.

- Runtime : décisions, variantes, placement, paramètres, instancing.
- Async/offline cache : meshes coûteux, HLOD, clusters, previews, light probes.
- Source of truth : seed + recipes + deltas.

### 16.4 Tout en 60 FPS ?

Non.

- Renderer monde actif : selon mode.
- Debug : throttled/on-demand.
- Tools : previews à la demande.
- Generation : jobs async.
- Validation : batch.

### 16.5 Nanite-like tout de suite ?

Non.

Commencer par : LOD classique, culling, instancing, HLOD simple. Ensuite meshlets/clusters. Ensuite streaming pages.

---

## 17. Critères de qualité globaux

Un système est “intégrable” seulement s’il respecte :

- déterminisme ;
- tests ;
- debug view ;
- budget ;
- pas d’allocation per-frame inutile ;
- pas de dépendance UI dans `EngineCore` ;
- version de données ;
- sauvegarde ou cache policy claire ;
- fallback simple ;
- documentation courte dans `docs/decisions` si décision structurante.

---

## 18. Checklist de revue Codex

Avant merge, vérifier :

```text
[ ] Build via scripts/xcodebuild-safe.sh OK
[ ] Tests OK
[ ] Pas de modification globale Xcode requise
[ ] Pas de rendu 60 Hz non demandé dans menu/debug idle
[ ] Pas de génération synchrone lourde sur MainActor
[ ] Pas d’import SwiftUI dans EngineCore
[ ] Pas d’import Metal dans les systèmes core sauf payload explicitement renderer
[ ] Pas de RNG consommé dans un ordre instable
[ ] Pas d’allocation évidente dans la frame loop
[ ] Debug view ou stats ajoutées
[ ] Save/cache policy définie si données persistantes
[ ] Document de référence mentionné si système majeur
```

---

## 19. Ordre final conseillé en une phrase

**Mettre à jour le projet et corriger le debug 60 Hz, puis construire AppShell + EngineCore déterministe + save minimal + renderer baseline + terrain/biomes/materials + LOD/instancing + props ; seulement ensuite ajouter verticalité, characters, animation, FX, audio, HUD, RPG, settlements, save avancée et IVDS.**

---

## 20. Annexe — mapping documents vers steps

| Document | Steps principaux dans ce plan |
|---|---|
| `procedural-app-flow-shell-tools-system.md` | 2, 12, 13, 24 |
| `procedural-save-system.md` | 5, 23 |
| `procedural-modern-rendering.md` | 6, 10, 25, 26 |
| `modern-texture-lighting-pipeline.md` | 9, 25 |
| `procedural-versatile-terrain-generation.md` | 7, 14, 15 |
| `procedural-biome-transition-system.md` | 8 |
| `nanite-inspired-lod-system.md` | 10, 26 |
| `procedural-parametric-props-system.md` | 11, 27 |
| `procedural-parametric-character-system.md` | 16, 31 |
| `procedural-physics-driven-animation-system.md` | 17, 28 |
| `procedural-parametric-particles-fx-pipeline.md` | 18, 29 |
| `procedural-parametric-audio-engine.md` | 19, 30 |
| `procedural-parametric-ui-hud-system.md` | 20, 34 |
| `procedural-deterministic-rpg-system.md` | 21, 32 |
| `procedural-parametric-buildings-settlements-system.md` | 22, 33 |

---

## 21. Annexe — références externes utiles à garder dans le repo

Ces liens ne sont pas nécessaires à Codex pour implémenter chaque PR, mais ils contextualisent les décisions :

- Apple Xcode : https://developer.apple.com/xcode/
- Apple Metal sample code : https://developer.apple.com/metal/sample-code/
- Swift documentation : https://docs.swift.org/swift-book/documentation/the-swift-programming-language/
- SQLite WAL : https://sqlite.org/wal.html
- Unreal PCG : https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-overview
- Unreal Nanite : https://dev.epicgames.com/documentation/unreal-engine/nanite-virtualized-geometry-in-unreal-engine
- Unreal Motion Matching : https://dev.epicgames.com/documentation/unreal-engine/motion-matching-in-unreal-engine
- Unreal Niagara : https://dev.epicgames.com/documentation/unreal-engine/overview-of-niagara-effects-for-unreal-engine
- Houdini procedural modeling : https://www.sidefx.com/products/houdini/modeling/procedural-modeling/
- CityEngine CGA : https://doc.arcgis.com/en/cityengine/latest/tutorials/essentials-rule-based-modeling.htm
