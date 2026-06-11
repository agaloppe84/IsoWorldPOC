# Baseline moteur V1

Ce document fixe la base active apres le Step 9-BIS. Il ne remplace pas les docs de recherche dans `docs/IsoWorld-Research-Lab/`; ces fichiers restent la vision long terme.

## Objectif

Construire la V1 sur un pipeline unique, testable et lisible:

```text
EngineCore data contracts
    -> WorldRuntime / RenderSnapshotBuilder
    -> RenderWorldSnapshot
    -> Metal buffers
    -> terrain PBR preview pipeline
```

Le code actif ne doit plus adapter ses noms, alias ou tests a l'ancien pipeline. Les compatibilites temporaires doivent etre retirees avant d'ajouter de nouvelles couches moteur.

## Contrats actifs

- `BiomeType` contient uniquement les biomes V1: `temperateForest`, `grassland`, `desert`, `mountain`, `marsh`, `taiga`, `coast`, `freshwater`.
- `TerrainMaterialKind` contient les materiaux terrain V1: `grass`, `rock`, `dirt`, `sand`, `mud`, `snow`.
- `PropType` contient les types de props V1: `rock`, `pebble`, `grass`, `tree`, `deadwood`, `crystal`.
- `StableRNG` est le generateur deterministe public du moteur.
- `LODPolicy` et `LODSelection` decrivent la visibilite et le niveau de detail des chunks avant upload GPU.
- `PropSystem` decrit les props naturels V1 depuis terrain, biome, seed, catalogue et regles de placement.
- `RenderWorldSnapshot` transporte les donnees neutres consommees par le renderer, sans dependance Metal ni option debug non consommee.
- `TerrainTextureCatalog.makePreview` genere les texture arrays temporaires de preview pour valider le pipeline PBR.

## Regles de hygiene

- Ne pas reintroduire d'alias legacy dans `EngineCore`.
- Ne pas ajouter de regle hardcodee cote renderer pour compenser un contrat moteur flou.
- Garder `EngineCore` independant de SwiftUI, RealityKit et Metal.
- Les tests doivent viser les contrats V1, pas les anciens noms.
- Les nouvelles metriques debug doivent avoir un consommateur clair dans l'overlay ou dans un snapshot.

## Plan d'action avant Step 10

- Verifier que les tests EngineCore couvrent les contrats V1 critiques.
- Verifier que le build et les tests Xcode passent via les wrappers safe.
- Garder l'overlay debug court: perf, jobs chunks, rendu Metal et position joueur.
- Ajouter les prochains travaux LOD au-dessus de `RenderWorldSnapshot` et des donnees chunk existantes, sans creer un chemin de rendu parallele.

## Step 10 livre

Step 10 introduit un LOD terrain/chunks baseline en gardant le meme flux:

```text
chunk data V1 -> snapshot V1 -> upload GPU -> passes Metal
```

La selection LOD reste deterministe et testable dans `EngineCore`. Le streamer applique un budget de chunks visibles et de props rendus, le snapshot transporte la selection, le renderer upload uniquement les chunks visibles et l'index buffer terrain suit le niveau LOD choisi.

## Step 11 livre

Step 11 ajoute les props naturels simples au-dessus du budget LOD:

- `EngineCore/Props` porte `PropSystem`, `PropCatalog`, `PropContext`, `PropPlacementRule`, `PropRecipe`, `PropVariantGenome` et `PropChunkData`.
- `PropCatalog.naturalV1` couvre rochers, cailloux, herbes, arbres, bois mort et cristaux.
- Le placement utilise biome, slope, moisture et walkability depuis `TerrainSampleGrid`.
- Les IDs de props sont stables via `StableID.prop`.
- Le renderer Metal bake `box`, `capsule` et `cone` dans le buffer props du chunk existant.

La V1 ne cree pas encore de GPU instancing dedie, d'imposteurs, de prop LOD par instance ou de debug placement interactif.

## Prochaine cible

## Step 12 livre

Step 12 remplace le loading cosmetique par un `WorldPreparePipeline` reel:

