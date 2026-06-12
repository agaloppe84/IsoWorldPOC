# Architecture

## Cible

Le projet vise une separation nette entre l'application macOS, le rendu, les entrees utilisateur et le moteur de jeu.

```text
IsoWorldPOC macOS app
├── SwiftUI
├── Metal
├── GameController
└── EngineCore
    ├── simulation
    ├── generation procedurale
    ├── chunks
    ├── coordonnees monde
    └── regles testables
```

## App macOS

Les sources de l'app vivent dans:

```text
IsoWorldPOC/IsoWorldPOC/
```

Responsabilites:

- Composition SwiftUI.
- Cycle de vie macOS.
- Integration Metal.
- Integration GameController.
- Adaptation entre l'etat moteur et le rendu.

L'app peut importer SwiftUI, MetalKit, GameController et EngineCore. RealityKit a ete retire du code app et ne doit pas etre reintroduit.

## Rendu 3D

Metal est le renderer actif du projet.

Responsabilites:

- Scene 3D.
- Camera isometrique/orbitale.
- Entites visibles.
- Materiaux et lumieres.
- Synchronisation GPU avec les snapshots de rendu produits par la simulation.

RealityKit ne fait plus partie du chemin de rendu. Il ne doit pas entrer dans `EngineCore`.

### Backend actif

Le backend actif unique est `MetalRenderer`, heberge par `MetalGameView`.

Responsabilites:

- Configurer `MTKView`.
- Posseder les ressources GPU Metal.
- Consommer `RenderWorldSnapshot`.
- Orchestrer les passes Metal.
- Mettre a jour les metriques debug liees au renderer.
- Ne pas piloter directement la simulation, les inputs gameplay ou le streaming logique.

`MetalGameView` reste un host macOS/SwiftUI: elle cree le `MTKView`, transmet les evenements clavier et laisse le backend renderer gerer le rendu.

Les contrats de rendu purs vivent dans `EngineCore/Rendering` et ne doivent importer ni RealityKit ni Metal.

### Passes Metal

Le rendu Metal est organise en passes legeres, sans RenderGraph complet pour l'instant:

- `MetalTerrainPass`: dessine les chunks terrain visibles.
- `MetalPropPass`: dessine les props proceduraux bakes dans les buffers de chunk.
- `MetalPlayerPass`: dessine le preview joueur.
- `MetalDebugPass`: dessine les helpers debug 3D comme les bounds de chunks.

`MetalFrameContext` transporte l'etat necessaire a une frame:

- `RenderWorldSnapshot`;
- buffers GPU par chunk;
- buffers joueur;
- position joueur;
- matrice view-projection.
- uniforms de lumiere derives de `LightingState`.
- uniforms debug derives de `RenderDebugOptions`.

Chaque passe retourne des metriques de draw simples. L'overlay expose les draw calls, buffers GPU, chunks dessines et props dessines. Cette structure prepare les futures passes lighting/shadow/material sans imposer encore un graphe de rendu complexe.

### Materiaux Metal initiaux

Le rendu Metal utilise un payload materiau par vertex:

- couleur de base;
- roughness scalaire;
- identifiant numerique simple de type materiau;
- indices de couches texture terrain explicites;
- echelles UV par couche terrain.

Pour le terrain, `BiomeSampler` produit maintenant un `TerrainVertexMaterial` par sample/vertex. Ces materiaux restent deterministes par seed, chunk et coordonnee locale. Les bords utilisent les memes coordonnees monde que la generation de biome, ce qui permet aux chunks voisins de partager les memes couleurs/materiaux sur leurs frontieres.

Chaque sample peut porter un materiau primaire, un materiau secondaire et un poids de transition. Ces donnees restent disponibles pour les vues debug, tandis que le rendu normal utilise les couches splat PBR preview dans le fragment shader.

