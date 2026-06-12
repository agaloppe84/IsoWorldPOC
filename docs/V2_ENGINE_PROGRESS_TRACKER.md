# Tracker implementation moteur V2

Ce tracker suit l'avancement de la V2 a partir de l'etat post-Step 23.

Legende :

- `[ ]` a faire
- `[~]` en cours
- `[x]` livre
- `[!]` bloque ou risque ouvert

## Etat courant

| Element | Etat |
|---|---|
| Dernier step livre | Step 24-BIS - Persistence production spine core |
| Branche cible | `main` |
| Docs reference | lecture seule |
| Prochaine cible officielle | Step 24-BIS-B - SQLite/WAL/CAS/recovery + Save Inspector real data |
| Plan V2 | `[x]` document cree |
| Tracker V2 | `[x]` document cree |

## Regles de suivi

- Mettre a jour ce fichier a la fin de chaque Step V2.
- Ne pas cocher un item si le build ou les tests pertinents n'ont pas ete lances.
- Ajouter un "Risque ouvert" si une feature est livree avec dette volontaire.
- Garder les docs de reference `docs/IsoWorld-Research-Lab/` non modifiees.
- Les docs actives peuvent etre mises a jour : architecture, decisions, baseline, tracker, plan.

## Gates globaux

### Architecture

- [x] `EngineCore` reste sans SwiftUI.
- [x] `EngineCore` reste sans Metal sauf contrats renderer neutres existants.
- [ ] Les systems V2 consomment seed + versions + recipes + deltas.
- [ ] Les caches sont declares rebuildables.
- [x] Les docs actives indiquent les decisions structurantes.

### Performance

- [ ] Real World sans debug visible.
- [ ] Debug World compact par defaut.
- [ ] Metrics SwiftUI throttled.
- [ ] Pas de generation lourde sur MainActor.
- [ ] Budget CPU/GPU/memoire documente par systeme lourd.

### Persistence

- [~] Save/cache policy par nouveau systeme.
- [x] Packages outils versionnes.
- [x] Region deltas lisibles/ecrivables.
- [ ] SQLite/WAL introduit avec tests recovery.
- [ ] Migration corpus maintenu.

### Tooling

- [x] Chaque systeme majeur a un inspector ou viewer.
- [~] Chaque systeme majeur a un validator.
- [x] Seed gallery couvre les cas extremes.
- [x] Diagnostic bundle exportable.

### Validation

- [~] Tests determinisme par domaine.
- [ ] Tests seams terrain/biome/material.
- [ ] Tests save/load/migration.
- [ ] Tests budgets perf quand possible.
- [ ] Visual snapshots pour systems renderer/UI/FX critiques.

## Step 24 - Tools Hub production V2

Objectif : outils production pour modifier, valider et persister les systems.

### Core shell

- [x] Tool workspace production.
- [x] Navigation categories + recent projects.
- [~] Dirty state, close protection, unsaved indicator.
- [~] Command routing clavier/manette minimal.
- [x] Diagnostic export depuis Tools Hub.

### Persistence tools

- [x] `ToolDocumentStore`.
- [x] Open/save `.isoproj`.
- [x] Open/save `.isoasset`.
- [x] Open/save `.isograph`.
- [x] Autosave draft.
- [x] Revision snapshot.
- [x] Runtime export manifest.

### Shared validation

- [x] `ToolValidationIssue` avec severity.
- [x] Validation report UI.
- [x] Fix hints.
- [x] Package dependency validation.
- [x] Golden seed validation runner hook.

### Production tools

- [x] Terrain Recipe Editor.
- [x] Biome Graph Viewer.
- [x] Prop Gallery.
- [x] Material Viewer.
- [x] LOD Debugger.
- [x] Character Customization Lab.
- [x] Animation Contact Lab.
- [x] FX Preview Editor.
- [x] Audio Graph Preview.
- [x] RPG World DNA Browser.
- [x] Settlement Viewer.
- [x] Save Inspector.
- [x] Performance HUD.
- [x] Seed Gallery.
- [x] Snapshot Diff.

### Step 24 validation

- [x] Tools open without Real World.
- [x] Tool previews do not mutate `WorldRuntime`.
- [x] Priority specialized reports consume EngineCore/Persistence contracts.
- [x] Remaining specialized reports consume EngineCore/App contracts.
- [x] Golden seed runner validates reference corpus.
- [x] Package roundtrip tests.
- [ ] Validation UI tests where possible.
- [x] Build Xcode safe OK.

