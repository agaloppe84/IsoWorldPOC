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

## Step 17 livre

Step 17 ajoute la base animation/contact terrain V1:

- `EngineCore/Animation` contient `AnimationSkeleton`, `Pose`, `AnimationClip`, `AnimationSampler`, `CharacterMotor`, `ContactPatch`, `FootIKSolver`, `FootstepEvent` et `SurfaceContactResolver`.
- Le sampler fournit idle/walk humanoides simples, pose interpolatee, root motion de cycle et poids de pieds plantes.
- `SurfaceContactResolver` derive friction, wetness, compliance, tags et stabilite depuis `TerrainSample`, materiau, eau et `TraversalSurfaceClass`.
- `CharacterMotor` expose le contrat capsule/friction/slope/step-up sans dependre du renderer.
- `FootIKSolver` ajuste la cible pied, verrouille les appuis, compense le bassin et ajoute une clearance simple pour petits obstacles.
- `FootstepEventEmitter` produit des events materiau-aware pour les futurs audio/FX/decals.
- Le runtime conserve maintenant `TerrainSampleGrid` par chunk, cree des `ContactPatch` depuis le terrain prepare et met a jour l'etat animation joueur.

Cette passe ne rend pas encore un mesh skinned anime. Elle pose les sorties moteur necessaires pour brancher rendu personnage, audio de pas, FX de contact et debug animation.

## Step 18 livre

Step 18 ajoute les FX V1 data-driven:

- `EngineCore/FX` contient `FXDefinition`, `FXEvent`, `FXContext`, `FXRecipe` et `FXBudget`.
- Les definitions V1 couvrent sprites billboards, bursts simples, courbes couleur/taille/lifetime, poussiere de pas, splash de pas, sparks d'impact et decals de footprint.
- `FXRecipe` consomme les vrais `FootstepEvent`, `TerrainMaterialKind`, wetness, friction et seed monde pour produire des events deterministes.
- `FXFrameState` garde les particules/decals actifs sur leur duree de vie au lieu de les afficher une seule frame.
- `RenderWorldSnapshot` transporte un `FXFrameSnapshot`, donc le renderer consomme le pipeline V1 sans recalculer les contacts.
- `FrameGraph` ajoute `DecalPass` et `BillboardParticlePass` entre opaque et debug overlay.
- Le pipeline Metal active l'alpha blending et dessine une premiere version legere des billboards/decals avec les shaders existants.
- `SeedDomain.fx` et `GeneratorVersionTable.current` versionnent le domaine FX.

Cette passe reste volontairement simple cote GPU: pas encore de compute particles, atlas sprite dedie, instancing ou decal projection avancee. La base est propre, budgetee et testee pour pouvoir evoluer.

## Step 19 livre

Step 19 ajoute l'audio V1 procedural et parametrable:

- `EngineCore/Audio` contient les contrats purs `IsoAudioEvent`, `AudioContext`, `AudioRecipe`, `AudioBus`, `AudioParameterSet` et `AudioSurfaceResponse`.
- Les bus V1 couvrent `master`, `music`, `ambience`, `foley`, `world` et `ui`, avec calcul de gain effectif via le parent master.
- `AudioRecipeResolver` consomme les vrais `FootstepEvent` Step 17 et choisit une recette de pas par `TerrainMaterialKind`.
- Les surfaces audio derivent gain, pitch, durete, rugosite, porosite, crunch, splash et squish depuis materiau, wetness et friction.
- `AudioRuntime` contient `IsoAudioEngine`, `AudioEventQueue`, `SamplePlayer` et `NoiseSynth`.
- Le runtime audio est deterministe: queue priorisee, RNG stable par seed contexte, sample player procedural de fallback et noise synth simple.
- `WorldRuntime` poste les footsteps recents vers l'audio apres les FX, sans recalculer les contacts terrain.
- Les debug meters existent sous forme de `AudioRuntimeSnapshot` et `AudioBusMeter`, mais ne sont pas ajoutes au panel compact pour ne pas recharger l'overlay debug.
- `SeedDomain.audio` et `GeneratorVersionTable.current` versionnent le domaine audio.

