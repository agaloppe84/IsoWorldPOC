# Plan d'implementation moteur V2

Ce document est le plan d'action actif pour la V2 du moteur IsoWorld, construit apres le Step 23. Il synthetise les docs de reference dans `docs/IsoWorld-Research-Lab/` et l'etat livre dans `docs/V1_ENGINE_BASELINE.md`, `docs/ARCHITECTURE.md` et `docs/DECISIONS.md`.

Les docs de reference restent la vision long terme. Ce fichier transforme cette vision en ordre d'implementation concret pour une V2 robuste, performante, moderne et future-proof.

## Sources recoupees

- `implementation-engine-cores.md` : ordre Step 24 a Step 35, dependances systemes, criteres de qualite.
- `procedural-app-flow-shell-tools-system.md` : Tools Hub production, state machine, diagnostics, previews isolees.
- `procedural-save-system.md` : seed + versions + deltas, region files, SQLite/WAL, CAS blobs, snapshots, migrations, packages outils.
- `modern-texture-lighting-pipeline.md` : ISLP, PBR, material graph, Forward+/clustered lighting, CSM, probes, surface states, virtual textures.
- `nanite-inspired-lod-system.md` : IVDS, HLOD, terrain LOD, meshlets/clusters, culling GPU, geometry pages, Metal mesh shaders, visibility buffer.
- `procedural-versatile-terrain-generation.md` : terrain field-driven, feature-driven, hydrologie, verticalite, patches volumetriques, DSL de regles.
- `procedural-biome-transition-system.md` : BiomeGraph, WorldBiomeDNA, ecotones, sub-biomes, micro-habitats, fields continus.
- `procedural-parametric-props-system.md` : PropCatalog, recipes, genomes, rules, weathering, manufacturable props, interactions, WFC local.
- `procedural-physics-driven-animation-system.md` : environnement-aware motion, contact patches, footstep planner, warping, vertical traversal, motion matching.
- `procedural-parametric-particles-fx-pipeline.md` : IPFX, GPU particles, data interfaces, indirect draws, weather/world FX, budgets.
- `procedural-parametric-audio-engine.md` : procedural audio graphs, physical footsteps, ambience, generative music, spatial/acoustic.
- `procedural-parametric-character-system.md` : CharacterDNA, humanoid skeleton, PNJ, clothing/culture, persistent states, crowd LOD.
- `procedural-deterministic-rpg-system.md` : WorldRPGDNA avance, factions, storylets, quest graph, director, economy, reputation, endgames.
- `procedural-parametric-buildings-settlements-system.md` : architecture ecosystem, WorldArchitectureDNA, settlement intent, terrain integration, districts, interiors, HLOD.
- `procedural-parametric-ui-hud-system.md` : IPUI retained-mode, custom Metal HUD, design tokens, themes, accessibility bridge.
- `procedural-modern-rendering.md` : Metal data-oriented rendering, GPU-driven direction, resource lifetime, compact procedural data.

## Etat de depart apres Step 23

La V1 active dispose deja de :

- AppShell, Real World, Debug World, Tools Hub minimal.
- `EngineCore` pur avec seeds, IDs, RNG, jobs, snapshots.
- renderer Metal unique, FrameGraph simple, terrain/props/player/debug/HUD/FX passes.
- terrain fields, biomes initiaux, splats/PBR preview, FeatureGraph, hydrologie V1, traversal V1.
- LOD baseline, culling/visible chunks, snapshot cache, debug cadence optimisee.
- props naturels simples, characters base, animation/contact V1, FX V1, audio event pipeline V1, UI/HUD Metal minimal.
- RPG DNA V1, settlements/buildings V1, save avancee V2 sous forme de contrats.
- docs actives et tests EngineCore couvrant les contrats principaux.

La V2 ne doit pas repartir de zero. Elle doit industrialiser cette base.

## Vision V2

La V2 doit transformer IsoWorld en moteur procedural systemique :

```text
Seed + World DNA + Recipes + Deltas
  -> Tool-authored packages and validation
  -> EngineCore deterministic systems
  -> Async build/cache layers
  -> Immutable runtime snapshots
  -> Metal GPU-driven rendering + custom HUD + procedural audio
  -> Save/migration/profiling/seed lab
```