## Step 24-BIS - Persistence production spine

Objectif : brancher les contrats Step 23 dans une persistence robuste.

- [x] `SaveCoordinator` actor.
- [x] `PersistenceRegistry`.
- [x] Region file writer/reader.
- [x] Autosave incremental.
- [x] Manual save transaction path.
- [ ] `state.sqlite` experimental.
- [ ] WAL enabled.
- [x] Event journal persisted.
- [~] Snapshot compaction.
- [ ] CAS blob store.
- [ ] Migration lab.
- [ ] Save Inspector connected to real save data.
- [ ] Crash injection tests.
- [ ] Save/load world delta integration tests.
- [x] EngineCore persistence tests.
- [x] Build Xcode safe OK.

Notes:

- Tranche livree: spine core uniquement, sans branchement runtime World.
- `SaveCoordinator` ecrit regions, journal et snapshots avant `manifest.json`, qui reste le point de commit.
- L'autosave est debounce + budget de regions; `DirtyTracker.markSaved(_:)` garde visibles les deltas non ecrits.
- La retention `SnapshotStore` est appliquee a l'index, mais le nettoyage physique des anciens fichiers snapshot reste a durcir avec recovery/CAS.

## Step 25 - ISLP lighting/surfaces V2

Objectif : pipeline surface/lumiere/weather moderne sans RT.

### Materials

- [ ] `WorldRenderDNA`.
- [ ] Material palette per biome/RPG/world.
- [ ] `IsoMaterialRuntime`.
- [ ] Material parameter blocks.
- [ ] Texture set registry.
- [ ] baseColor/normal/ORM packing.
- [ ] Material LOD.
- [ ] Material graph package bridge.

### Terrain surfaces

- [ ] Terrain layered PBR.
- [ ] Height/slope/biome blending.
- [ ] Triplanar cliffs.
- [ ] Macro/micro variation.
- [ ] Detail normals.
- [ ] Debug baseColor/normal/roughness/splats.

### Lighting

- [ ] Tone mapping/exposure.
- [ ] IBL sky simple.
- [ ] CSM.
- [ ] Shadow atlas local.
- [ ] Forward+ or clustered lights.
- [ ] Light priority.
- [ ] Reflection probes.
- [ ] Chunk irradiance probes.

### Weather/surface states

- [ ] Wetness maps.
- [ ] Snow accumulation.
- [ ] Dust/sand.
- [ ] Moss/lichen.
- [ ] Water shader baseline.
- [ ] Fog/atmosphere baseline.

### Tools/validation

- [ ] Material Viewer production.
- [ ] Lighting sandbox.
- [ ] Texture residency debugger.
- [ ] Albedo/roughness/normal validators.
- [ ] Perf HUD integration.

## Step 26 - IVDS / LOD avance

Objectif : virtualisation progressive du detail.

- [ ] LOD orchestrator.
- [ ] HLOD chunks.
- [ ] HLOD props groups.
- [ ] HLOD settlement groups.
- [ ] Terrain quadtree/clipmap.
- [ ] Crack-free transitions.
- [ ] Foliage impostors.
- [ ] Meshlet/cluster data model.
- [ ] Cluster builder offline/procedural async.
- [ ] Hi-Z occlusion.
- [ ] Compute culling.
- [ ] Indirect command build.
- [ ] Geometry page cache.
- [ ] Root resident fallback.
- [ ] Page feedback.
- [ ] Mesh shader path capability detection.
- [ ] Fallback legacy cluster pipeline.
- [ ] IVDS debug overlay.
- [ ] Collision/render mismatch tests.

## Step 27 - Props avances et manufactures

Objectif : familles de props riches, contextuelles et interactives.

- [ ] Prop registry data-driven.
- [ ] JSON/YAML or Codable definitions.
- [ ] Scoring system.
- [ ] Hard constraints.
- [ ] Layer budgets.
- [ ] PropVariantGenome V2.
- [ ] Weathering masks.
- [ ] Biome overlays.
- [ ] Manufactured props.
- [ ] Shape grammar simple.
- [ ] Sockets.
- [ ] Compound collisions.
- [ ] Interactive states.
- [ ] Harvest/destruct/open deltas.
- [ ] Instancing by family.
- [ ] Prop LOD/impostors.
- [ ] WFC local objects.
- [ ] Prop Gallery production.
- [ ] Rule Debugger.
- [ ] Budget Viewer.