Les donnees de sample preparent aussi un modele splat: `TerrainMaterialSplat` contient jusqu'a 4 couches de materiaux normalisees. Chaque couche porte un `RenderMaterial` et des `TerrainPBRTextureSlots` neutres pour `albedo`, `normal`, `roughness` et `metallicAmbientOcclusion`. Ces slots declarent `textureLayerIndex`, `uvScale` et `debugName` sans importer Metal. Le vertex buffer Metal transporte `splatWeights`, `splatTextureLayerIndices`, `splatUVScales` et les coordonnees UV terrain.

Le rendu normal du terrain utilise un `TerrainTextureCatalog` preview cote Metal. Ce catalogue genere en memoire quatre petits texture arrays 2x2 par materiau (`grass`, `rock`, `dirt`, `sand`, `mud`, `snow`): albedo, normal flat, roughness grayscale et metallic/ambient-occlusion neutre. Le fragment shader echantillonne ces couches et les melange avec les 4 poids splat. C'est volontairement simple, mais l'architecture est deja proche d'un futur atlas ou texture array de vraies textures.

L'overlay peut basculer le debug terrain entre rendu normal, biome primaire, biome secondaire, heatmap du poids de transition et heatmap d'une couche splat specifique. Le mode et l'index de couche splat sont stockes dans `RenderDebugOptions`, passes au shader par uniform, et ne s'appliquent qu'aux vertices terrain.

Cette approche garde les props et terrains batchables par chunk. Elle evite de multiplier les draw calls par biome ou materiau. Le shader utilise actuellement la roughness pour adoucir la reponse diffuse des materiaux rugueux.

### Props naturels V1

Les props naturels V1 restent dans le pipeline chunk existant:

- `EngineCore/Props` definit `PropSystem`, `PropCatalog`, `PropPlacementRule`, `PropContext`, `PropRecipe`, `PropVariantGenome` et `PropChunkData`.
- `PropSystem` recoit le `TerrainSampleGrid`, le biome dominant et le seed monde pour produire des placements, recipes, IDs stables et variants deterministes.
- `PropCatalog.naturalV1` couvre rochers, cailloux, herbes, arbres, bois mort et cristaux.
- Les regles de placement utilisent biome, slope, moisture et walkability.
- `ProceduralChunkDataFactory` consomme `PropChunkData` puis expose les placements et variants dans le meme snapshot V1 qu'avant.
- `MetalChunkBuffers` bake les shapes `box`, `capsule` et `cone` dans le buffer props du chunk.

Cette baseline ne cree pas encore de chemin d'instancing GPU parallele, de billboards, d'imposteurs ou de collisions detaillees par prop.

### WorldPreparePipeline V1

Le monde reel ne s'ouvre plus directement depuis le menu. `WorldPreparePipeline` fabrique une `WorldSession` minimale avant de passer en `realWorld`.

Responsabilites:

- normaliser le seed texte et produire un `WorldSeed`;
- generer `WorldDNA`;
- initialiser les regles V1 terrain, biomes et props;
- preparer les champs terrain/biome autour du spawn;
- resoudre un spawn joueur praticable;
- generer les chunks initiaux autour du spawn avec le meme seed que la session;
- valider les payloads CPU de rendu et le bootstrap collision minimal;
- publier une progression determinee par phases ponderees;
- respecter l'annulation cooperative avant l'ouverture du monde.

Les types de preparation vivent dans `IsoWorldPOC/IsoWorldPOC/GameRuntime/WorldPrepare`.
`WorldOpenRequirements` decrit les conditions minimales avant ouverture. Le runtime ne doit pas creer une session monde si ces exigences ne sont pas satisfaites.

`WorldSession` transporte maintenant `worldSeed`, `WorldDNA`, `spawnPosition`, `initialChunks` et `openRequirements`. `RealWorldView` transmet cette session a `GameRootView`, puis a `MetalRenderer` et `WorldRuntime`.