Le but n'est pas seulement "plus de features". Le but est que chaque systeme devienne :

- deterministe par seed et version ;
- data-driven et modifiable par outils ;
- validable automatiquement ;
- budgete CPU/GPU/memoire ;
- inspectable via debug tools ;
- sauvegardable via deltas/packages ;
- decouple de SwiftUI/Metal quand il vit dans `EngineCore` ;
- compatible avec des caches rebuildables et des migrations futures.

## Principes non negociables V2

1. `EngineCore` reste pur : pas de SwiftUI, pas de Metal, pas de cycle de vie macOS.
2. Le renderer ne decide pas le monde : il consomme des snapshots et des ressources preparees.
3. La source de verite est seed + generator versions + recipes + deltas, jamais un cache de mesh.
4. Les caches lourds sont rebuildables et exclus des saves source-of-truth.
5. Les tools manipulent des documents/packages versionnes, pas des singletons runtime.
6. Toute feature visible doit avoir un debug view ou un rapport de validation.
7. Toute feature couteuse doit avoir un budget et un mode de degrade.
8. Les gameplay anchors/collisions/navigation ne doivent pas dependre du LOD render.
9. Le mode Real World ne doit pas afficher ni payer le cout des outils debug.
10. Les migrations et tests de saves doivent suivre les schemas, pas arriver a la fin.

## Architecture cible V2

```text
IsoWorldPOC app
  AppShell
    MainMenu
    RealWorld
    DebugWorld
    ToolsHub
  ToolingUI
    Project packages (.isoproj)
    Asset packages (.isoasset)
    Graph packages (.isograph)
    Inspectors / validators / seed lab
  GameRuntime
    WorldSession
    WorldRuntime
    streaming/orchestration
    save/autosave coordinator
  Rendering/Metal
    FrameGraph
    ISLP surface + lighting
    IVDS/HLOD/cluster pipelines
    IPFX GPU passes
    IPUI HUD renderer
  AudioRuntime
    Apple backend
    deterministic DSP/graph layer

EngineCore
  Foundation / Jobs / Diagnostics
  Persistence / Validation
  Terrain / Biomes / Materials / LOD / VirtualGeometry
  Props / Characters / Animation / FX / Audio / RPG / Settlements / UIModel
```

## Tracks transverses a maintenir pendant toute la V2

### Determinisme et versioning

- Chaque domaine V2 doit avoir un `SeedDomain` ou sous-domaine clair.
- Les nouveaux recipes doivent porter schema version + generator version.
- Les tests doivent verifier meme seed + memes versions = memes hashes.
- Les deltas sauvegardes doivent etre independants de l'ordre de streaming.

### Performance et scalability tiers

La V2 doit avoir des tiers explicites :

- Tier 0 Low/debug : LOD agressif, HLOD fort, peu de lights shadowed, pas de virtual geometry detaillee.
- Tier 1 M1 target : HLOD chunks, terrain quadtree, culling compute progressif, page cache modere, impostors forts.
- Tier 2 M2/M3/M4+ : mesh shaders si disponibles, meilleur cluster culling, virtual textures plus riches.
- Tier 3 Future : visibility buffer, virtual material, virtual shadow maps, dense procedural worlds.

### Save/cache policy

Chaque systeme doit declarer :

- ce qui est source-of-truth ;
- ce qui est delta mutable ;
- ce qui est cache rebuildable ;
- ce qui est snapshot compactable ;
- comment migrer ;
- comment reparer.

### Tooling-first

Un systeme V2 ambitieux sans outils devient opaque. Chaque grand step doit livrer au minimum :

- inspector ;
- validator ;
- seed gallery ou preview matrix ;
- budget/perf view ;
- export/import si package ou recipe.

### Validation production

Les validations doivent progressivement couvrir :

- determinisme ;
- seams terrain/biomes/materials ;
- no NaN ;
- budgets CPU/GPU/memoire ;
- save/load/migration ;
- LOD transitions ;
- collision/render mismatch ;
- accessibility UI ;
- regression golden seeds.

## Roadmap V2 par phases