Cette passe ne branche pas encore de sortie audio systeme. Le but est d'abord de verrouiller le pipeline data-driven, testable et non bloquant; la lecture bas niveau pourra etre ajoutee ensuite sans changer les contrats EngineCore.

## Step 20 livre

Step 20 ajoute le HUD/UI procedural minimal V1 en gardant SwiftUI hors de la boucle de rendu in-game:

- `EngineCore/UIModel` contient `UIFrameSnapshot`, `UIWorldDNA`, `UIToken`, `UITheme` et `HUDState`.
- Le domaine `.ui` est versionne dans `GeneratorVersionTable.current` et le theme UI est deterministe par seed monde.
- Trois themes V1 existent: `neutral`, `parchment` et `sci-fi`.
- `WorldRuntime` fabrique un `UIFrameSnapshot` depuis le joueur, le biome, la meteo simple et les affordances terrain.
- `RenderWorldSnapshot` transporte le snapshot UI sans importer SwiftUI ni Metal.
- `FrameGraph` active `HUDOverlayPass` seulement quand le HUD est visible et que le drawable a une taille valide.
- `MetalRenderer/UI` contient les draw commands, un atlas icone 5x5, un label renderer bitmap et `UIMetalRenderer`.
- Le HUD Metal minimal dessine panel, label, icone et progress bar en batch quads.

Cette passe garde SwiftUI pour les menus, tools et overlay debug. Le HUD du vrai monde passe par Metal pour eviter de recharger le rendu in-game avec des publications SwiftUI haute frequence.

## Step 21 livre

Step 21 remplace l'ancien RPG DNA minimal par une vraie constitution RPG deterministe du monde:

- `EngineCore/RPG` contient `WorldRPGDNA`, `WorldRuleset`, `GameplayTag`, `RPGArchetype`, `WorldObjective`, `FactionDefinition`, `QuestSeed` et `WorldStateLedger`.
- `WorldDNA.rpg` pointe maintenant vers le contrat V1 riche, plus vers un trio `historySeed/factionSeed/dangerBias` isole dans `WorldDNA.swift`.
- Les domaines `rpg.dna`, `rpg.rules`, `rpg.factions`, `rpg.objectives`, `rpg.quests` et `rpg.ledger` sont versionnes dans `GeneratorVersionTable.current`.
- Le seed choisit archetype, epoque, niveau tech, magie, menace, presence ennemie, objectif global, progression, tonalite et axes de densite.
- `WorldRuleset` transforme le DNA en systemes actifs, politique de violence, objectif primaire, factions et quest seeds.
- Le debug print du monde existe via `debugSummary` sur `WorldRPGDNA` et `WorldRuleset`.
- `WorldStateLedger` stocke les faits significatifs et compactables sans persister le monde entier.
- Les tests EngineCore valident 20 seeds de reference RPG jouables, determinisme, versioning, roundtrip Codable, mondes sans ennemis et ledger.

Cette passe ne genere pas encore villages, settlements, NPCs, storylets runtime ou directeur narratif actif. Elle pose les contrats purs pour que les prochains systemes consomment la constitution RPG au lieu d'inventer leurs propres regles.

## Step 22 livre

Step 22 ajoute les buildings/settlements V1 comme pipeline EngineCore pur et deterministe:

- `EngineCore/Settlements` contient `StructureRecipe`, `SettlementRecipe`, `BuildingIntent`, `FootprintGenerator`, `MassingGenerator`, `TerrainSupportMap`, `SettlementSiteSelector` et `SettlementSystem`.
- Les domaines `settlements`, `settlements.recipes`, `settlements.sites`, `settlements.building-intents`, `settlements.footprints` et `settlements.massing` sont versionnes dans `GeneratorVersionTable.current`.
- `SettlementRecipe` consomme le `WorldRuleset` et le biome dominant pour choisir camp, hamlet, trade post, shrine cluster, frontier outpost, farmstead ou ruin cluster.
- `TerrainSupportMap` derive pente, rugosite, eau, walkability, biome dominant, ratio buildable et solutions de support depuis `TerrainSampleGrid`.
- `SettlementSiteSelector` score les sites depuis support terrain, eau, biome, trade/defense needs et tags RPG.
- `BuildingIntent` separe l'intention gameplay de la generation visuelle: fonction, recette, importance, storeys, tags et ancre locale.
- `FootprintGenerator` produit footprints orientes avec ajustements de fondation sans modifier ni aplatir le terrain.
- `MassingGenerator` produit des volumes simples, supports V1, materiaux biome et `StructureRenderInstance` instanciables via les primitives de geometry existantes.
- `SettlementSystem` assemble site, buildings, chemins simples, massings et instances render dans un `SettlementPlan` validable.
- Les tests EngineCore ajoutent 8 cas couvrant determinisme/Codable, support terrain, selection de site, footprints, massing/render, influence RPG, versioning et seeds de reference.