Cette baseline ne precompile pas encore les pipelines GPU hors `MetalRenderer`. Le warmup Step 12 signifie que les payloads CPU critiques sont prets avant la premiere frame.

### Terrain FeatureGraph V1

Le terrain V1 est structure par un `TerrainFeatureGraph` deterministe dans `EngineCore/Terrain/Features`.

Responsabilites:

- declarer les features terrain V1: `RiverFeature`, `LakeFeature`, `MountainRangeFeature`, `CliffBandFeature`;
- permettre une query par chunk pour savoir quelles features affectent une zone;
- produire des contributions de hauteur et de masques depuis les coordonnees monde;
- appliquer carving, ranges, falaises, water masks et shore masks avant la creation des samples;
- rester independant de Metal, SwiftUI et du runtime monde.

`DefaultTerrainFieldProvider` combine la height function de base avec les contributions du graph. Les `TerrainSample` transportent `waterDepth` et `TerrainFeatureMasks` (`water`, `shore`, `mountain`, `cliff`). Ces masks influencent humidite, materiaux terrain, walkability et climbability, tout en gardant les bords de chunks stables car les features sont echantillonnees en coordonnees monde.

### Traversal gameplay V1

`EngineCore/Traversal` derive la verticalite gameplay depuis `TerrainSampleGrid` sans dependre de Metal ni de SwiftUI. `TraversalSurfaceClass` classe les samples en `walkable`, `steep`, `climbable`, `dangerous` ou `blocked`. `ClimbabilityMap` garde les valeurs de climbability, les scores de ledge et les classes par sample.

`TraversalChunkData` regroupe les candidats de chunk: ledges, anchors de corde, attaches d'escalier et routes verticales candidates. Cette data est produite depuis le terrain V1 par `TerrainSystem.traversalData(for:)`, puis transportee dans `ProceduralChunkData` pour que le runtime puisse lire les affordances sans recalculer le chunk.

Le grounding joueur utilise la classe traversal sous le joueur quand elle est disponible. Le fallback par pente brute reste uniquement une garde de robustesse pour les payloads incomplets; les decisions gameplay V1 doivent passer par `TraversalSurfaceClass`.

Le renderer ne dessine pas encore de surface d'eau dediee. Pour l'instant, l'hydrologie V1 existe comme donnees moteur et comme splats de materiaux shore/mud, afin de preparer debug, gameplay traversal et rendu d'eau futur.

### Personnages V1

`EngineCore/Characters` porte la base personnage procedurale pure, sans SwiftUI, Metal ni dependance runtime app.

Responsabilites:

- generer un `CharacterDNA` deterministe depuis `WorldSeed`, `GeneratorVersionTable` et index personnage;
- decrire les parametres de corps, le skeleton humanoide canonique, les sockets et la capsule collision;
- porter l'apparence, les sliders visage et les materiaux PBR neutres peau/cheveux/vetements;
- gerer les slots d'equipement, les conflits de slots et un starter outfit stable;
- separer l'ADN regenerable de `CharacterRuntimeState`;
- sauvegarder la personnalisation dans `CharacterCustomizationSave` sans persister de cache mesh.

`WorldRuntime` cree le joueur depuis le seed de la `WorldSession`, puis `PlayerController` derive vitesse de marche et capsule collision depuis la DNA. Le renderer garde encore son preview joueur simple; le mesh skinned, les vetements visibles et l'animation complete arriveront au-dessus de ces contrats V1.

### Animation Contact V1

`EngineCore/Animation` pose la premiere couche IsoMotion V1, pure et testable.

Responsabilites:

- decrire un `AnimationSkeleton` depuis le skeleton personnage;
- transporter des poses locales via `Pose` et `JointPose`;
- sampler des `AnimationClip` simples et fournir les poids de pieds plantes;
- convertir un `TerrainSample` en `ContactPatch` avec friction, wetness, compliance, stabilite et tags;
- exposer un `CharacterMotor` capsule/friction/slope/step-up;
- resoudre un foot IK minimal avec foot locking, pelvis compensation, slope normal et clearance de petit obstacle;
- generer des `FootstepEvent` materiau-aware pour FX/audio futurs.