### Phase V2-A : Tooling et persistence production

Objectif : rendre les systemes modifiables, validables et sauvegardables avant de les complexifier.

Steps principaux :

- Step 24 : Tools Hub production V2.
- Save production track : autosave coordinator, region writer, SQLite/WAL, migration lab.
- Validation foundations : seed lab, package validators, diagnostic exports.

Livrables structurants :

- documents outils persistants via `.isoproj`, `.isoasset`, `.isograph`;
- save inspector et snapshot diff ;
- seed gallery et performance HUD ;
- runtime export des packages vers recipes consommees par `EngineCore`;
- migration/save corpus minimal.

Gate de sortie :

- un tool peut ouvrir, modifier, valider, autosauver, exporter et recharger un package sans lancer le monde.
- aucun outil ne mute `WorldRuntime` directement.
- les saves/deltas peuvent etre inspectes et compares.

### Phase V2-B : Surface, lighting et weather modernes

Objectif : remplacer le PBR preview par un pipeline visuel robuste.

Step principal :

- Step 25 : Lighting avance + weather surfaces.

Livrables structurants :

- `WorldRenderDNA` et material palettes par monde/biome/RPG.
- `IsoMaterialRuntime` et material table compacte.
- terrain layered PBR avec texture sets baseColor/normal/ORM.
- triplanar proche pour falaises et surfaces verticales.
- tone mapping, IBL sky simple, CSM, shadow atlas local.
- Forward+ ou clustered lights selon complexite.
- surface states : wetness, snow, dust, moss.
- reflection probes et irradiance probes chunkees.
- fog/atmosphere/water V2 minimal.
- material viewer + lighting sandbox + texture residency debugger.

Gate de sortie :

- terrain, props, characters et structures lisent des contrats materiaux coherents.
- les modes debug peuvent isoler base color, normal, roughness, splats, lights, cascades, probes, wetness/snow/dust.
- le shader ne devient pas un monolithe impossible a profiler.

### Phase V2-C : IVDS, HLOD et rendu dense

Objectif : rendre possible la densite future sans exploser CPU/GPU.

Step principal :

- Step 26 : LOD avance / IVDS Nanite-inspired.

Livrables structurants :

- LOD orchestrator multi-domaines : terrain, virtual geometry, foliage, characters, FX, HLOD.
- HLOD par chunk, props groups, structures groups.
- terrain quadtree/clipmap simple, transitions crack-free.
- impostors arbres/foliage lointains.
- meshlets/clusters offline/procedural async.
- compute culling, Hi-Z, compaction visible clusters.
- indirect command buffers quand pertinents.
- geometry pages + page cache + root resident geometry.
- fallback compute+ICB et capability detection pour mesh shaders Metal.
- debug IVDS : clusters, pages, LOD errors, residency, missing pages.

Gate de sortie :

- toujours afficher un fallback sans trou de streaming.
- gameplay collision/anchors restent stables quand le render LOD change.
- la taille disque/cache est budgetee.
- le pipeline reste compatible M1.

### Phase V2-D : Monde naturel riche

Objectif : passer du terrain/biomes/props V1 a un monde naturel procedural credible.

Steps principaux :

- Step 27 : Props avances et manufactures.
- Terrain/Biome expansion intercalee avec Step 25/26.

Livrables structurants :

- `WorldBiomeDNA`, `BiomeGraph`, sub-biomes, ecotones explicites, micro-habitats.
- climate fields + geo/hydro fields data-driven.
- DSL/regles terrain pour materiaux, gameplay, danger, hydrologie, props, LOD.
- hydrologie plus riche : rivers as corridors, lake flattening, shore materials, waterfalls simples.
- patches volumetriques/SDF locaux pour grottes, arches, overhangs.
- PropCatalog V2 : natural + manufactured + narrative + interactive families.
- PropVariantGenome avec correlations age/usure/materiau.
- weathering masks, biome overlays, sockets, composed collisions.
- shape grammar/WFC local pour objets composes.
- instancing par famille, material atlases, prop LOD/impostors.
- Prop Gallery production, Rule Debugger, Budget Viewer, Snapshot Diff.

Gate de sortie :