- `GameRuntime/WorldPrepare` contient `WorldPrepareRequest`, `WorldPreparePhase`, `LoadingProgress`, `WorldOpenRequirements` et `WorldPreparePipeline`.
- Le pipeline normalise le seed, genere `WorldDNA`, initialise les regles V1 et prepare terrain/biomes autour du spawn.
- Le spawn joueur est resolu depuis les samples terrain/biome.
- Les chunks initiaux sont generes avant ouverture avec le `WorldSeed` de la session.
- `WorldSession` transporte seed, `WorldDNA`, spawn, chunks initiaux et exigences d'ouverture.
- `WorldRuntime` et `ChunkDataStreamer` demarrent depuis la session preparee au lieu de refaire un demarrage froid avec le seed debug.
- La progression de loading est determinee par phases ponderees et l'annulation reste cooperative.

La V1 ne precompile pas encore les pipelines GPU Metal hors renderer. Le warmup Step 12 valide les payloads CPU critiques avant premiere frame.

## Step 12-BIS livre

Step 12-BIS ajoute une baseline performance et separe clairement le vrai monde du monde debug:

- Le mode `realWorld` demarre en cadence live gameplay mais sans bounds de chunks ni badge debug de seed.
- Le mode `debugWorld` garde les bounds de chunks et expose des toggles d'isolation: terrain, props, player, bounds, freeze simulation, freeze streaming et LOD force.
- `WorldRuntime`, `RenderSnapshotBuilder`, `RenderWorldSnapshot`, `RenderPayloadUploader`, `FrameGraph` et les passes Metal consomment tous les memes options V1.
- Les metriques debug se concentrent sur les couts utiles: simulation, snapshot, sync buffers, encode render, indices visibles et estimation memoire CPU/GPU.
- Les buffers chunks peuvent etre liberes quand seuls le player ou les couches non-chunk sont rendus.

Cette etape ne corrige pas encore toutes les causes possibles de chute FPS. Elle donne un banc d'isolation propre pour identifier si le cout vient de la simulation, du snapshot, du streaming chunks, des buffers GPU, du terrain, des props ou de l'overlay debug.

## Step 12-TER livre

Step 12-TER affine le diagnostic performance quand le FPS chute sans que les draw calls Metal soient couteux:

- `MetalRenderer` mesure maintenant l'intervalle brut entre callbacks MTKView, le cout total de `draw(in:)`, le gap de scheduling, le cout de publication des metriques et le temps de draw non explique.
- `RenderSnapshotBuilder` expose le detail du snapshot: lecture des chunks actifs, conversion des chunks, conversion props et sampling terrain des props.
- Le toggle `pause metrics publish` permet de figer les `@Published` pour confirmer ou eliminer SwiftUI/ObservableObject comme cause de chute FPS.
- `render props` coupe aussi la construction des props dans le snapshot, pas uniquement leur draw Metal.

Les mesures doivent etre lues ainsi: si `frame raw` reste haut mais `draw` reste bas, le probleme est hors travail renderer direct. Si `publish` fait chuter le FPS, la priorite devient decoupler les metriques de SwiftUI. Si `snapshot props/sample` est haut, la priorite devient cache/eviter la reconstruction des props par frame.

## Step 12-QUATER livre

Step 12-QUATER decouple la telemetry SwiftUI du renderer:

- `DebugMetrics` garde les controles debug en `@Published`, mais les valeurs haute frequence deviennent des champs de staging non publies.
- `DebugTelemetry` capture un snapshot equatable des valeurs affichees par l'overlay.
- `MetalRenderer` met a jour les champs de staging pendant la frame, puis publie une seule telemetry a la fin de `updateDebugMetrics()`.
- `DebugOverlayView` lit `metrics.telemetry` pour l'affichage et conserve les bindings uniquement pour les controles utilisateur.
- `WorldRuntime` ne republie plus les controles de materiaux debug depuis le snapshot.

Le toggle `pause metrics publish` reste disponible comme coupe-circuit de diagnostic, mais il ne doit plus etre necessaire pour retrouver une cadence fluide en usage debug normal.

## Step 12-QUINQUIES livre