Le runtime app garde un `TerrainSampleGrid` par chunk charge afin que les contacts animation lisent les memes donnees V1 que le terrain, les props et traversal. `PlayerController` met a jour une pose/contact joueur depuis le grounding courant, mais le renderer Metal affiche encore le preview joueur simple. Aucun etat animation n'entre dans SwiftUI.

### FX V1

`EngineCore/FX` est la couche data-driven qui relie contacts, materiaux et rendu d'effets.

Responsabilites:

- decrire des `FXDefinition` pures: kind billboard/decal, blend mode, burst, lifetime, size, velocity, gravity, courbes couleur et taille;
- transporter des `FXEvent`, `FXBillboardParticle`, `FXDecal` et `FXFrameSnapshot` codables;
- resoudre des `FXSurfaceResponse` depuis `TerrainMaterialKind`, wetness et friction;
- convertir les `FootstepEvent` et impacts en poussiere, splash, sparks et footprint decals via `FXRecipe`;
- appliquer un `FXBudget` deterministe avant exposition au renderer;
- garder les FX actifs dans `FXFrameState` pendant leur lifetime.

Le runtime monde avance `FXFrameState` apres la simulation joueur, puis injecte le `FXFrameSnapshot` dans `RenderWorldSnapshot`. Le renderer Metal ne recalcule pas les contacts et ne connait pas les regles materiau: il lit seulement les particules/decals budgetes.

Le rendu actuel garde deux passes separees:

- `DecalPass`;
- `BillboardParticlePass`.

Elles sont inserees dans `FrameGraph` apres opaque et avant debug overlay. L'implementation GPU reste volontairement minimale et reutilise le shader opaque avec alpha blending; l'architecture permet de remplacer plus tard ces passes par instancing, atlas sprites ou decal projection sans changer le contrat EngineCore.

### Audio V1

`EngineCore/Audio` est la couche audio procedurale pure, reliee aux contacts et materiaux du moteur.

Responsabilites:

- transporter des `IsoAudioEvent` deterministes avec recipe, source, position, bus, priorite, seed et parametres;
- decrire les bus `master`, `music`, `ambience`, `foley`, `world` et `ui`;
- resoudre des `AudioSurfaceResponse` depuis `TerrainMaterialKind`, wetness et friction;
- fournir des `AudioRecipe` pour ambience et footsteps materiau-aware;
- convertir les `FootstepEvent` en events audio via `AudioRecipeResolver`;
- exposer des meters `AudioBusMeter` exploitables par debug/profiling sans imposer SwiftUI au moteur.

`AudioRuntime` vit cote app pour la V1. Il contient une queue priorisee, un sample player avec fallback procedural, un noise synth deterministe et `IsoAudioEngine` qui produit un `AudioRuntimeSnapshot`.

Cette V1 ne sort pas encore sur le systeme audio macOS. Le pipeline est d'abord data-driven et testable; une couche de sortie bas niveau pourra consommer les buffers/voices ensuite, sans changer les recipes ni les evenements moteur.

### RPG DNA V1

`EngineCore/RPG` transforme le seed en constitution RPG du monde.

Responsabilites:

- generer un `WorldRPGDNA` deterministe depuis `WorldSeed`, `SeedDomain.rpgDNA` et `GeneratorVersionTable`;
- choisir archetype, epoque, niveau technologique, magie, menace, presence ennemie, objectif global, progression et tonalite;
- exposer des `GameplayTag` stables pour relier terrain, props, UI, settlements, quetes, factions et sauvegarde;
- transformer le DNA en `WorldRuleset` executable: systemes actifs, politique de violence, objectif primaire, factions et quest seeds;
- fournir un `WorldStateLedger` compact pour stocker les faits et deltas significatifs sans sauvegarder toute la simulation.