- les transitions de biomes deviennent des zones de gameplay, pas seulement des blends visuels.
- chaque prop repond a "pourquoi ici", "comment le contexte l'a modifie", "que comprend le joueur".
- les props interactifs persistent via deltas Step 23+.

### Phase V2-E : Personnages et mouvement environnement-aware

Objectif : remplacer le preview joueur par un systeme personnage/animation coherent avec terrain, materiaux et RPG.

Steps principaux :

- Step 28 : Animation avancee.
- Step 31 : Character avance.

Livrables structurants :

- skinned mesh simple et GPU skinning.
- CharacterDNA enrichi, PNJ par seed, cultures/factions, clothing/climate rules.
- hair cards, cicatrices/tatouages/salete, body morphs, shoes gameplay.
- CharacterBuildCache pour assets couteux.
- contact patches filtres, footwear profiles, friction effective, compliance.
- footstep planner, support polygon approximatif, fatigue/charge.
- slope/stride/orientation warping, inertialization, motion warping.
- climb mode, hand IK, rope/ladder/stair affordances.
- motion matching V1 avec debug top-k et features terrain.
- partial active ragdoll, balance controller, impact reactions.
- character customization non destructive et persistent states.
- crowd LOD, impostors, settlement population hooks.

Gate de sortie :

- le gameplay depend du motor/capsule/contacts valides, pas des os finaux.
- le debug explique les adaptations de mouvement.
- les chaussures, surfaces, FX et audio lisent les memes contacts.

### Phase V2-F : FX et audio comme couches expressives du monde

Objectif : rendre le monde vivant par evenements, surface responses, weather et style RPG.

Steps principaux :

- Step 29 : FX avances GPU.
- Step 30 : Audio avance.

Livrables structurants FX :

- IPFX graph model : systems, emitters, modules, data interfaces.
- CPU authoritative events + GPU cosmetic simulation.
- Metal compute spawn/update, alive/dead lists, indirect draw args.
- soft particles, depth collision, ribbons/trails, beams, distortion.
- low-res particles, volumetric lite, weather macro FX.
- material/weather/biome/RPG data interfaces.
- FX Director, FX Ecology, FX Memory, anomalies RPG.
- graph editor + compiler + profiler + overdraw heatmap.

Livrables structurants audio :

- backend AVAudioEngine/CoreAudio simple mais propre.
- procedural audio graph compiler.
- physical footsteps : surface, footwear, wetness/mud/snow, animation contacts.
- ambience manager par biome, wind/rain/water synth.
- generative music : WorldMusicDNA, harmony, motifs, arrangement director.
- spatializer, occlusion, reverb zones, acoustic materials, portals.
- modal impact synth, friction synth, creature voice synth.
- audio graph preview, event/voice meters, export variants.

Gate de sortie :

- le son et les FX sont derives des memes regles que terrain/biomes/props/meteo/RPG.
- les events gameplay restent deterministes, les simulations GPU restent tolerantes.
- overdraw, voices, particles et lights proxies sont budgetes.

### Phase V2-G : RPG procedural profond et settlements vivants

Objectif : transformer la seed en mondes jouables tres differents, puis incarner ces mondes dans les lieux.

Steps principaux :

- Step 32 : RPG avance.
- Step 33 : Settlements avances.

Livrables structurants RPG :

- WorldRPGDNA V2 : lois, tabous, economie, mythes, metiers, knowledge, endgames.
- factions avancees, cultures, ressources, territoires, relations.
- storylets, quest graph, rumor system, local narrative places.
- WorldStateLedger enrichi et compactable.
- director : tension, pacing, cooldowns, event candidates, budgets narratifs/danger.
- economy/reputation/progression systems.
- World DNA Inspector, Quest Graph Viewer, Storylet Debugger, Faction Simulator, Director Timeline.

Livrables structurants settlements :

- WorldArchitectureDNA.
- SettlementIntentGraph.
- SiteSelectionSystem avance.
- TerrainIntegrationAnalyzer.
- AccessNetworkGenerator : routes, stairs, bridges, vertical links.
- PlotAndDistrictGenerator.
- facade/roof grammar, trim sheets, weathering.
- industrial/camps/mines/rails/pipes.
- partial interiors, room graph, WFC local, interior streaming.
- HLOD batiment/bloc/quartier, skyline, occlusion.
- settlement viewer + validation report + visual graph editor minimal.