Step 12-QUINQUIES corrige le cout restant de publication observe dans Xcode:

- La telemetry vit dans `DebugTelemetryStore`, separe de `DebugMetrics`.
- `GameRootView` et `MetalGameView` ne sont plus invalides par les updates de chiffres debug.
- `DebugOverlayView` separe les controles interactifs des blocs texte de telemetry.
- Les lignes dynamiques FPS/player/chunks sont rendues en blocs monospaced compacts au lieu de dizaines de `Text` SwiftUI independants.

Le but est que `pause metrics publish` redevienne un outil de diagnostic, pas une condition necessaire pour obtenir une cadence correcte.

## Step 12-SNAPSHOT-CACHE livre

Step 12-SNAPSHOT-CACHE reduit le cout commun Debug World / Real World quand le snapshot runtime est reconstruit a chaque frame:

- `RenderSnapshotBuilder` conserve un cache de `RenderChunk` par coordonnee tant que la signature de rendu reste stable.
- Le snapshot ne transporte plus les chunks invisibles; le renderer travaille deja sur les chunks visibles.
- Les props ne sont plus converties pour les chunks invisibles ou quand `render props` est desactive.
- Le cache est invalide par les changements qui affectent le payload: etat debug chunk, visibilite, niveau LOD, props rendues et chunk bounds.

Cette passe cible le cout `snapshot chunks/props` visible dans le panel. Elle ne remplace pas un profil Instruments si la cadence Real World reste basse apres cache, mais elle retire une reconstruction CPU inutile du pipeline V1.

## Step 12-FRAME-DRIVER livre

Step 12-FRAME-DRIVER traite la cadence MTKView/SwiftUI observee quand `draw(in:)` reste peu couteux mais que `frame raw` et `gap` montent:

- Le vrai World ne publie plus de telemetry debug. Il garde les controles de rendu internes necessaires, mais n'envoie plus d'updates `ObservableObject` haute frequence.
- `DebugCadenceController` pilote explicitement les frames: la `MTKView` reste pausee et les modes continus planifient des draws via un driver controle.
- Les redraws demandes par le clavier, les changements de view ou les controles debug passent par la meme file de scheduling pour eviter les dessins synchrones pendant les updates SwiftUI.
- Le mode Debug conserve le panel et le toggle `pause metrics publish`; le mode Real World doit rester le vrai jeu, sans outil debug visible ni publication debug.

Le signal attendu apres cette passe: en Real World, la cadence ne doit plus dependre du panel debug; en Debug World, `draw` doit rester bas et le `gap` doit se rapprocher de la cadence choisie quand la publication telemetry ne bloque pas SwiftUI.

## Step 12-DEBUG-LEAN livre

Step 12-DEBUG-LEAN reduit le cout propre au panneau Debug World:

- Le panel debug demarre en mode compact et masque les details joueur/chunks tant que `details` n'est pas active.
- La publication telemetry debug est limitee a 2 Hz en live/slow, et a 1 Hz en benchmark.
- Les chunk bounds sont desactives par defaut; ils restent disponibles via le toggle.
- Les donnees longues de snapshot, memoire, textures et chunks restent consultables, mais ne sont plus layout a chaque refresh compact.

Le Debug World doit maintenant etre un outil de diagnostic leger par defaut. Les modes detailles restent assumement plus couteux et doivent servir aux investigations ponctuelles.

## Step 13 livre

Step 13 ouvre le `Tools Hub` minimal comme surface isolee du vrai monde:

- `ToolingUI` contient `ToolDescriptor`, `ToolDocument`, `ToolRegistry`, `ToolPreviewView`, `ToolValidationPanel` et la vue hub SwiftUI.
- Le registry V1 expose six outils initiaux: Terrain Viewer, Biome Viewer, Prop Gallery, Material Viewer, LOD Debugger et Seed Explorer.
- Chaque preview produit un `ToolPreviewSnapshot` deterministe depuis le seed texte et les parametres du document.
- Les previews n'ouvrent pas de `WorldSession`, ne mutent pas `WorldRuntime` et ne demarrent pas le renderer monde.
- `AppStore` garde une `ToolSession` separee pour le hub, afin que les transitions app restent explicites.