## Terrain/Biome V2 expansion track

Objectif : monde naturel multi-couche, ecotones et verticalite enrichie.

- [ ] `WorldBiomeDNA`.
- [ ] Biome definitions data-driven.
- [ ] Sub-biomes.
- [ ] Transition rules.
- [ ] Ecotone resolver.
- [ ] Micro-habitats.
- [ ] ClimateFieldProvider V2.
- [ ] GeoHydroFieldProvider V2.
- [ ] Terrain rule DSL.
- [ ] Hydrology corridors.
- [ ] Waterfalls simple.
- [ ] Terrain patches/SDF caves.
- [ ] Terrain validation report V2.
- [ ] Biome/terrain debug layers expanded.

## Step 28 - Animation avancee

Objectif : mouvement environnement-aware.

- [ ] ContactPatch V2.
- [ ] Surface filtering by foot size/gait.
- [ ] FootwearProfile.
- [ ] Effective friction/compliance.
- [ ] Footstep planner.
- [ ] Candidate scoring debug.
- [ ] Foot locking V2.
- [ ] Pelvis compensation V2.
- [ ] Slope warping.
- [ ] Stride scaling.
- [ ] Orientation warping.
- [ ] Support polygon.
- [ ] Fatigue/load.
- [ ] Slip/stumble.
- [ ] Climb mode.
- [ ] Hand IK.
- [ ] Rope/ladder/stair affordances.
- [ ] Motion warping.
- [ ] Motion matching V1.
- [ ] Partial active ragdoll.

## Step 29 - FX GPU avances

Objectif : IPFX compute-first, budgete et world-aware.

- [ ] FX graph data model.
- [ ] FX graph compiler.
- [ ] GPU spawn compute.
- [ ] GPU update compute.
- [ ] Alive/dead lists.
- [ ] Indirect draw args.
- [ ] Depth collision.
- [ ] Soft particles.
- [ ] Flipbooks.
- [ ] Ribbons/trails.
- [ ] Beams.
- [ ] Distortion.
- [ ] Low-res FX.
- [ ] Volumetric lite.
- [ ] Weather macro FX.
- [ ] Terrain/Material/Weather/RPG data interfaces.
- [ ] FX Director.
- [ ] Overdraw heatmap.
- [ ] FX profiler.

## Step 30 - Audio avance

Objectif : procedural audio engine world-aware.

- [ ] AVAudioEngine/CoreAudio backend.
- [ ] Audio graph nodes.
- [ ] Audio graph compiler.
- [ ] Procedural footstep synth.
- [ ] Footwear/wetness/mud/snow response.
- [ ] Biome ambience manager.
- [ ] Wind/rain/water synth.
- [ ] Rare ambience events.
- [ ] WorldMusicDNA.
- [ ] Harmony generator.
- [ ] Motif/arrangement director.
- [ ] Spatializer.
- [ ] Occlusion raycasts.
- [ ] Reverb zones.
- [ ] Acoustic materials.
- [ ] Modal impact synth.
- [ ] Creature voice synth.
- [ ] Audio Graph Preview.
- [ ] Voice/event profiler.

## Step 31 - Characters avances

Objectif : joueur/PNJ expressifs, persistants, compatibles crowds.

- [ ] Skinned mesh simple.
- [ ] GPU skinning.
- [ ] CharacterDNA V2.
- [ ] PNJ generation by seed.
- [ ] Culture/faction rules.
- [ ] Climate clothing rules.
- [ ] Hair cards.
- [ ] Scars/tattoos/dirt.
- [ ] Body morphs V2.
- [ ] Advanced eyes.
- [ ] Approx skin subsurface.
- [ ] Clothing refit.
- [ ] Shoes gameplay link.
- [ ] Injuries visible.
- [ ] Aging state.
- [ ] Prosthetics / missing limbs architecture.
- [ ] CharacterBuildCache.
- [ ] Crowd LOD.
- [ ] Settlement population generator hooks.

## Step 32 - RPG avance

Objectif : seed -> mondes jouables radicalement differents.