Gate de sortie :

- une ville n'est pas posee sur le monde ; elle semble avoir pousse, ete construite, reparee, abandonnee ou transformee par le monde.
- les lieux narratifs, props, PNJ, audio, UI et quests lisent les memes tags/regles RPG.
- les settlements sont budgets par classes visitables et HLOD.

### Phase V2-H : UI procedural production et accessibilite

Objectif : faire de l'UI un systeme procedural lisible, pas une collection d'ecrans hardcodes.

Step principal :

- Step 34 : UI/HUD avance.

Livrables structurants :

- IPUI retained-mode.
- UI tree, layout dirtying, stack/grid/anchor/radial.
- input router et focus graph manette.
- token resolver, JSON themes, UIWorldDNA enrichi.
- theme validator : contrast, motion, readability, accessibility.
- in-game menus stylises : inventory, map, quest log, dialogue, crafting.
- SDF/MSDF text planifie, procedural icons/glyphs, faction symbols.
- world-space UI, UI particles/shaders budgetes.
- accessibility bridge : roles, labels, values, reduce motion, high contrast, colorblind modes, large text.
- theme inspector, token editor, layout bounds viewer, focus graph viewer.

Gate de sortie :

- SwiftUI/AppKit reste pour OS-native, tools et debug avance.
- HUD et menus stylises in-game passent par renderer UI custom quand ils doivent etre performants.
- la lisibilite prime sur la variation procedurale.

### Phase V2-I : Validation production, seed lab et release hardening

Objectif : rendre le moteur robuste face aux changements continus.

Step principal :

- Step 35 : Validation production et seed lab.

Livrables structurants :

- `EngineCore/Validation` : seed suite, determinism validator, seam validators, budget validators, save migration validators.
- golden seeds et fixtures de mondes remarquables.
- visual snapshots et deterministic hashes.
- save corpus et migration lab.
- crash recovery tests pour writes/autosave/migration.
- performance budget validator : CPU, GPU, memory, draw calls, particles, voices, pages.
- release/perf profiles : Debug, Real World, Tools, Benchmark.
- automatic diagnostic bundle export.

Gate de sortie :

- chaque nouveau systeme V2 peut etre prouve par tests + diagnostics + docs.
- les regressions de seed, perf, save et visual seams sont visibles avant integration.

## Ordre d'implementation conseille a partir de maintenant

L'ordre ci-dessous suit les dependances officielles tout en ajoutant les sous-etapes indispensables pour ne pas construire une V2 fragile.

### Step 24 - Tools Hub production V2

But : rendre les systemes modifiables, validables et persistables.

Sous-steps proposes :

1. `ToolWorkspace` + navigation production : categories, recent projects, dirty state, command routing.
2. `ToolDocumentStore` : open/save/autosave draft pour `.isoproj`, `.isoasset`, `.isograph`.
3. Preview isolation contract : aucune mutation de `WorldRuntime`, previews par snapshot/rapport.
4. Tool validators communs : severity, fix hints, references de packages.
5. Terrain Recipe Editor V2 : fields, FeatureGraph, hydrology preview, validation seams.
6. Biome Graph Viewer : weights, ecotones, sub-biomes, transition rules.
7. Prop Gallery production : families, genomes, placement rules, budget.
8. Material Viewer : PBR params, texture slots, surface states hooks.
9. LOD Debugger : chunk/prop/terrain LOD, budgets, hysteresis.
10. Character Customization Lab : CharacterDNA, clothing, sockets, save overrides.
11. Animation Contact Lab : contact patches, foot IK, surface response.
12. FX Preview Editor + Audio Graph Preview : event matrix, variants export.
13. RPG World DNA Browser + Settlement Viewer.
14. Save Inspector + Snapshot Diff.
15. Performance HUD + Seed Gallery.

Definition of Done :

- Chaque outil a un descriptor, un document, un preview, un validator et une persistence policy.
- Les packages Step 23 round-trip via JSON stable.
- Les tools peuvent etre utilises sans ouvrir un monde reel.
- Le Hub garde SwiftUI hors de la boucle renderer monde.