La V1 ne branche pas encore de preview Metal dediee dans les outils. Le hub fournit le shell data-driven, les documents et la validation necessaires avant d'ajouter des previews specialisees.

## Step 14 livre

Step 14 remplace le terrain purement bruite par un premier `TerrainFeatureGraph` V1:

- `EngineCore/Terrain/Features` contient les contrats `TerrainFeature`, `TerrainFeatureGraph`, `RiverFeature`, `LakeFeature`, `MountainRangeFeature` et `CliffBandFeature`.
- Le graph est deterministe par `WorldSeed` et expose une query par chunk via `features(intersecting:)`.
- `DefaultTerrainFieldProvider` applique les contributions du graph avant de produire les samples terrain.
- Les samples transportent maintenant `waterDepth` et `TerrainFeatureMasks` pour eau, berge, montagne et falaise.
- Les rivieres/lacs creusent le terrain, les montagnes relevent les ranges, les falaises ajoutent une marche locale, et les masques influencent humidite, walkability/climbability et splats de materiaux shore.
- `TerrainValidationReport` expose `waterCoverage` et `shoreCoverage`.

Cette passe ne rend pas encore de mesh d'eau dedie. L'eau V1 est un contrat de generation et de material masks, pret pour debug/renderer/gameplay dans les prochains steps.

## Step 15 livre

Step 15 ajoute la premiere couche de verticalite gameplay V1 au-dessus du terrain feature-driven:

- `EngineCore/Traversal` contient les types purs `TraversalSurfaceClass`, `TraversalChunkData`, `ClimbabilityMap`, `VerticalTraversalCandidate`, `RopeAnchorCandidate`, `StairAttachCandidate` et `LedgeCandidate`.
- Chaque chunk derive une classification `walkable`, `steep`, `climbable`, `dangerous`, `blocked` depuis slope, waterDepth, feature masks, walkability et climbability.
- Les ledges, anchors de corde, attaches d'escalier et routes verticales candidates sont generes deterministiquement depuis `TerrainSampleGrid`.
- `TerrainSystem` expose `traversalData(for:)`; `ProceduralChunkDataFactory` transporte cette data dans le chunk runtime.
- Le grounding joueur consomme la classe traversal quand elle existe, avec fallback pente pour rester robuste.
- Les debug layers terrain exposent `traversalSurface` et `ledgeScore`; `TerrainValidationReport` resume le ratio blocked et le nombre de candidats.

Cette passe ne cree pas encore de mesh de corde/escalier ni de mode escalade joueur complet. Elle pose le contrat moteur V1 pour que ces features puissent etre ajoutees sans hardcoder les regles dans le renderer ou le player.

## Step 16 livre

Step 16 ajoute la base personnage procedurale V1 dans `EngineCore/Characters`:

- `CharacterDNA` devient le contrat racine deterministe pour un personnage genere par seed/version.
- `CharacterBodyParameters` expose morphologie, skeleton humanoide canonique, sockets, capsule collision et vitesse naturelle.
- `CharacterAppearance` porte les sliders visage, couleurs et materiaux PBR peau/cheveux.
- `EquipmentSlot`, `WearableItem` et `CharacterEquipmentSet` decrivent les slots modulaires, sockets et conflit d'equipement.
- `CharacterRuntimeState` separe l'etat vivant/equipement courant de l'ADN regenerable.
- `CharacterCustomizationSave` rend la personnalisation sauvegardable sans persister de cache mesh genere.
- `PlayerProfile` peut porter une personnalisation personnage.
- `WorldRuntime` cree le personnage joueur depuis le `WorldSeed` de session et le `PlayerController` derive vitesse/capsule depuis cette DNA.

Cette passe ne rend pas encore un vrai mesh skinned ni des vetements modulaires GPU. Elle pose les contrats purs V1 pour animation, gameplay et sauvegarde.

## Prochaine cible

Step 17 peut brancher animation/contact terrain: locomotion minimale, stance runtime, camera/collision coherentes avec le corps et premiers hooks pour mesh skinned futur.