Cette passe ne branche pas encore les settlements dans le runtime monde visible ni dans le renderer Metal app. Elle pose le contrat complet et testable que Step 33 pourra enrichir avec districts, routes avancees, interiors, NPCs et streaming monde.

## Step 23 livre

Step 23 ajoute la sauvegarde avancee V2 comme contrats EngineCore purs, sans brancher encore un stockage lourd:

- `EngineCore/Persistence` contient maintenant dirty tracking, region deltas, entity persistence, event journal, snapshot store, migration manager et packages outils/assets/graphs.
- `SaveVersion.current` passe en `format-1.schema-2` pour marquer l'arrivee des deltas regionaux et des packages V2.
- `DirtyTracker` groupe les chunks sales par region, systeme et raison, avec ticks de premiere/derniere modification.
- `RegionDeltaStore` produit des fichiers `regions/r.x.y.z.isoregion` contenant deltas terrain, props, settlements et references d'entites persistantes.
- `EntityStateStore` conserve les entites vivantes et les tombstones de suppression afin que les removals soient persistables.
- `EventJournal` trace les evenements save/autosave/snapshot/migration de maniere ordonnee et compactable.
- `SnapshotStore` cree des manifests de snapshots incrementaux et applique une retention simple par raison.
- `MigrationManager` planifie la migration schema 1 vers schema 2 avec modes strict, migrated et regenerated.
- `GraphPackage`, `AssetPackage` et `ToolProjectPackage` posent les formats `.isograph`, `.isoasset` et `.isoproj` pour les outils V1/V2.
- Les tests EngineCore couvrent merge de deltas, dirty tracking, entites supprimees, journal, snapshots, migration et packages.

Cette passe ne fait pas encore d'autosave disque complete, de WAL, de SQLite ni de writer incremental branche au runtime. Elle pose le format propre pour que les prochains outils et la future autosave consomment la vraie architecture V1/V2 au lieu de serializer des caches de rendu.

## Step 24-A livre

Step 24-A ouvre la V2 avec un Tools Hub production spine au-dessus des packages Step 23:

- `ToolRegistry.v2` expose les 15 outils production prevus par le Step 24.
- `ToolWorkspace` garde les documents par outil, la selection, les recents, le dirty state, les snapshots de revision et le diagnostic export.
- `ToolSession` porte un workspace outils sans creer de `WorldSession`.
- `ToolsHubView` consomme le workspace V2: categories, outils, commandes, indicateur unsaved, recents, validation et resume persistence.
- `ToolDocumentStore` convertit un document outil vers `ToolProjectPackage`, `GraphPackage` et `AssetPackage`, puis ouvre/sauvegarde `.isoproj`, `.isograph` et `.isoasset`.
- `ToolValidationIssue` porte maintenant des fix hints et la validation signale les references package invalides.
- Les tests app couvrent registry V2, workspace dirty/recent/diagnostic et roundtrip des packages Step 24.

Cette passe ne livre pas encore les vrais editeurs specialises. Les 15 outils disposent d'une surface, d'un document, d'une preview generique, d'une validation et d'une policy package-backed; Step 24-B doit maintenant remplacer les surfaces generiques par les inspectors/editors metier.

## Step 24-B livre

Step 24-B remplace une partie des previews generiques du Tools Hub V2 par des rapports specialises branches sur les contrats reels du moteur:

- `ToolSpecializedPreviewReport` decrit des sections/metriques stables, codables et testables.
- Terrain Recipe Editor expose le `TerrainFeatureGraph`, les compteurs hydrologie/relief et la query du chunk origine.
- Biome Graph Viewer expose biomes, sub-biomes, ecotones, materiaux lies et densite props.
- Prop Gallery expose le catalogue naturel, les types supportes, regles de placement et budgets d'echantillonnage.
- Material Viewer expose les slots materiaux terrain, roles PBR, surfaces triplanar et hooks `SurfaceState`.
- LOD Debugger expose thresholds, budgets draw calls et marge d'hysteresis.
- Save Inspector expose les chemins `.isoproj`, `.isograph`, `.isoasset`, validation package et export runtime.
- Seed Gallery expose le corpus `GoldenWorldSeeds`, le seed courant et la derivation preview.
- `ToolsHubView` affiche ces rapports sous la preview isolee, avec un workspace central scrollable.
- Les tests app couvrent la couverture des outils prioritaires, le terrain feature graph, les packages Step 23 et le corpus de seeds.

Cette passe ne livre pas encore des editeurs interactifs complets. Elle etablit la base metier fiable pour les inspectors/editors de Step 24-C et garde les autres outils en fallback generique explicite.

## Step 24-C livre

Step 24-C complete la couverture specialisee du Tools Hub V2:

- Character Customization Lab expose `CharacterDNA`, body parameters, skeleton/sockets, equipment, mesh descriptor et save regenerable.
- Animation Contact Lab expose clips idle/walk, root motion, contact windows, Foot IK et profils de surface.
- FX Preview Editor expose definitions V1, types billboard/decal, blend modes et budgets temps reel.
- Audio Graph Preview expose recipes, renderers, bus et mix state par defaut.
- RPG World DNA Browser expose archetype, era, magie, menace, systems actifs, factions, quests et validation jouable.
- Settlement Viewer expose une recette de settlement derivee de `WorldRuleset` et biome preview, sans generer de chunk terrain.
- Performance HUD expose cadence debug/live, throttling telemetry, budgets LOD/FX et defaults de debug visuel.
- Snapshot Diff expose preview ID, revision, references et policy de retention snapshots.
- `ToolGoldenSeedValidationRunner` valide le corpus `GoldenWorldSeeds` sur terrain, personnages, animation, FX, audio, RPG, settlements et LOD.
- La validation du document Seed Gallery branche ce runner et remonte un `ToolValidationIssue` dedie.
- Les tests app couvrent tous les rapports Step 24, les contrats restants et le runner golden seeds.

Cette passe reste une couche inspector/rapport. Les vrais controles d'edition profonde, les graph editors et les previews visuelles dediees devront s'appuyer sur ces contrats au lieu de contourner le workspace.

## Step 24-BIS livre

Step 24-BIS branche une premiere tranche du spine persistence production au-dessus des contrats Step 23:

- `PersistenceRegistry.productionV2` declare les domaines de sauvegarde: manifest, regions, event journal, snapshots, entites, packages outils/assets/graphs, blobs, index SQLite rebuildable et caches generes.
- `RegionDeltaFileStore` lit/ecrit les fichiers `regions/r.x.y.z.isoregion` via `AtomicFileWriter`, avec validation format, region et seed.
- `SaveCoordinator` devient l'acteur d'orchestration: regions d'abord, journal/snapshots ensuite, puis `manifest.json` comme point de commit.
- Le save manuel avance la generation, persiste les regions sales disponibles, journalise les regions ecrites et cree un snapshot.
- L'autosave incremental applique un debounce et un budget de regions par passe, sans masquer les deltas encore non ecrits.
- `DirtyTracker.markSaved(_:)` sait marquer uniquement un scope ecrit, ce qui evite qu'un autosave partiel efface virtuellement des regions en attente.
- `SaveFilesManifest` reference maintenant les chemins production V2 (`regions`, `events/journal.json`, `snapshots`).
- Les tests EngineCore couvrent registry, roundtrip `.isoregion`, transaction manuelle, autosave debounce/budget et dirty scope partiel.