### Step 24-BIS - Persistence production spine

But : brancher les contrats Step 23 sans attendre la fin de la V2.

Sous-steps proposes :

1. `SaveCoordinator` actor.
2. `PersistenceRegistry` par domaine.
3. writer/reader de fichiers region `.isoregion`.
4. autosave incremental avec debounce et budget.
5. `state.sqlite` experimental pour entities/events/indexes.
6. WAL + transactions + recovery.
7. CAS blob store pour assets/caches lourds.
8. migration lab avec corpus de saves.
9. Save Inspector connecte aux vraies donnees.

Definition of Done :

- un monde modifie peut sauvegarder puis recharger un delta terrain/prop/entity.
- un crash injecte pendant save recupere le dernier etat valide.
- les caches restent exclus de la source de verite.

### Step 25 - ISLP lighting/surfaces V2

But : rendre le monde credible sans ray tracing.

Sous-steps proposes :

1. `WorldRenderDNA`, surface palettes, material compatibility tags.
2. material runtime table et parameter blocks compacts.
3. texture sets baseColor/normal/ORM et normal/ORM packing.
4. terrain layered PBR avec triplanar proche.
5. tone mapping, exposure et IBL sky.
6. CSM pour soleil + shadow atlas local.
7. Forward+ ou clustered lighting.
8. wetness/snow/dust/moss surface state maps.
9. probes : reflection + irradiance chunked.
10. fog/atmosphere/water baseline.
11. material/lighting tools et validators.

### Step 26 - IVDS / LOD avance

But : densite massive, sans casser gameplay ni M1.

Sous-steps proposes :

1. LOD orchestrator multi-domaines.
2. HLOD chunks/props/structures.
3. terrain quadtree/clipmap crack-free.
4. impostors foliage.
5. meshlet/cluster data model.
6. compute culling + indirect commands.
7. geometry page cache + root resident fallback.
8. procedural IVDS builder async.
9. mesh shader path experimental avec fallback.
10. debug residency/clusters/pages/LOD errors.

### Step 27 - Props avances

But : passer de props simples a familles riches, narratives et interactives.

Sous-steps proposes :

1. registry data-driven et rule sets.
2. scoring/constraints/layer budgets.
3. PropVariantGenome correlations.
4. weathering/biome overlays.
5. manufactured props via shape grammar + sockets.
6. collisions composees et gameplay affordances.
7. interactive prop deltas.
8. instancing massif + prop LOD/impostors.
9. WFC local pour objets composes.
10. Prop Gallery + Rule Debugger + Budget Viewer.

### Step 28 - Animation avancee

But : mouvement conscient de l'environnement.

Sous-steps proposes :

1. contact patches filtres et surface/footwear response.
2. footstep planner.
3. slope/stride/orientation warping.
4. support polygon, fatigue, charge, glissades.
5. vertical traversal : ledge, climb, rope, ladder, stair.
6. hand IK et motion warping.
7. motion matching V1 avec debug top-k.
8. partial active ragdoll.

### Step 29 - FX GPU avances

But : IPFX compute-first, budgete et world-aware.

Sous-steps proposes :

1. FX graph model + compiler.
2. Metal compute spawn/update.
3. alive/dead lists + indirect draw args.
4. depth collision + soft particles.
5. flipbooks, ribbons, trails, beams, distortion.
6. low-res particles + volumetric lite.
7. weather macro FX + FX Director.
8. overdraw/budget profiler.

### Step 30 - Audio avance

But : audio procedural derive du monde.

Sous-steps proposes :

1. backend AVAudioEngine/CoreAudio.
2. procedural audio graph compiler.
3. physical footsteps surface/footwear/weather.
4. ambience biome/weather.
5. generative music and arrangement director.
6. spatialization, occlusion, reverb zones.
7. synths impacts/friction/creatures/machines.
8. authoring UI + profiler.

### Step 31 - Characters avances

But : joueur/PNJ expressifs et persistants.

Sous-steps proposes :