`WorldDNA.rpg` est le point d'entree du reste du moteur. Les prochains systemes ne doivent pas hardcoder leur propre genre de monde: ils lisent les tags, objectifs et regles RPG. Le debug print du monde est porte par `debugSummary`, afin que tools, tests et futurs panels puissent afficher la constitution generee sans dependance SwiftUI.

### Settlements V1

`EngineCore/Settlements` transforme terrain, biome et ruleset RPG en plan de settlement pur.

Responsabilites:

- definir un catalogue V1 de `StructureRecipe` pour maisons simples, cabanes, stockage, workshops, markets, shrines, watchtowers, halls et farm houses;
- choisir une `SettlementRecipe` depuis `WorldRuleset`, `WorldRPGDNA` et biome dominant;
- analyser un `TerrainSampleGrid` via `TerrainSupportMap` pour classer pente, eau, roughness, walkability, support solution et buildable score;
- selectionner un site deterministe avec `SettlementSiteSelector`;
- produire des `BuildingIntent` gameplay avant toute geometrie;
- generer des footprints orientes et des ajustements de fondation sans aplatir le terrain;
- produire un massing simple et une `StructureRenderInstance` instanciable avec primitives/materials deja connus du moteur;
- assembler le tout dans un `SettlementPlan` validable avec chemins simples.

La V1 reste volontairement hors runtime app: elle ne force pas encore l'affichage de villages dans le monde. Les prochains steps pourront brancher ces instances au renderer, au streaming et a la sauvegarde sans changer le contrat terrain/RPG.

### UI/HUD V1

`EngineCore/UIModel` porte les contrats purs du HUD in-game, sans SwiftUI ni Metal.

Responsabilites:

- generer un `UIWorldDNA` deterministe depuis `WorldSeed`, `SeedDomain.ui` et `GeneratorVersionTable`;
- definir les tokens, palettes et themes V1 `neutral`, `parchment` et `sci-fi`;
- transporter un `UIFrameSnapshot` stable par frame avec health, stamina, biome, meteo et prompt terrain;
- garder les donnees HUD dans `RenderWorldSnapshot` pour que le renderer consomme un snapshot, sans interroger les systemes moteur directement.

Le rendu HUD in-game vit cote app dans `Rendering/Metal/UI`. `UIMetalRenderer` convertit le snapshot UI en `UIDrawCommand` puis batch des quads screen-space dans `HUDOverlayPass`, apres les passes monde et FX. Les labels utilisent une fonte bitmap minimale et les icones viennent d'un atlas procedural 5x5.

SwiftUI reste le bon outil pour les menus, tools et panneaux debug, mais le vrai HUD du monde ne doit pas dependre de publications `ObservableObject` haute frequence.

### Tools Hub V1

Le Tools Hub est une surface app separee du monde runtime.

Responsabilites:

- declarer les outils disponibles via `ToolRegistry.v1`;
- porter les parametres utilisateur dans `ToolDocument`;
- valider localement un document d'outil;
- produire une preview isolee sous forme de `ToolPreviewSnapshot`;
- rester hors `WorldRuntime`, hors `WorldSession` et hors boucle Metal du monde.

Les outils initiaux sont Terrain Viewer, Biome Viewer, Prop Gallery, Material Viewer, LOD Debugger et Seed Explorer. Le hub prepare des previews specialisees futures, mais son contrat V1 interdit de contourner le pipeline moteur: un outil doit consommer les donnees V1 et produire un snapshot ou un rapport explicite.

### LOD baseline

Le LOD V1 est un systeme classique et explicite, avant tout HLOD ou virtual geometry.

Responsabilites:

- `EngineCore/LOD` definit `LODPolicy`, `LODSelection`, `ScreenError`, `Hysteresis` et `LODBudget`.
- `ChunkDataStreamer` garde un rayon de chunks candidats, calcule une selection LOD deterministe depuis la position joueur et applique un budget de chunks visibles et de props rendus.
- `RenderChunk` transporte sa `LODSelection`, afin que le renderer ne reinvente pas la decision.
- `RenderPayloadUploader` charge uniquement les chunks visibles.
- `MetalChunkBuffers` genere l'index buffer terrain selon le niveau LOD selectionne, avec des bords de chunk conserves en pleine resolution.

Cette baseline ne fait pas encore de meshlets, HLOD, visibility buffer, occlusion culling GPU ou collision LOD avancee.

### Lumiere

La lumiere de base est portee par `LightingState` dans les contrats `EngineCore/Rendering`.

Responsabilites:

- Decrire une lumiere directionnelle principale.
- Exposer intensite solaire, intensite ambiante et activation future des ombres.
- Rester independante de Metal, RealityKit et SwiftUI.

Le shader Metal consomme ces valeurs via un uniform dedie. Les ombres ne sont pas encore calculees: `shadowsEnabled` est conserve dans le contrat pour preparer une future `MetalShadowPass`.

### Runtime monde et snapshots

`WorldRuntime` est la couche runtime de l'app. Elle orchestre les systemes gameplay encore cote app:

- `InputManager`;
- `PlayerController`;
- `PlayerGrounding`;
- `OrbitCameraController`;
- `ChunkDataStreamer`;
- `RenderSnapshotBuilder`.

Responsabilites:

- Avancer la simulation a chaque frame.
- Mettre a jour le streaming de chunks autour du joueur.
- Resoudre le suivi terrain du joueur.
- Produire le `RenderWorldSnapshot` courant.
- Remplir les metriques debug gameplay/monde.
- Demarrer depuis les chunks et le spawn d'une `WorldSession` preparee quand on ouvre un monde reel.

`RenderSnapshotBuilder` convertit l'etat runtime en contrats de rendu neutres:

- `RenderWorldSnapshot`;
- `RenderChunk`;
- `RenderProp`;
- `CameraRenderState`;
- options de debug chunk bounds, toggles d'isolation et modes materiaux terrain.

Le renderer Metal ne doit donc pas construire le monde ni decider quels chunks existent. Il recoit un snapshot, synchronise les buffers GPU manquants, puis dessine.

### Baseline performance et isolation

Le vrai monde et le monde debug utilisent le meme pipeline V1, mais pas le meme profil:

- `realWorld` demarre sans chunk bounds et sans metriques visibles dans la scene.
- `debugWorld` expose les outils d'isolation dans l'overlay.
- Les toggles d'isolation passent de `DebugMetrics` a `RenderSnapshotDebugOptions`, puis a `RenderDebugOptions`.
- `WorldRuntime` respecte `freezeSimulation`, `freezeChunkStreaming` et `forcedLODLevel`.
- `RenderPayloadUploader` synchronise les buffers chunks seulement si terrain, props ou chunk bounds en ont besoin.
- `FrameGraph` et les passes Metal sautent les couches desactivees au lieu de dessiner puis masquer.

Les metriques prioritaires sont: frame time, simulation, snapshot, sync buffers, encode render, chunks visibles, indices terrain/props et estimation memoire CPU/GPU. Elles servent a isoler les couts avant toute optimisation plus invasive.

Le diagnostic Step 12-TER separe aussi:

- l'intervalle brut entre callbacks MTKView;
- le cout total de `draw(in:)`;
- le gap entre callback et travail mesure;
- le cout de publication des metriques SwiftUI;
- le detail du snapshot: chunks actifs, conversion chunks, props et sampling terrain des props.

Si le gap reste eleve pendant que `draw(in:)` reste bas, le probleme est dans la cadence/scheduling plutot que dans les passes Metal. Si `pause metrics publish` remonte la cadence, la publication `ObservableObject` doit etre decouplee du rendu.