Cette passe ne branche pas encore le runtime World reel sur `SaveCoordinator`. Elle ne livre pas non plus `state.sqlite`, WAL, CAS blob store, crash injection/recovery ni le Save Inspector connecte aux donnees de save reelles. Ces sujets restent le prochain bloc persistence avant les gros pipelines V2 suivants.

## Step 24-BIS-B livre

Step 24-BIS-B durcit la persistence production avec les briques disque robustes manquantes:

- `CSQLite` ajoute un pont SwiftPM/Xcode vers `sqlite3` sans pousser SQLite dans l'app.
- `SQLiteStateIndexStore` cree `state.sqlite`, active WAL, execute les writes dans une transaction et indexe metadata, regions, events, snapshots, entities et blobs.
- `CASBlobStore` ecrit les payloads lourds par adresse de contenu stable dans `blobs/*/*.blob` et maintient `blobs/manifest.json`.
- `SaveCoordinator` ecrit maintenant le manifest CAS et l'index SQLite avant `manifest.json`; le manifest reste le point de commit final.
- `SaveCrashInjectionPoint` permet d'injecter un crash apres regions ou avant commit manifest pour tester recovery.
- `SaveRecoveryScanner` detecte les fichiers region/snapshot et les artefacts support SQLite/journal/index plus recents que le manifest committe, puis peut nettoyer ces artefacts non commit.
- `SaveInspector` lit un dossier de save reel et expose status, generation, compteurs regions/events/snapshots/blobs, WAL et recovery.
- Le Tools Hub Save Inspector accepte une reference `saveRoot:/chemin` et affiche les vraies donnees du dossier de save quand elle est disponible, avec fallback preview contractuel.
- `MigrationLab` lance un corpus de samples contre `MigrationManager` pour garder la migration visible et testable.
- Les tests EngineCore couvrent CAS, SQLite/WAL, crash/recovery, migration lab et coordinator enrichi; le build Xcode `build-for-testing` compile app + tests sans lancer l'UI Debug.

Cette passe ne branche pas encore le vrai `WorldRuntime` sur le save/load complet. Les contrats disque sont prets, mais il manque l'integration gameplay: collecter les deltas runtime reels, charger un slot, appliquer les deltas terrain/props/entities et valider un roundtrip monde visible.

## Step 24-BIS-C livre

Step 24-BIS-C branche la persistence sur le vrai runtime World:

- `EntityStateFileStore` ajoute `entities/state.isoentity` comme source autoritative des entites persistantes, separee de l'index SQLite rebuildable.
- `SaveFilesManifest` et `PersistenceRegistry.productionV2` declarent maintenant le fichier entites.
- `SaveCoordinator` ecrit l'etat entites, les regions, le CAS, les snapshots, le journal et `state.sqlite` avant le commit `manifest.json`.
- `SaveRecoveryScanner` peut nettoyer `entities/state.isoentity` si le fichier est en avance sur le manifest committe.
- `WorldRuntime` expose une capture persistence issue du vrai runtime: seed texte, `WorldDNA`, position/camera joueur, entite joueur, chunk courant, chunks actifs/visibles, dirty scope et region delta.
- `WorldRuntimeSaveService` sauvegarde un runtime vivant vers un dossier de slot, ecrit un blob CAS de receipt runtime, inspecte le resultat, puis recharge manifest + regions + entites + blobs en `WorldSession` restaurable.
- `RealWorldView` possede un bouton Save branche sur le `WorldRuntime` rendu par Metal via `WorldRuntimeHandle`; ce n'est plus une save theorique de menu.
- Le test app `worldRuntimeSaveServiceRoundTripsVisibleWorldFromDisk` prouve le roundtrip visible: runtime prepare, save disque, load disque, nouveau `WorldRuntime`, snapshot sans chunk bounds et chunk visible.

Limite volontaire: le gameplay courant ne modifie pas encore terrain/props en jeu. Le step prepare et transporte les region deltas, mais l'application de mutations terrain/props avancees restera a brancher quand les outils ou systemes gameplay produiront ces deltas en runtime.

## Prochaine cible

Step 25 peut demarrer sur les surfaces/lighting V2. En parallele, une future tranche persistence devra etendre le runtime aux mutations terrain/props editables quand les systemes producteurs existent.