1. skinned mesh + GPU skinning.
2. CharacterDNA PNJ, culture/faction/climate clothing.
3. hair cards, scars, tattoos, dirt, body morphs.
4. advanced skin/eyes approximations.
5. clothing refit + shoes gameplay.
6. injuries/aging/prosthetics persistent states.
7. CharacterBuildCache.
8. crowd LOD and settlement population hooks.

### Step 32 - RPG avance

But : seed -> mondes jouables radicalement differents.

Sous-steps proposes :

1. WorldRPGDNA V2 axes riches.
2. factions/cultures/resources/territories.
3. storylets and quest graph.
4. local rumors and narrative places.
5. director timeline and pacing budgets.
6. economy, reputation, professions, knowledge, myths.
7. multiple endgames and player transformations.
8. debug tools production.

### Step 33 - Settlements avances

But : lieux construits avec le monde, pas poses dessus.

Sous-steps proposes :

1. WorldArchitectureDNA.
2. SettlementIntentGraph.
3. TerrainIntegrationAnalyzer.
4. AccessNetworkGenerator.
5. Plot/district generation.
6. facade/roof grammar, trim sheets, weathering.
7. vertical villages, bridges, stairs, cliff buildings.
8. industrial/camps/mines/rails/pipes.
9. partial interiors + WFC + streaming.
10. HLOD batiment/bloc/quartier.

### Step 34 - UI/HUD avance

But : IPUI retained-mode, performant et accessible.

Sous-steps proposes :

1. UI tree retained-mode + dirty layout.
2. input router + focus graph manette.
3. JSON themes + token resolver + validators.
4. procedural modulation biome/weather/faction.
5. inventory/map/quest/dialogue/crafting stylises.
6. SDF/MSDF text plan.
7. procedural iconography/glyph grammar.
8. accessibility bridge.
9. authoring tools UI.

### Step 35 - Validation production et Seed Lab

But : rendre la V2 maintenable.

Sous-steps proposes :

1. Golden seed suite.
2. determinism validator.
3. terrain/biome/material seam validators.
4. prop/settlement/collision validators.
5. performance budget validator.
6. save/migration validator and crash tests.
7. visual snapshot runner.
8. diagnostic bundle export.
9. release gates.

## Gates qualite par PR

Chaque PR V2 doit repondre a cette checklist :

```text
[ ] Build via scripts/xcodebuild-safe.sh OK si app touchee
[ ] Tests EngineCore ou app ajoutes si contrat modifie
[ ] Pas d'import SwiftUI/Metal dans EngineCore hors contrats prevus
[ ] Seed/version/determinisme documentes
[ ] Save/cache policy claire
[ ] Debug view ou validation report disponible
[ ] Budget perf/memoire defini si runtime
[ ] Fallback/degrade prevu
[ ] Docs actives mises a jour si decision structurante
[ ] Docs de reference IsoWorld-Research-Lab non modifiees
```

## Budget initial V2

Ces valeurs sont des cibles de depart, a ajuster avec profiling reel :

| Domaine | Cible V2 |
|---|---:|
| Real World target | 60 FPS si possible, degrade a 30 FPS stable |
| Frame CPU main thread | < 4 ms hors UI/debug |
| Snapshot stable frame | proche de 0 allocation |
| Debug telemetry | 1-2 Hz compact, details on demand |
| Tool previews | on demand ou throttled |
| Chunk generation | job async, jamais lourd sur MainActor |
| Geometry streaming | root resident fallback obligatoire |
| Particle overdraw | heatmap + budget par tier |
| Audio voices | budget par bus/priorite |
| Save autosave | incremental, budgete, crash-safe |

## Definition globale de V2 done

La V2 est consideree livree quand :

- Tools Hub production peut authorer/valider/exporter les systems principaux.
- Save production peut persister un monde vivant modifie avec recovery et migrations.
- ISLP remplace le PBR preview par surfaces/lights/weather modernes.
- IVDS/HLOD permet une densite nettement superieure sans casser M1.
- Props, characters, animation, FX, audio, RPG, settlements et UI lisent les memes donnees monde.
- Seed Lab et validation production detectent regressions de determinisme, seams, saves et budgets.
- Real World reste propre : aucun outil debug visible ni cout SwiftUI haute frequence.