Le decouplage Step 12-QUATER applique cette regle: `DebugMetrics` publie les controles utilisateur separement de `DebugTelemetry`. Le renderer mutate des champs de staging non publies pendant la frame, puis appelle `publishTelemetry()` une seule fois pour rafraichir l'overlay. L'overlay lit ce snapshot unique et garde les bindings uniquement pour les toggles, pickers et modes debug.

Le correctif Step 12-QUINQUIES pousse cette separation plus loin: `DebugMetrics` ne publie plus directement la telemetry. Il possede un `DebugTelemetryStore` dedie, observe seulement par les blocs texte de l'overlay. Les controles restent observes depuis `DebugMetrics`, ce qui evite qu'une update FPS invalide `GameRootView`, `MetalGameView` ou les controles SwiftUI.

Le correctif Step 12-SNAPSHOT-CACHE traite le cout commun au Debug World et au Real World: `RenderSnapshotBuilder` garde un cache de `RenderChunk` par chunk visible, invalide par signature de rendu, et ne transporte plus les chunks invisibles dans le snapshot. Le renderer continue de consommer un snapshot V1 neutre, mais le runtime evite de resampler les props et de reconstruire les payloads terrain stables a chaque frame.

Le correctif Step 12-FRAME-DRIVER separe aussi les profils d'execution: Debug World peut publier de la telemetry SwiftUI, Real World ne le fait pas. `DebugCadenceController` devient le driver explicite des frames continues et laisse `MTKView` en canvas Metal pause, ce qui evite de dependre d'un reveil implicite fragile quand SwiftUI, AppKit et le debugger se partagent le main thread.

Le correctif Step 12-DEBUG-LEAN garde le Debug World utilisable sans redevenir le goulot principal: l'overlay SwiftUI publie a basse frequence, affiche un bloc compact par defaut, masque les details longs derriere un toggle et laisse les chunk bounds desactives tant qu'ils ne sont pas necessaires.

### Donnees de chunks procedurales

`ProceduralChunkDataFactory` produit les donnees de chunks neutres consommees par Metal:

- geometrie terrain issue d'`EngineCore`;
- biome dominant;
- materiau terrain abstrait;
- materiaux terrain par vertex/sample issus du biome;
- placements et variants de props issus de `PropSystem`;
- origine monde du chunk;
- metriques simples de generation.

Ce factory ne doit pas importer RealityKit ni Metal. Il remplace l'ancien melange entre generation de donnees et rendu RealityKit.

## Input

GameController est utilise pour le support manette PS5.

Responsabilites:

- Detection de la manette.
- Lecture des axes et boutons.
- Conversion en intentions de jeu.

Les intentions de jeu doivent etre des types simples que le moteur peut consommer sans dependre de GameController.

## EngineCore

`EngineCore` sera un Swift Package local a la racine du repo.

Responsabilites:

- Generation procedurale.
- Gestion des chunks.
- Coordonnees monde, positions et hauteurs.
- Simulation et regles de gameplay.
- Types purs testables.

Contraintes:

- Ne doit pas importer SwiftUI.
- Ne doit pas importer RealityKit.
- Ne doit pas dependre du cycle de vie macOS.
- Doit etre testable par des tests unitaires rapides.

## Flux de donnees

```text
Controller / clavier
        ↓
Intentions d'input
        ↓
WorldRuntime
        ↓
Simulation joueur / camera / streaming
        ↓
FXFrameState / FXRecipe
        ↓
IsoAudioEngine / AudioRecipeResolver
        ↓
RenderSnapshotBuilder
        ↓
RenderWorldSnapshot
        ↓
Metal
```

## Build

La compilation doit toujours passer par:

```sh
./scripts/xcodebuild-safe.sh -project IsoWorldPOC/IsoWorldPOC.xcodeproj -scheme IsoWorldPOC -destination 'platform=macOS' build
```