- [ ] WorldRPGDNA V2.
- [ ] Factions V2.
- [ ] Cultures.
- [ ] Resources/economy seeds.
- [ ] Territories.
- [ ] Storylets.
- [ ] Quest graph.
- [ ] Local narrative places.
- [ ] Rumors.
- [ ] Director tension.
- [ ] Pacing/cooldowns.
- [ ] Economy.
- [ ] Reputation.
- [ ] Professions.
- [ ] Knowledge/secrets.
- [ ] Myths/taboos.
- [ ] Multiple endgames.
- [ ] Player transformations.
- [ ] World DNA Inspector.
- [ ] Quest Graph Viewer.
- [ ] Storylet Debugger.
- [ ] Faction Simulator.
- [ ] Director Timeline.

## Step 33 - Settlements avances

Objectif : villes, villages et structures generes avec terrain/RPG/LOD.

- [ ] WorldArchitectureDNA.
- [ ] SettlementIntentGraph.
- [ ] SiteSelectionSystem V2.
- [ ] TerrainIntegrationAnalyzer.
- [ ] AccessNetworkGenerator.
- [ ] PlotAndDistrictGenerator.
- [ ] BuildingMassingGenerator V2.
- [ ] TerrainAdaptiveStructureSolver.
- [ ] Facade grammar.
- [ ] Roof grammar.
- [ ] Trim sheets.
- [ ] Weathering.
- [ ] Vertical villages.
- [ ] Bridges/stairs/ropes.
- [ ] Industrial/camps/mines.
- [ ] Partial interiors.
- [ ] Room graph.
- [ ] WFC interior.
- [ ] Interior streaming.
- [ ] HLOD building/block/district.
- [ ] Settlement Viewer production.
- [ ] Settlement validation report.

## Step 34 - UI/HUD avance

Objectif : IPUI retained-mode, procedural, lisible, accessible.

- [ ] UI retained tree.
- [ ] Dirty layout.
- [ ] Stack/grid/anchor/radial.
- [ ] UI state store.
- [ ] Input router.
- [ ] Controller focus graph.
- [ ] JSON themes.
- [ ] Token resolver.
- [ ] Theme validator.
- [ ] Biome/weather/faction modulation.
- [ ] Inventory.
- [ ] Map.
- [ ] Quest log.
- [ ] Dialogue.
- [ ] Crafting.
- [ ] SDF/MSDF text.
- [ ] Procedural icons.
- [ ] Glyph/faction symbols.
- [ ] World-space UI.
- [ ] Accessibility nodes.
- [ ] Reduce motion.
- [ ] High contrast.
- [ ] Colorblind modes.
- [ ] Theme inspector.
- [ ] Layout bounds viewer.
- [ ] Focus graph viewer.

## Step 35 - Validation production et Seed Lab

Objectif : rendre la V2 testable et maintenable.

- [ ] `SeedTestSuite`.
- [ ] Golden seed list.
- [ ] Determinism validator.
- [ ] Chunk seam validator.
- [ ] Biome transition validator.
- [ ] Material seam validator.
- [ ] Prop placement validator.
- [ ] Settlement validator.
- [ ] Collision/render mismatch validator.
- [ ] Performance budget validator.
- [ ] Save migration validator.
- [ ] Crash recovery tests.
- [ ] Visual snapshot runner.
- [ ] Diagnostic bundle export.
- [ ] Benchmark mode production.
- [ ] Release gate checklist.

## Risques ouverts V2

- [ ] L'ambition IVDS/lighting peut depasser le budget M1 si HLOD/fallbacks ne viennent pas assez tot.
- [ ] Les outils peuvent devenir lourds si les previews ne restent pas isolees et throttled.
- [ ] Le save production peut devenir fragile si SQLite/WAL arrive sans crash tests.
- [ ] La variation procedurale peut nuire a la lisibilite si validators et archetypes ne sont pas stricts.
- [ ] UI custom Metal peut ignorer l'accessibilite si le bridge semantic n'est pas pose assez tot.

## Historique V2

| Date | Step | Resume | Commit |
|---|---|---|---|
| 2026-06-12 | V2 plan docs | Ajout du plan V2 et du tracker V2 apres Step 23 | pending |
| 2026-06-12 | Step 24-A | Tools Hub V2 avec workspace, registry production, document store packages, validation hints et diagnostics | pending |
| 2026-06-12 | Step 24-B | Rapports specialises pour terrain, biomes, props, materiaux, LOD, save inspector et seed gallery | pending |
| 2026-06-12 | Step 24-C | Rapports specialises pour les outils restants et runner golden seeds branche dans la validation | pending |
