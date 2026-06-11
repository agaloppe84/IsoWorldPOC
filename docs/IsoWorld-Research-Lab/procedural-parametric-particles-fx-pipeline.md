# IsoWorld — Point 12 — Pipeline moderne de particules / FX procéduraux et paramétriques

**Document dédié uniquement au sujet 12 : gestion des particules et FX avec un pipeline moderne, déterministe, procédural/paramétrique, haute qualité, adapté à IsoWorld en Swift/Metal sur Apple Silicon.**

_Date de référence : 2026-06-10._

---

## 0. Objectif du document

Le but n’est pas de créer un simple `ParticleSystem` classique limité à des sprites alpha. Pour IsoWorld, il faut un **système FX complet**, capable de générer des effets visuels très variés, paramétriques, cohérents avec le monde procédural, le terrain, les biomes, la météo, les matériaux, les règles RPG et le seed global.

Le système doit pouvoir produire :

- poussière sur sol sec ;
- éclaboussures sur roche mouillée ;
- fumée de feu de camp ;
- brouillard de vallée ;
- neige poussée par le vent ;
- feuilles mortes en tourbillon ;
- étincelles sur métal ;
- traces lumineuses de magie ;
- impacts de projectiles ;
- particules d’eau autour d’une cascade ;
- FX de craft, forge, cuisine, alchimie, technologie, énergie, rituel ;
- vents de sable, pollen, spores, cendres, poussières volcaniques ;
- micro-FX liés aux chaussures, au matériau du sol, à la vitesse, à l’humidité ;
- FX procéduraux rares créés par certaines règles de monde générées par seed.

Le système doit être **artist-friendly**, **data-driven**, **GPU-friendly**, mais aussi **déterministe au niveau monde**. Il doit pouvoir rendre des effets riches sans exploser le coût CPU/GPU.

---

## 1. Recherche industrie : ce qu’il faut retenir

### 1.1 Unreal Engine Niagara

Niagara est une référence importante car il structure les effets en **Systems**, **Emitters**, **modules** et **renderers**. Un Niagara System contient plusieurs emitters ; chaque emitter contrôle la naissance, la vie, le comportement et le rendu des particules. Les modules sont organisés en groupes d’exécution : `Emitter Spawn`, `Emitter Update`, `Particle Spawn`, `Particle Update`, `Event Handler`, puis `Render`. Source : [Unreal Engine — Overview of Niagara Effects](https://dev.epicgames.com/documentation/unreal-engine/overview-of-niagara-effects-for-unreal-engine).

Points à retenir pour IsoWorld :

1. **Séparer le System de l’Emitter** : un effet complet est rarement un seul flux de particules. Une explosion combine flash, shockwave, fumée, débris, lumière, decals, son, camera shake.
2. **Empiler des modules simples** : spawn, force, collision, couleur, taille, rotation, turbulence, kill, render.
3. **Supporter plusieurs renderers** : sprite, mesh, ribbon/trail, decal, light, volume proxy.
4. **Permettre des Data Interfaces** : Niagara utilise des Data Interfaces pour lire des données externes. IsoWorld doit avoir l’équivalent : terrain, météo, biomes, matériaux, vent, gameplay events, animation, physics, RPG rules.
5. **Prévoir des emitters légers/stateless** : Unreal documente des lightweight/stateless emitters optimisés pour réduire, voire éliminer, le tick de simulation dans certains cas. Source : [Unreal Engine — Niagara Lightweight Emitters](https://dev.epicgames.com/documentation/unreal-engine/niagara-lightweight-emitters).

### 1.2 Unity Visual Effect Graph

Unity VFX Graph est une autre référence importante pour les effets GPU authorés par graphe. La documentation indique qu’un Visual Effect Graph permet de créer un ou plusieurs particle systems, d’ajouter des meshes statiques et de contrôler des propriétés de shader. Source : [Unity — Visual Effect Graph](https://docs.unity3d.com/Packages/com.unity.visualeffectgraph%4012.0/).

Points à retenir :

1. **Graph authoring** : les artistes/technical artists doivent pouvoir composer les effets visuellement ou via des recettes data.
2. **GPU-first pour les gros volumes** : pluie, neige, poussière, insectes, étincelles, fumée légère.
3. **Mesh particles** : Unity supporte les sorties de particules sous forme de mesh, utiles pour cailloux, braises, feuilles, débris, oiseaux stylisés, fragments. Source : [Unity — Output Particle Mesh](https://docs.unity3d.com/Packages/com.unity.visualeffectgraph%4010.2/manual/Context-OutputParticleMesh.html).
4. **Sampling de mesh/skinned mesh** : Unity a mis en avant le sampling de skinned mesh pour flammes, trails, dissolution, morphing sur personnages/objets. Source : [Unity Blog — New possibilities with VFX Graph](https://unity.com/blog/engine-platform/new-possibilities-with-vfx-graph-in-2020-lts-and-beyond).

### 1.3 Frostbite GPU Emitter Graph

Frostbite a présenté un **graph based GPU particle system** avec shader generation, memory management, sorting, rendering et un workflow data-driven pour supporter une grande variété de jeux. Source : [EA/Frostbite — GPU Emitter Graph System](https://www.ea.com/news/frostbite-gpu-emitter-graph-system).

À retenir :

1. Le système FX doit être **générique**, pas construit pour un seul type de jeu.
2. Le graphe doit pouvoir compiler vers des kernels/shaders efficaces.
3. La mémoire, le tri, le batching et le rendu sont des sujets centraux, pas des détails.
4. Un système moderne doit lier **workflow artiste** et **architecture GPU**.

### 1.4 Frostbite volumetric rendering

Frostbite a aussi documenté une approche de rendu volumétrique unifié : extinction volumes, voxelisation de particules dans un volume d’extinction, shadow maps volumétriques et rendu final des participating media. Source : [EA/Frostbite — Physically-based & Unified Volumetric Rendering](https://www.ea.com/news/physically-based-unified-volumetric-rendering-in-frostbite).

À retenir pour IsoWorld :

- les particules ne doivent pas seulement être des quads alpha ;
- fumée, brouillard, poussière, nuages bas, tempêtes et atmosphère locale doivent pouvoir alimenter une **couche volumétrique légère** ;
- tous les volumes doivent utiliser des paramètres physiques simplifiés : densité, extinction, albedo, anisotropie, bruit, vitesse du vent, dissipation.

### 1.5 EmberGen et le workflow flipbook / VDB

EmberGen est une référence production pour les FX de feu, fumée et explosions temps réel, avec simulation GPU, exports flipbooks/sprite sheets, motion vectors, normal maps, depth maps, 6-point lighting et VDB. Source : [JangaFX — EmberGen](https://jangafx.com/software/embergen).

À retenir :

1. Certains FX coûteux doivent être **pré-bakés** sous forme de flipbooks haut de gamme.
2. Les flipbooks doivent contenir plus que de l’albedo : normales, profondeur, motion vectors, lighting frames.
3. L’itération rapide est cruciale.
4. Un pipeline AAA ne simule pas tout en runtime : il combine runtime procedural + baked volumetric assets.

### 1.6 GPU Gems : off-screen particles

Le chapitre “High-Speed, Off-Screen Particles” de GPU Gems explique que les particules peuvent être très coûteuses en overdraw/fillrate, notamment pour smoke, fire, explosions, dust, fog. La technique proposée rend les particules coûteuses dans une cible off-screen de résolution réduite, puis les recompose sur l’image finale. Source : [NVIDIA GPU Gems 3 — High-Speed, Off-Screen Particles](https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-23-high-speed-screen-particles).

À retenir :

- les FX soft/low-frequency peuvent être rendus à demi, quart ou huitième résolution ;
- les FX high-frequency comme débris et étincelles doivent rester en résolution native ;
- les particules plein écran sont un danger majeur pour les performances ;
- le moteur doit classer les effets selon leur fréquence visuelle et leur coût.

### 1.7 Metal moderne

Apple fournit des samples Metal modernes utilisant Indirect Command Buffers, sparse textures, variable rate rasterization, GPU-based mesh culling, tile-based deferred lighting, ambient occlusion, volumetric fog et cascaded shadow maps. Source : [Apple — Metal Sample Code](https://developer.apple.com/metal/sample-code/). Apple documente aussi les mesh shaders comme pipeline flexible pour générer de la géométrie procédurale sur GPU et améliorer le culling meshlet. Source : [Apple WWDC22 — Transform your geometry with Metal mesh shaders](https://developer.apple.com/videos/play/wwdc2022/10162/).

À retenir pour IsoWorld :

- FX massifs = compute + GPU buffers + indirect rendering ;
- renderers mesh/trail/procedural peuvent bénéficier des mesh shaders sur machines compatibles ;
- argument buffers et heaps doivent réduire le coût CPU ;
- sparse textures peuvent aider pour atlases, flipbooks volumineux, caches de bruit, decals et texture fields.

---

## 2. Vision IsoWorld : IsoWorld Procedural FX System, ou IPFX

Nom proposé : **IPFX — IsoWorld Procedural FX System**.

IPFX est un système en couches :

```text
World Seed / WorldRuleDNA
        ↓
Biome + Weather + Terrain + Materials + Gameplay Events
        ↓
FX Event Layer
        ↓
FX Recipe Resolver
        ↓
FX Graph Instance
        ↓
Emitters / Modules / Data Interfaces
        ↓
CPU simulation / GPU simulation / Stateless evaluation
        ↓
Renderers: sprites, meshes, ribbons, decals, volumes, lights, distortion
        ↓
Compositor: opaque, transparent, low-res particles, volumetrics, post-process
```

L’idée centrale : un FX n’est pas une animation figée. C’est une **recette paramétrique** évaluée dans un contexte de monde.

Exemple : le joueur pose le pied au sol.

```text
Footstep event
- actorMass = 82 kg
- shoeType = leather_boot
- footVelocity = 2.1 m/s
- groundMaterial = wet_mud
- wetness = 0.74
- slope = 12°
- wind = 4 m/s NE
- biome = temperate_wet_forest
- timeOfDay = dusk
- temperature = 8°C
- seed = worldSeed + chunkSeed + actorID + stepIndex
```

IPFX résout cet événement en :

- éclaboussure boueuse ;
- petites particules de boue projetées ;
- decal d’empreinte humide ;
- micro-gouttelettes ;
- son mouillé ;
- légère modification temporaire du sol ;
- variation selon la chaussure et la vitesse.

---

## 3. Principes fondamentaux

### 3.1 Procédural, mais contrôlable

Le système doit générer beaucoup de variantes, mais rester contrôlable. Chaque effet doit être défini par :

- un **type** : fire, smoke, dust, magic, impact, weather, biome ambient ;
- un **style** : realistic, stylized, painterly, magical, toxic, alien, technological ;
- une **recette** : graph + paramètres ;
- un **budget** ;
- un **niveau de déterminisme** ;
- des **contraintes de gameplay** ;
- des **règles de LOD** ;
- des **règles de culling** ;
- des **renderers autorisés**.

### 3.2 Gameplay authoritative, FX perceptual

Les FX ne doivent pas contrôler la simulation gameplay critique. Ils doivent réagir au gameplay.

- Collision gameplay : CPU / physics / terrain system.
- Collision FX cosmétique : GPU depth, SDF, heightfield, coarse colliders.
- Événements gameplay : déterministes et réplicables.
- Particules : peuvent être perceptuellement déterministes, pas forcément bit-identiques sur GPU.

### 3.3 Le seed pilote le style, pas chaque float

Pour garder un monde déterministe sans rendre le GPU impossible à maîtriser :

- le seed doit choisir les familles d’effets, palettes, intensités, règles ;
- chaque événement possède un `FXEventID` stable ;
- les variations sont générées à partir de hashes stables ;
- la simulation GPU peut diverger légèrement si elle reste visuellement cohérente ;
- les événements importants sont générés côté CPU et envoyés au GPU.

### 3.4 Multi-échelle

Un système FX moderne doit gérer :

- micro-FX : poussière de pas, gouttes, étincelles ;
- méso-FX : torches, feux, cascades, impacts ;
- macro-FX : tempête, brouillard de vallée, cendres volcaniques ;
- méta-FX : changement de biome, événement RPG, anomalie mondiale.

### 3.5 FX comme extension du monde

Les FX doivent lire les systèmes existants :

- terrain ;
- biomes ;
- météo ;
- matériaux ;
- props ;
- animation ;
- RPG rules ;
- gameplay tags ;
- lighting ;
- audio.

Un feu ne doit pas avoir le même look dans un désert sec, une forêt humide, une grotte glacée ou un monde futuriste toxique.

---

## 4. Architecture data-driven

### 4.1 `FXDefinition`

Décrit un effet réutilisable.

```swift
struct FXDefinitionID: Hashable, Codable {
    let rawValue: String
}

struct FXDefinition: Codable {
    let id: FXDefinitionID
    let category: FXCategory
    let tags: Set<FXTag>
    let graph: FXGraphDefinition
    let defaultParameters: FXParameterSet
    let allowedRenderers: [FXRendererKind]
    let budgetClass: FXBudgetClass
    let deterministicMode: FXDeterminismMode
    let lodPolicy: FXLodPolicy
    let cullingPolicy: FXCullingPolicy
    let materialPolicy: FXMaterialPolicy
    let audioHooks: [FXAudioHook]
    let gameplayHooks: [FXGameplayHook]
}
```

### 4.2 `FXRecipe`

Une recette est une version paramétrique d’un effet pour un contexte donné.

```swift
struct FXRecipe: Codable {
    let definitionID: FXDefinitionID
    let variantRules: [FXVariantRule]
    let biomeOverrides: [BiomeID: FXParameterSet]
    let weatherOverrides: [WeatherStateID: FXParameterSet]
    let materialOverrides: [SurfaceMaterialID: FXParameterSet]
    let worldEraOverrides: [WorldEraID: FXParameterSet]
    let rarityRules: [FXRarityRule]
}
```

Exemple : `footstep_surface_response` peut générer poussière, neige, boue, éclaboussure, sable, cendres ou cristaux selon la surface.

### 4.3 `FXEvent`

Un événement déclencheur issu du gameplay ou du monde.

```swift
struct FXEvent {
    let id: UInt64
    let type: FXEventType
    let worldPosition: SIMD3<Float>
    let normal: SIMD3<Float>
    let velocity: SIMD3<Float>
    let intensity: Float
    let radius: Float
    let sourceEntityID: EntityID?
    let sourceMaterial: SurfaceMaterialID?
    let targetMaterial: SurfaceMaterialID?
    let biome: BiomeID
    let weather: WeatherSample
    let terrainSample: TerrainFXSample
    let seed: UInt64
    let timestampTick: UInt64
    let parameters: FXParameterSet
}
```

### 4.4 `FXContext`

Le contexte enrichit l’événement.

```swift
struct FXContext {
    let worldSeed: UInt64
    let chunkID: ChunkID
    let biomeSample: BiomeSample
    let weatherSample: WeatherSample
    let lightingSample: LightingSample
    let terrainSample: TerrainFXSample
    let materialSample: SurfaceMaterialSample
    let cameraDistance: Float
    let visibilityClass: VisibilityClass
    let performanceTier: PerformanceTier
    let worldRules: WorldRuleSample
}
```

---

## 5. Graphe FX moderne

### 5.1 Philosophie

Le graphe IPFX doit être proche de Niagara/Frostbite/VFX Graph dans l’esprit, mais plus simple au départ.

Un `FXGraph` contient :

- des emitters ;
- des modules ;
- des data interfaces ;
- des renderers ;
- des event links ;
- des paramètres exposés ;
- des règles de compilation.

### 5.2 Phases d’exécution

```text
System Init
System Update
Emitter Init
Emitter Spawn
Emitter Update
Particle Spawn
Particle Update
Particle Collision
Particle Event Output
Renderer Prepare
Renderer Draw
Post Composite
```

### 5.3 Types de modules

#### Spawn modules

- spawn rate constant ;
- spawn burst ;
- spawn by distance ;
- spawn by surface area ;
- spawn from point ;
- spawn from sphere ;
- spawn from cone ;
- spawn from capsule ;
- spawn from mesh vertices ;
- spawn from mesh surface ;
- spawn from skinned mesh bone ;
- spawn from terrain slope ;
- spawn from water edge ;
- spawn from collision event ;
- spawn from decal mask ;
- spawn from biome mask ;
- spawn from weather cell ;
- spawn from SDF shell ;
- spawn from noise threshold ;
- spawn from spline/path ;
- spawn from volume field.

#### Initialization modules

- initial position ;
- initial velocity ;
- initial color ;
- initial alpha ;
- initial size ;
- initial aspect ratio ;
- initial rotation ;
- initial angular velocity ;
- initial lifetime ;
- initial temperature ;
- initial wetness ;
- initial mass ;
- initial buoyancy ;
- initial drag ;
- initial material response ;
- initial sprite frame ;
- initial mesh index ;
- initial animation phase ;
- initial random stream.

#### Update modules

- gravity ;
- drag ;
- buoyancy ;
- curl noise ;
- vector field ;
- wind field ;
- vortex ;
- turbulence ;
- attraction point ;
- repulsion point ;
- orbit ;
- spline follow ;
- terrain conform ;
- water surface conform ;
- collision response ;
- friction ;
- bounce ;
- stick ;
- slide ;
- dissolve ;
- color over life ;
- alpha over life ;
- size over life ;
- temperature cooling ;
- smoke darkening ;
- light emission decay ;
- sprite flipbook advance ;
- mesh spin ;
- trail history update ;
- event emission ;
- kill conditions.

#### Collision modules

- heightfield collision ;
- terrain normal collision ;
- screen-space depth collision ;
- signed distance field collision ;
- capsule collision ;
- sphere collision ;
- box collision ;
- water plane collision ;
- vegetation proxy collision ;
- character capsule collision ;
- material-driven bounce/friction ;
- wetness-driven adhesion ;
- slope-driven slide ;
- stick-to-surface ;
- spawn-on-impact ;
- decal-on-impact.

#### Renderer modules

- sprite billboard ;
- camera-facing billboard ;
- axis-aligned billboard ;
- velocity-aligned billboard ;
- stretched billboard ;
- soft particle ;
- lit particle ;
- unlit particle ;
- mesh particle ;
- instanced mesh ;
- ribbon/trail ;
- beam ;
- decal ;
- light sprite ;
- distortion sprite ;
- flipbook volume impostor ;
- low-res transparent layer ;
- volumetric injection ;
- procedural mesh shader renderer.

---

## 6. Backends de simulation

### 6.1 Backend A — Stateless FX

Pour les effets simples, l’état peut être dérivé de :

```text
position = f(seed, time, emitterID, particleIndex)
```

Avantages :

- presque pas de mémoire persistante ;
- parfait pour poussières ambiantes, insectes distants, pluie lointaine, neige lointaine ;
- déterminisme simple ;
- LOD facile.

Inconvénients :

- collisions et interactions limitées ;
- moins naturel pour les effets denses complexes.

### 6.2 Backend B — CPU Events + GPU Stateless

Le CPU génère des événements stables, le GPU rend les particules.

Utilisation :

- footsteps ;
- impacts ;
- récolte de ressources ;
- crafting ;
- petites interactions gameplay ;
- objets qui cassent ;
- micro-éclaboussures.

### 6.3 Backend C — GPU Stateful Particles

Le GPU stocke et simule l’état des particules.

Buffers typiques :

```text
ParticlePositionBuffer
ParticleVelocityBuffer
ParticleColorLifeBuffer
ParticleSizeRotationBuffer
ParticleMaterialBuffer
ParticleRandomBuffer
AliveList
DeadList
EmitterCounters
IndirectDrawArgs
```

Utilisation :

- fumée ;
- feu ;
- pluie dense ;
- neige proche ;
- essaims ;
- magie ;
- débris ;
- cascades ;
- tempêtes.

### 6.4 Backend D — CPU Simulation courte

Certains effets doivent être calculés CPU :

- événements qui modifient le gameplay ;
- collisions précises avec personnages ;
- FX qui déclenchent des sons ou decals gameplay ;
- destruction légère synchronisée ;
- simulation déterministe réseau/sauvegarde si besoin futur.

### 6.5 Backend E — Baked Flipbook / Volume Impostor

Pour pyro/smoke/explosions très haute qualité :

- flipbook albedo/alpha ;
- normal map ;
- depth map ;
- motion vectors ;
- 6-point lighting ;
- emission ;
- temperature ;
- optional VDB offline.

Runtime :

- sprite/mesh billboard ;
- lit flipbook ;
- camera-facing volume impostor ;
- distortion/refraction ;
- shadow approximation ;
- decal + dynamic light.

### 6.6 Backend F — Volumetric Field Lite

Pour brouillard, nuages bas, fumées larges, poussières de tempête :

- froxel/grid basse résolution autour caméra ;
- injection de densité par emitters ;
- advection simplifiée ;
- dissipation ;
- lighting approximé ;
- reprojection temporelle ;
- compositing volumétrique.

---

## 7. Pipeline Metal proposé

### 7.1 Passes principales

```text
1. Opaque Geometry Depth/GBuffers or Forward+ Depth
2. Terrain / Props / Characters
3. Decal Pass
4. FX Spawn Compute
5. FX Sim Compute
6. FX Culling + LOD Compute
7. FX Sorting / Binning
8. Native Resolution FX
9. Low Resolution Soft FX
10. Volumetric Injection
11. Volumetric Lighting / Fog
12. Distortion / Heat Haze
13. Composite Transparent FX
14. Bloom / Tone Mapping / Post
```

### 7.2 Compute-first simulation

Metal compute kernels :

- spawn particles ;
- update particles ;
- collide particles ;
- compact alive list ;
- write indirect draw args ;
- sort/bin transparent particles ;
- update trails ;
- inject volumetric density ;
- update temporal buffers.

### 7.3 Argument buffers

Tous les emitters d’une frame doivent être groupés dans des argument buffers :

```text
FXFrameArgumentBuffer
- global constants
- camera
- weather field
- wind field
- terrain sample textures
- material tables
- particle buffers
- emitter buffers
- atlas textures
- noise textures
- depth textures
- lighting resources
```

But : réduire le coût CPU et faciliter le batching.

### 7.4 Indirect Command Buffers

Pour des milliers d’emitters potentiels :

- le CPU ne doit pas encoder chaque draw ;
- le GPU écrit les commandes de draw visibles ;
- le culling/LOD choisit les renderers actifs ;
- les ICB peuvent regrouper sprites, meshes, ribbons.

### 7.5 Mesh shaders

Sur machines compatibles, les mesh shaders peuvent rendre :

- billboards procéduraux sans générer de vertex buffers intermédiaires ;
- ribbons/trails ;
- meshlets de débris ;
- herbes/feuilles FX ;
- sparks/tubes lumineux ;
- micro-geometry FX.

Fallback : compute + vertex shader classique.

### 7.6 Low-res FX layer

Les effets soft doivent pouvoir être rendus dans une couche basse résolution :

- smoke ;
- fog puffs ;
- dust clouds ;
- heat haze large ;
- magic aura large ;
- snow mist ;
- sand storm.

Règles :

```text
if visualFrequency == low and screenCoverage > threshold:
    renderScale = 0.5 or 0.25
else:
    renderScale = 1.0
```

### 7.7 Soft particles

Les sprites doivent s’adoucir au contact de la géométrie via la profondeur scène.

Paramètres :

- softness distance ;
- near fade ;
- depth bias ;
- material-specific opacity ;
- noise erosion ;
- contact darkening.

### 7.8 Sorting et OIT

Approche recommandée par étapes :

1. Alpha blended simple pour POC.
2. Tri par emitter + distance pour FX importants.
3. Binning par tiles pour grosses scènes.
4. Weighted blended OIT pour nombreux effets translucides.
5. Cas spéciaux full-res pour feu/énergie/high-frequency.

### 7.9 Texture atlases et sparse textures

Ressources :

- flipbook atlas ;
- noise atlas ;
- normal/depth/motion atlas ;
- decal atlas ;
- vector field atlas ;
- LUTs couleur ;
- curve textures.

Sparse textures utiles si :

- atlas très grands ;
- monde très riche en variants ;
- streaming par biome ;
- FX rares chargés à la demande.

---

## 8. Intégration monde procédural

### 8.1 Data Interfaces IsoWorld

Équivalents internes des Data Interfaces Niagara :

```text
TerrainFXDataInterface
BiomeFXDataInterface
WeatherFXDataInterface
MaterialFXDataInterface
WaterFXDataInterface
WindFXDataInterface
LightingFXDataInterface
PropFXDataInterface
CharacterFXDataInterface
RPGRuleFXDataInterface
AudioFXDataInterface
```

### 8.2 TerrainFXDataInterface

Doit exposer :

- hauteur ;
- normale ;
- slope ;
- curvature ;
- roughness géométrique ;
- occlusion locale ;
- type de sol ;
- wetness ;
- snow depth ;
- mud depth ;
- sand looseness ;
- gravel amount ;
- vegetation density ;
- water proximity ;
- flow direction ;
- cave/interior factor ;
- cliff factor.

### 8.3 MaterialFXDataInterface

Chaque matériau doit définir sa réponse FX :

```swift
struct SurfaceFXResponse: Codable {
    let dustColor: ColorRGB
    let splashColor: ColorRGB
    let impactSparkChance: Float
    let debrisSizeRange: ClosedRange<Float>
    let footprintDecalStrength: Float
    let wetnessSplashMultiplier: Float
    let friction: Float
    let restitution: Float
    let adhesion: Float
    let soundProfile: SurfaceSoundProfileID
    let particlePalette: FXPaletteID
}
```

### 8.4 WeatherFXDataInterface

Expose :

- wind vector ;
- gustiness ;
- precipitation type ;
- precipitation intensity ;
- fog density ;
- humidity ;
- temperature ;
- pressure ;
- storm state ;
- cloud cover ;
- lightning probability ;
- snow accumulation ;
- evaporation potential.

### 8.5 RPGRuleFXDataInterface

Le seed RPG peut changer les FX :

- monde sans magie : pas de glow mystique ;
- monde toxique : fumées vertes, particules corrosives ;
- monde ancien : poussière, feu, forge, torches ;
- monde futuriste : hologrammes, plasma, scanlines, drones ;
- monde cristallin : reflets prismatiques, poussières minérales ;
- monde maudit : cendres inversées, brouillard sombre, particules organiques ;
- monde aquatique : gouttes, brume saline, algues flottantes ;
- monde glaciaire : poudrerie, cristaux, givre dynamique.

---

## 9. Déterminisme

### 9.1 Niveaux de déterminisme

```swift
enum FXDeterminismMode {
    case none                   // pur cosmétique local
    case seedStableVisual        // même seed ≈ même look
    case eventDeterministic      // mêmes events = mêmes paramètres
    case gameplayAuthoritative   // doit être stable pour sauvegarde/réseau
}
```

### 9.2 Génération stable

Chaque effet reçoit :

```text
FXSeed = hash(worldSeed, chunkID, eventID, effectDefinitionID, emitterIndex)
```

Chaque particule reçoit :

```text
ParticleSeed = hash(FXSeed, spawnTick, particleIndex)
```

### 9.3 Ce qui doit être déterministe

- choix de l’effet ;
- choix de la variante ;
- intensité de base ;
- nombre de bursts gameplay ;
- decals persistants ;
- modifications de terrain ;
- propagation de feu si gameplay ;
- contamination/toxicité si gameplay.

### 9.4 Ce qui peut être perceptuel

- turbulence fine ;
- micro-poussières ;
- bruit volumétrique ;
- ordre exact de particules transparentes ;
- fluctuations de lumière cosmétique ;
- petits embers secondaires.

---

## 10. Variantes paramétriques

### 10.1 Axes de variation

Un effet peut varier selon :

- seed global ;
- biome ;
- sous-biome ;
- météo ;
- saison ;
- heure ;
- matériau ;
- humidité ;
- température ;
- altitude ;
- exposition au vent ;
- proximité de l’eau ;
- profondeur de neige ;
- pente ;
- vitesse de l’objet ;
- masse de l’objet ;
- énergie d’impact ;
- type de chaussure ;
- type d’arme ;
- époque du monde ;
- niveau technologique ;
- magie présente ou non ;
- état narratif ;
- pollution ;
- corruption ;
- rareté.

### 10.2 Exemple : pas du joueur

```text
FootstepFX
Inputs:
- surfaceMaterial
- wetness
- snowDepth
- mudDepth
- footSpeed
- actorMass
- shoeType
- slope
- vegetationDensity

Outputs:
- decal footprint
- dust puff OR mud splash OR snow powder OR gravel kick
- micro debris
- sound event
- optional wet glisten decal
```

Règles :

```text
if snowDepth > 0.2:
    spawn snow powder + footprint compression decal
elif wetness > 0.6 and mudDepth > 0.25:
    spawn mud splash + sticky droplets + dark wet decal
elif surface == dry_sand:
    spawn sand puff + sliding grains
elif surface == gravel:
    spawn small pebbles + dust
elif surface == metal:
    no dust, maybe tiny spark if high impact
```

### 10.3 Exemple : feu

Paramètres :

- fuel type ;
- oxygen ;
- wind ;
- humidity ;
- rain ;
- temperature ;
- magic/tech style ;
- age ;
- size ;
- heat output ;
- smoke color ;
- ember count.

Variantes :

- feu de bois sec ;
- feu humide fumant ;
- braises faibles ;
- feu magique bleu ;
- feu toxique vert ;
- plasma futuriste ;
- combustion lente ;
- torche ;
- forge ;
- incendie de forêt ;
- explosion courte.

### 10.4 Exemple : eau

Paramètres :

- flow speed ;
- depth ;
- salinity ;
- wind ;
- slope ;
- turbulence ;
- collision energy ;
- foam amount ;
- suspended sediment ;
- temperature.

Effets :

- gouttes ;
- spray ;
- mist ;
- foam ;
- ripples ;
- impact rings ;
- wet decals ;
- condensation ;
- vapor ;
- ice crystals.

---

## 11. Très longue taxonomie de FX générables

### 11.1 FX terrain et sol

- poussière de pas sur terre sèche ;
- poussière de course ;
- poussière de glissade ;
- nuage de sable ;
- grains de sable individuels ;
- sable poussé par le vent ;
- sable qui tombe d’une dune ;
- poussière de falaise ;
- éclats de roche ;
- gravier déplacé ;
- cailloux projetés ;
- boue écrasée ;
- éclaboussures de boue ;
- gouttelettes de boue collantes ;
- sol spongieux compressé ;
- tourbe humide ;
- spores de mousse ;
- feuilles mortes soulevées ;
- aiguilles de pin déplacées ;
- herbe coupée ;
- pollen au ras du sol ;
- cendres au sol ;
- poussière volcanique ;
- poussière de craie ;
- poussière de ruine ;
- débris de brique ;
- débris de béton ;
- fragments de carrelage ;
- copeaux de bois ;
- sciure ;
- paille ;
- neige poudreuse ;
- neige compacte ;
- cristaux de glace ;
- givre qui se détache ;
- glace pilée ;
- sel marin au sol ;
- poussière métallique ;
- micro-étincelles sur sol métallique ;
- traces lumineuses temporaires sur sol magique ;
- corruption organique qui fume ;
- sol toxique qui bulle ;
- champignons qui libèrent spores ;
- sable vitrifié qui craque.

### 11.2 FX eau

- éclaboussure de pas dans flaque ;
- gouttes suspendues ;
- cercles d’impact ;
- spray de cascade ;
- brume de cascade ;
- mousse de rivière ;
- écume marine ;
- embruns ;
- vaguelette contre rocher ;
- eau qui ruisselle sur pente ;
- filets d’eau sur falaise ;
- gouttes depuis stalactites ;
- condensation ;
- vapeur chaude ;
- brouillard froid au-dessus d’un lac ;
- bulles sous-marines ;
- bulles toxiques ;
- bouillonnement volcanique ;
- eau boueuse projetée ;
- eau glacée cristallisée ;
- brume saline ;
- pluie sur eau ;
- pluie sur roche ;
- pluie sur feuilles ;
- gouttes depuis feuillage ;
- traînées de bateau ;
- sillages ;
- micro-particules de limon ;
- algues flottantes ;
- mousse stagnante ;
- vapeur d’égout ;
- geyser ;
- source chaude ;
- explosion d’eau magique ;
- portail liquide ;
- colonne d’eau ;
- distorsion aquatique.

### 11.3 FX feu, chaleur, fumée

- feu de camp ;
- torche ;
- bougie ;
- lanterne ;
- forge ;
- braises ;
- étincelles ;
- fumée fine ;
- fumée noire ;
- fumée blanche humide ;
- fumée toxique ;
- fumée magique ;
- flammes courtes ;
- flammes hautes ;
- flammes au vent ;
- feu rampant sur sol ;
- feuillage qui brûle ;
- arbre en feu ;
- explosion de gaz ;
- explosion poudreuse ;
- flash thermique ;
- onde de choc ;
- heat haze ;
- air scintillant ;
- cendres montantes ;
- cendres tombantes ;
- résidus incandescents ;
- métal chauffé ;
- lave qui crépite ;
- magma bullant ;
- fissures lumineuses ;
- steam burst ;
- combustion magique bleue ;
- feu fantôme ;
- plasma futuriste ;
- arc électrique thermique ;
- brûlure de laser ;
- dissipation de bouclier énergétique.

### 11.4 FX météo

- pluie légère ;
- pluie dense ;
- pluie oblique ;
- bruine ;
- gouttes de tempête ;
- splash de pluie au sol ;
- neige légère ;
- neige dense ;
- poudrerie ;
- blizzard ;
- grésil ;
- cristaux suspendus ;
- brouillard de vallée ;
- brouillard côtier ;
- brouillard toxique ;
- brume matinale ;
- nuages bas ;
- poussière atmosphérique ;
- tempête de sable ;
- tempête de cendres ;
- vents de feuilles ;
- pollen saisonnier ;
- spores ;
- éclairs ;
- flash lointain ;
- impact de foudre ;
- électrisation de l’air ;
- arc entre objets ;
- halo humide autour des lumières ;
- gouttes sur caméra ;
- givre dynamique ;
- haleine visible ;
- vapeur corporelle ;
- condensation sur métal ;
- pluie acide ;
- neige noire ;
- tempête magnétique ;
- pluie de météores ;
- poussière cosmique.

### 11.5 FX végétation / biome

- feuilles qui tombent ;
- feuilles qui tourbillonnent ;
- pétales ;
- pollen ;
- spores fongiques ;
- graines volantes ;
- herbe qui relâche poussière ;
- branches secouées ;
- écorce qui s’effrite ;
- sève qui goutte ;
- liane qui libère particules ;
- champignons luminescents ;
- poussière bioluminescente ;
- insectes autour de plantes ;
- lucioles ;
- essaim de moucherons ;
- papillons lointains ;
- insectes de marais ;
- plumes ;
- graines brûlées ;
- spores toxiques ;
- pollen allergène ;
- poussière de feuilles mortes ;
- cristaux organiques ;
- particules d’arbre magique ;
- racines qui déplacent la terre ;
- feuilles gelées qui cassent ;
- mousse qui émet vapeur ;
- algues lumineuses.

### 11.6 FX impacts / combat / gameplay physique

- impact pierre sur pierre ;
- impact métal sur pierre ;
- impact bois sur bois ;
- impact épée métal ;
- étincelle d’arme ;
- arc électrique d’arme tech ;
- poussière d’impact ;
- fragmentation légère ;
- éclats de bois ;
- éclats de verre ;
- éclats de cristal ;
- éclats d’os stylisés ;
- impact sur bouclier ;
- ripple de bouclier ;
- projectile qui traverse fumée ;
- trail de flèche ;
- trail de balle ;
- trail plasma ;
- muzzle flash ;
- fumée de tir ;
- cartouche éjectée ;
- onde de choc ;
- shock dust ring ;
- stomp au sol ;
- écrasement de sol ;
- burst d’énergie ;
- absorption d’énergie ;
- soin magique ;
- poison ;
- gel ;
- brûlure ;
- saignement stylisé ;
- impact non violent abstrait ;
- stun stars ;
- désintégration ;
- matérialisation ;
- téléportation ;
- portail ;
- scan holographique ;
- hack numérique ;
- rune qui s’allume.

### 11.7 FX objets / props

- poussière qui tombe d’une table ;
- fumée de cheminée ;
- vapeur de cuisine ;
- bulles de chaudron ;
- forge sparks ;
- scie/atelier sciure ;
- machine tech qui fume ;
- tuyau vapeur ;
- fuite d’eau ;
- fuite de gaz ;
- lampe qui attire insectes ;
- ampoule qui grésille ;
- néon flicker ;
- panneau holographique ;
- particules de téléporteur ;
- poussière de ruine ;
- sable dans temple ancien ;
- bibliothèque poussiéreuse ;
- livre magique ;
- parchemin qui brûle ;
- cristal qui pulse ;
- minerai qui scintille ;
- ressource récoltée ;
- coffre ouvert ;
- serrure forcée ;
- mécanisme ancien ;
- engrenages poussiéreux ;
- alarme tech ;
- générateur instable ;
- batterie énergétique ;
- antenne radio ;
- drone trail ;
- robot sparks ;
- textile qui libère poussière ;
- verre qui se brise.

### 11.8 FX animaux / personnages

- haleine froide ;
- vapeur corporelle ;
- poussière de course ;
- gouttes d’eau après nage ;
- poils/plumes détachés ;
- insectes attirés ;
- aura de fatigue ;
- sueur stylisée ;
- frottement sur mur ;
- glissade sur boue ;
- neige projetée par bottes ;
- cape trail ;
- vêtement poussiéreux ;
- spark d’armure ;
- énergie d’arme ;
- magic casting hands ;
- trail de mouvement rapide ;
- atterrissage lourd ;
- saut dans eau ;
- grimpe falaise poussière ;
- corde frottée poussière ;
- respiration toxique ;
- aura de statut ;
- buff/debuff ;
- maladie visible ;
- invisibilité ;
- matérialisation partielle ;
- transformation ;
- scan corporel ;
- shield hit ;
- dash trail.

### 11.9 FX magie / fantastique / anomalie

- runes flottantes ;
- glyphes ;
- cercles rituels ;
- poussières d’étoiles ;
- fragments de lumière ;
- brume spectrale ;
- feu follet ;
- âme stylisée ;
- cristaux flottants ;
- particules inversées ;
- pluie ascendante ;
- gravité locale visible ;
- distorsion spatiale ;
- portail vortex ;
- fissure dimensionnelle ;
- champ de force ;
- aura divine ;
- aura maudite ;
- corruption rampante ;
- purification ;
- sort de soin ;
- sort de poison ;
- sort de glace ;
- sort de feu ;
- sort de foudre ;
- sort de terre ;
- télékinésie ;
- cristallisation ;
- désintégration ;
- transformation de biome ;
- apparition mythique ;
- objet légendaire qui pulse ;
- constellation au sol ;
- nuage de mana ;
- poussière temporelle.

### 11.10 FX science-fiction / technologie

- hologramme ;
- scanline ;
- grille énergétique ;
- particules de téléportation ;
- plasma ;
- laser impact ;
- muzzle flash tech ;
- smoke coolant ;
- steam vent ;
- sparks électriques ;
- arc haute tension ;
- écran cassé ;
- nanobots visibles ;
- drones micro-particles ;
- champ magnétique ;
- shield ripple ;
- stealth shimmer ;
- glitch spatial ;
- corruption numérique ;
- pixel dissolve ;
- data stream ;
- circuit glow ;
- batterie surcharge ;
- moteur ionique ;
- réacteur ;
- gaz cryogénique ;
- fuite radioactive stylisée ;
- particules orbitales ;
- gravité artificielle ;
- warp trail ;
- scan environnemental.

### 11.11 FX macro-monde

- brouillard de biome ;
- nuage de spores régional ;
- tempête de sable régionale ;
- neige de montagne ;
- embruns côtiers ;
- poussière désertique ;
- cendres volcaniques ;
- pluie acide ;
- nuée d’insectes ;
- migration de lucioles ;
- particules de corruption ;
- aura de zone sacrée ;
- radiation tech ;
- effet de portail mondial ;
- météor shower ;
- anneaux atmosphériques ;
- pollen saisonnier global ;
- feuilles automnales ;
- givre progressif ;
- fumée de ville ;
- pollution industrielle ;
- poussières de ruines ;
- micro-cristaux polaires ;
- vapeur de marais ;
- gaz de grotte ;
- brume de canyon.

---

## 12. Règles de génération

### 12.1 Règle générale

```text
FX = Resolve(
    eventType,
    worldRuleDNA,
    biome,
    subBiome,
    terrainFeature,
    material,
    weather,
    season,
    timeOfDay,
    actorState,
    gameplayTags,
    distanceToCamera,
    performanceBudget,
    seed
)
```

### 12.2 Règles de style par monde

Exemples :

```text
WorldFXStyle = realistic_natural
- palette terre/eau/feu réaliste
- peu d’émissif
- fumées physiques
- pas de particules magiques

WorldFXStyle = mythic_low_magic
- glow rare
- runes sur événements importants
- particules subtiles autour des lieux sacrés

WorldFXStyle = high_magic
- particules visibles dans l’air
- couleurs irréelles
- effets de biome surnaturels

WorldFXStyle = hard_scifi
- hologrammes, plasma, scanlines
- peu de poussière organique
- FX propres et géométriques

WorldFXStyle = post_apocalyptic
- poussière, cendres, pollution
- sparks, vapeur, fuites toxiques

WorldFXStyle = alien_ecosystem
- spores, bioluminescence, fluides colorés
- vents de particules organiques
```

### 12.3 Règles biome

```text
Desert:
- dustMultiplier high
- waterSplash low
- windSand high
- heatHaze high

WetForest:
- pollen/spores medium
- wetFootsteps high
- leafDrips high
- fog medium

Arctic:
- snowPowder high
- breathSteam high
- dust low
- iceCrystals high

Volcanic:
- ash high
- ember high
- heatHaze high
- toxicGas medium

Swamp:
- fog high
- bubbles high
- insects high
- mudSplash high

UrbanTech:
- sparks high
- steamVents high
- holograms medium
- dust depends on decay
```

### 12.4 Règles matériau

```text
DryDirt:
- footstep: dust puff
- impact: dust + tiny pebbles

WetMud:
- footstep: splash + sticky droplets
- impact: dark blobs + wet decal

SnowPowder:
- footstep: powder burst
- impact: plume + compression decal

Ice:
- footstep: small shards if hard impact
- impact: cracks + crystals

Metal:
- footstep: no dust, possible clang spark
- impact: sparks + tiny metal flakes

Wood:
- impact: splinters + dust
- fire: embers + smoke

Crystal:
- impact: sharp shards + prism glints
- magic: resonance particles
```

### 12.5 Règles intensité

```text
intensity = base
    * massFactor
    * velocityFactor
    * materialResponse
    * wetnessResponse
    * slopeResponse
    * biomeModifier
    * worldStyleModifier
```

### 12.6 Règles de densité

```text
particleCount = clamp(
    baseCount * intensity * visibility * qualityTier,
    minCount,
    maxCount
)
```

### 12.7 Règles de couleur

```text
particleColor = blend(
    materialColor,
    biomeAtmosphereColor,
    weatherTint,
    worldStylePalette,
    randomVariation
)
```

### 12.8 Règles de durée

```text
lifetime = baseLifetime
    * humidityMultiplier
    * windMultiplier
    * temperatureMultiplier
    * scaleMultiplier
```

### 12.9 Règles de mouvement

```text
velocity = eventVelocity * inheritance
    + normal * normalImpulse
    + tangentRandom * scatter
    + wind * windInfluence
    + turbulence(seed)
```

---

## 13. Collision et interaction

### 13.1 Hiérarchie de collision FX

Les FX doivent utiliser plusieurs niveaux selon le coût :

```text
Level 0: no collision
Level 1: depth buffer collision
Level 2: terrain heightfield collision
Level 3: local SDF collision
Level 4: simple collider set
Level 5: gameplay physics callback
```

### 13.2 Terrain collision

Pour poussières, neige, boue, débris :

- sample heightfield ;
- sample normal ;
- sample material ;
- bounce/slide/stick selon friction ;
- spawn decal si collision forte ;
- kill si sous terrain.

### 13.3 Screen-space collision

Utile pour :

- pluie visible ;
- sparks ;
- petits débris ;
- gouttes ;
- magie légère.

Limites :

- dépend de la caméra ;
- ne voit pas les objets hors écran ;
- peut être instable derrière objets transparents ;
- pas gameplay-authoritative.

### 13.4 SDF local

Utile pour :

- fumée autour props ;
- particules qui contournent rochers ;
- neige qui tombe autour arbres ;
- brume de grotte ;
- sparks dans intérieur.

### 13.5 Matériaux de collision

Chaque collision renvoie :

```text
normal
surfaceMaterial
wetness
roughness
friction
restitution
adhesion
temperature
isWater
isVegetation
isSnow
```

### 13.6 Événements secondaires

Une collision peut générer :

- nouveau burst ;
- decal ;
- sound event ;
- light flash ;
- trail change ;
- terrain wetness update ;
- gameplay event si autorisé.

---

## 14. Rendu haute qualité

### 14.1 Lit particles

Les particules importantes doivent être éclairées :

- directional light ;
- ambient/IBL approximée ;
- local lights clusterisées ;
- fake normal map ;
- flipbook normals ;
- rim lighting ;
- volumetric shadow approximation.

### 14.2 Flipbook lit

Pour fumées/feux :

- atlas color/alpha ;
- normal/depth ;
- motion vectors ;
- emissive ;
- temperature ;
- 6-point lighting si disponible.

### 14.3 Decals couplés aux FX

Beaucoup d’effets doivent laisser une trace :

- scorch mark ;
- wet footprint ;
- mud splat ;
- snow compression ;
- blood/stain stylisé si autorisé par direction artistique ;
- magic rune ;
- oil spill ;
- acid burn ;
- dust accumulation ;
- crack decal ;
- frost decal.

### 14.4 Distortion

Effets de distorsion :

- heat haze ;
- shockwave ;
- magic portal ;
- underwater ripple ;
- shield impact ;
- stealth shimmer ;
- plasma.

Rendu :

- distortion vector buffer ;
- blur contrôlé ;
- mask de profondeur ;
- limitation forte de budget.

### 14.5 Lumières FX

Certaines particules peuvent produire de la lumière :

- feu ;
- explosion ;
- magie ;
- plasma ;
- sparks ;
- lucioles ;
- cristaux.

Règles :

- pas une lumière par particule ;
- générer des light proxies agrégées ;
- clusterisées ;
- cullées ;
- intensité lissée temporellement ;
- LOD en emissive-only à distance.

### 14.6 Volumetric injection

Les grands FX doivent injecter dans une grille volumétrique :

- fumée ;
- fog ;
- dust ;
- ash ;
- snow mist ;
- toxic gas ;
- magic mist.

Chaque injection :

```text
density
albedo
emission
anisotropy
temperature
velocity
dissipation
```

---

## 15. LOD, budgets et performance

### 15.1 Classes de budget

```swift
enum FXBudgetClass {
    case tiny       // footsteps, small sparks
    case small      // torch, small impact
    case medium     // campfire, waterfall local
    case large      // explosion, dense smoke
    case world      // storm, regional fog
}
```

### 15.2 LOD paramètres

```text
LOD0:
- full particles
- collision enabled
- lit shading
- decals
- sound/light hooks

LOD1:
- reduced count
- simple collision
- simpler material
- reduced lights

LOD2:
- stateless approximation
- no collision
- low-res render
- no decals

LOD3:
- flipbook/impostor
- no simulation
- coarse animation

LOD4:
- culled or ambient baked contribution
```

### 15.3 Culling

Critères :

- distance caméra ;
- screen size ;
- visibility/occlusion ;
- importance gameplay ;
- audio relevance ;
- biome ambiance ;
- indoors/outdoors ;
- weather relevance ;
- performance pressure.

### 15.4 Pooling

Éviter allocations runtime :

- pool d’emitters ;
- pool de particle buffers ;
- pool de decals ;
- ring buffers d’événements ;
- persistent GPU buffers ;
- compact alive lists.

### 15.5 Overdraw control

Règles :

- limiter taille écran des sprites ;
- low-res pour soft FX ;
- alpha erosion/noise pour éviter grands quads pleins ;
- culling par tile ;
- clamp de densité par écran ;
- max overdraw budget ;
- heatmap debug.

### 15.6 Budgets cibles initiaux MacBook Pro M1

Valeurs de départ à ajuster par profilage :

```text
Frame FX budget target: 1.5–3.0 ms en scène normale
Heavy FX burst target: max 5.0 ms très ponctuel
GPU particles active near camera: 50k–150k selon complexité
Ambient stateless particles: beaucoup plus possibles si très simples
Decals visibles: 128–512 selon taille/coût
Dynamic FX lights: 8–32 agrégées
Volumetric grid: résolution adaptative, faible au départ
```

Important : ces chiffres sont des **ordres de grandeur initiaux**, pas des garanties. Le profiling Metal décidera.

---

## 16. Authoring tools

### 16.1 FX Editor interne

À terme, IsoWorld devrait avoir un outil simple :

- liste des FX definitions ;
- graph ou stack de modules ;
- preview viewport ;
- simulation avec seed ;
- sliders de contexte ;
- preview biome/material/weather ;
- heatmap overdraw ;
- particle count ;
- GPU time ;
- LOD preview ;
- export JSON/binaire.

### 16.2 Format data

Prototype : JSON/YAML lisible.

Production : format binaire compilé.

```text
Assets/FX/
  definitions/
    footstep_surface_response.fx.json
    campfire.fx.json
    waterfall_mist.fx.json
  materials/
    fx_palettes.json
    surface_fx_response.json
  atlases/
    smoke_flipbooks.ktx
    sparks.ktx
  compiled/
    fx_database.ipfxbin
```

### 16.3 Graph compilation

Pipeline :

```text
FXGraph source
→ validation
→ parameter binding
→ module specialization
→ shader code generation / function constants
→ pipeline state cache
→ runtime compact data
```

### 16.4 Preview matrix

Chaque effet doit être testé sur une matrice :

```text
Materials: dirt, sand, mud, snow, ice, rock, wood, metal, crystal
Weather: dry, rain, storm, snow, fog, hot, freezing
Biomes: forest, desert, mountain, swamp, coast, volcanic, urban
Distances: near, mid, far
Quality: low, medium, high
```

---

## 17. Relations avec autres systèmes IsoWorld

### 17.1 Avec le terrain

- terrain fournit matériaux, normales, wetness ;
- FX génère decals, poussières, wet splashes ;
- certains decals peuvent modifier temporairement la surface ;
- grosses explosions peuvent demander au terrain une déformation gameplay si autorisée.

### 17.2 Avec les biomes

- biome choisit palette, densité, ambient FX ;
- transitions de biome peuvent générer FX propres : brume, feuilles, poussière, cristaux ;
- sous-biomes ajoutent micro-FX : marais = bulles/insectes ; forêt humide = gouttes/spores.

### 17.3 Avec la météo

- pluie/neige/fog sont des systèmes FX persistants ;
- météo module les effets locaux ;
- vent influence toutes les particules ;
- orage déclenche lumière/foudre/impacts.

### 17.4 Avec les props procéduraux

Les props doivent exposer :

- sockets d’émission ;
- surfaces émissives ;
- colliders FX ;
- material response ;
- state tags : burning, wet, broken, powered, cursed.

### 17.5 Avec l’animation

Les animations génèrent des events :

- footstep ;
- hand contact ;
- weapon swing ;
- landing ;
- slide ;
- climb dust ;
- rope friction ;
- cape trail ;
- breath.

### 17.6 Avec l’audio

Chaque effet peut déclencher ou moduler un son :

- intensity ;
- material ;
- wetness ;
- distance ;
- occlusion ;
- biome reverb ;
- weather muffling.

---

## 18. Exemples détaillés

### 18.1 Footstep ultra paramétrique

```text
FXDefinition: footstep_surface_response
Emitters:
- impact_dust_or_splash
- micro_debris
- footprint_decal
- optional_leaf_puff
- optional_snow_powder
- optional_wet_droplets
```

Règles :

```text
if material == mud and wetness > 0.5:
    use splash droplets
    droplet adhesion high
    decal dark/wet
elif material == snow:
    use powder burst
    decal compression
elif material == gravel:
    mesh particles pebbles
    dust small
elif material == dry_dirt:
    dust high
elif material == metal:
    particle count low
    spark chance if impactEnergy high
```

Paramètres chaussure :

```text
barefoot: less dust, more wet contact
soft_shoe: low impact
leather_boot: medium dust/splash
heavy_boot: high impact, deeper decals
metal_boot: sparks on hard materials
snow_boot: larger compression, less slide
```

### 18.2 Falaise / escalade / corde

Événements :

- main contact rock ;
- foot scrape ;
- rope friction ;
- rock chip ;
- dust fall ;
- small pebble fall.

FX :

- poussière directionnelle vers le bas ;
- micro cailloux mesh particles ;
- decals d’abrasion légers ;
- corde qui libère fibres/poussière ;
- frottement selon matériau : roche sèche, roche mouillée, glace, mousse.

### 18.3 Cascade

Composants :

- water streak mesh/ribbon ;
- spray particles ;
- mist volumetric injection ;
- foam decals/particles ;
- wetness decals sur roches ;
- sound emitter ;
- wind local.

Paramètres :

- débit ;
- hauteur ;
- turbulence ;
- température ;
- vent ;
- saleté/sédiments ;
- saison ;
- biome.

### 18.4 Tempête de sable

Composants :

- particules stateless longue distance ;
- poussière proche GPU ;
- volumetric density ;
- decals temporaires de sable ;
- occlusion atmosphérique ;
- wind gust field ;
- son de vent.

LOD :

- loin : sky/fog color + volume ;
- mi-distance : stateless particles ;
- proche : GPU particles collision terrain ;
- très proche : camera streaks.

### 18.5 Explosion non-raytraced

Composants :

- flash sprite emissive ;
- dynamic light proxy ;
- shockwave distortion ;
- debris mesh particles ;
- smoke flipbook lit ;
- dust ring terrain ;
- scorch decal ;
- camera shake hook ;
- audio hook.

Budget :

- burst court ;
- smoke low-res ;
- debris native res ;
- lights agrégées ;
- collision approximée.

---

## 19. Système de fields

Les fields contrôlent les effets dans l’espace.

### 19.1 Types de fields

- wind vector field ;
- gust field ;
- temperature field ;
- humidity field ;
- density field ;
- magic influence field ;
- toxicity field ;
- fire heat field ;
- water flow field ;
- gravity anomaly field ;
- sound pressure field ;
- gameplay danger field.

### 19.2 Sources de fields

- météo globale ;
- terrain/hydrologie ;
- props ;
- personnages ;
- événements RPG ;
- explosions ;
- biomes ;
- portails ;
- machines ;
- feux.

### 19.3 Résolution

- fields globaux basse fréquence ;
- fields chunkés ;
- fields locaux temporaires ;
- textures 2D pour terrain ;
- volumes 3D pour brouillard/fumée ;
- buffers de primitives pour sources dynamiques.

---

## 20. Debugging et métriques

### 20.1 Overlays indispensables

- particle count per system ;
- active emitters ;
- GPU time per pass ;
- overdraw heatmap ;
- low-res FX mask ;
- collision mode debug ;
- LOD level ;
- culling reason ;
- emitter bounds ;
- event stream ;
- decal count ;
- volumetric density ;
- atlas residency ;
- seed/variant display.

### 20.2 Validation

Chaque FXDefinition doit valider :

- pas de paramètre manquant ;
- renderer compatible ;
- budget déclaré ;
- bounds corrects ;
- atlas disponible ;
- shader compilable ;
- LOD présent ;
- culling policy présente ;
- collisions autorisées ;
- deterministic mode cohérent.

### 20.3 Tests automatiques

- snapshot rendu avec seed fixe ;
- budget GPU maximal ;
- nombre max particules ;
- no NaN in buffers ;
- no runaway emitter ;
- atlas missing check ;
- deterministic event replay ;
- LOD transition visual test.

---

## 21. Proposition d’implémentation progressive

### Phase 1 — Base CPU simple mais data-driven

Objectif : construire le modèle système.

- `FXDefinition` ;
- `FXEvent` ;
- `FXContext` ;
- sprites billboards ;
- burst simple ;
- color/size/lifetime over life ;
- footstep dust/splash ;
- impact sparks ;
- basic decals ;
- seed stable.

### Phase 2 — GPU particles Metal

- buffers SoA ;
- spawn compute ;
- update compute ;
- alive/dead list ;
- indirect draw args ;
- depth collision simple ;
- soft particles ;
- flipbook rendering.

### Phase 3 — Parametric material/weather responses

- `SurfaceFXResponse` ;
- wetness/snow/mud ;
- terrain sampling ;
- biome palettes ;
- weather modulation ;
- wind fields ;
- footstep system avancé.

### Phase 4 — Renderers avancés

- mesh particles ;
- ribbons/trails ;
- beams ;
- distortion ;
- lit flipbooks ;
- low-res particles ;
- decals avancés.

### Phase 5 — Volumetric lite

- froxel grid ;
- density injection ;
- fog/smoke/dust ;
- temporal reprojection ;
- light approximation ;
- weather macro FX.

### Phase 6 — Tooling

- preview editor ;
- graph/stack module authoring ;
- debug overlays ;
- performance budget ;
- snapshot tests ;
- compiled FX database.

### Phase 7 — WorldRuleDNA integration

- styles par monde ;
- magie/tech/corruption ;
- époques ;
- FX rares par seed ;
- anomalies globales ;
- règles RPG qui changent les FX.

---

## 22. Design de fichiers recommandé

```text
EngineCore/
  FX/
    FXDefinition.swift
    FXEvent.swift
    FXContext.swift
    FXRecipe.swift
    FXGraph.swift
    FXModule.swift
    FXParameterSet.swift
    FXVariantResolver.swift
    FXBudget.swift
    FXDataInterfaces.swift
    FXDeterminism.swift

MetalRenderer/
  FX/
    MetalFXSystem.swift
    MetalFXBuffers.swift
    MetalFXRenderer.swift
    MetalFXParticlePass.swift
    MetalFXDecalPass.swift
    MetalFXVolumetricPass.swift
    MetalFXSorting.swift
    MetalFXDebug.swift

Shaders/
  FX/
    FXCommon.metal
    FXSpawn.compute.metal
    FXUpdate.compute.metal
    FXCollision.compute.metal
    FXSprite.render.metal
    FXMeshParticle.render.metal
    FXRibbon.render.metal
    FXDecal.render.metal
    FXVolumetric.compute.metal
    FXComposite.render.metal

Assets/
  FX/
    definitions/
    recipes/
    palettes/
    atlases/
    curves/
    vector_fields/
```

---

## 23. Modèle de données compact GPU

### 23.1 Particle SoA

```metal
struct ParticlePosition {
    float3 position;
    float life;
};

struct ParticleVelocity {
    float3 velocity;
    float age;
};

struct ParticleVisual {
    half4 color;
    half2 size;
    half rotation;
    half frame;
};

struct ParticleMaterial {
    ushort materialID;
    ushort flags;
    uint randomSeed;
};
```

### 23.2 Emitter GPU data

```metal
struct FXEmitterGPU {
    uint definitionID;
    uint firstParticle;
    uint maxParticles;
    uint aliveCount;
    float3 position;
    float radius;
    float4 params0;
    float4 params1;
    uint rendererKind;
    uint collisionMode;
    uint lodLevel;
    uint flags;
};
```

### 23.3 Event ring buffer

```swift
struct FXEventGPU {
    var id: UInt64
    var type: UInt32
    var seed: UInt32
    var position: SIMD3<Float>
    var intensity: Float
    var normal: SIMD3<Float>
    var radius: Float
    var velocity: SIMD3<Float>
    var materialID: UInt32
    var biomeID: UInt32
    var packedWeather: UInt32
}
```

---

## 24. Règles de qualité artistique

### 24.1 Éviter le look “particle engine cheap”

- ne pas abuser des sprites ronds ;
- utiliser des flipbooks haute qualité ;
- varier taille, rotation, alpha, vitesse ;
- ajouter collisions quand proche ;
- utiliser soft particles ;
- lier couleur au matériau ;
- ajouter decals pour ancrer l’effet ;
- ajouter light/distortion avec parcimonie ;
- éviter les répétitions visibles ;
- utiliser des curves authorées.

### 24.2 Ancrage physique simplifié

Même stylisé, un bon FX doit respecter :

- gravité ;
- inertie ;
- friction ;
- vent ;
- humidité ;
- dissipation ;
- température ;
- densité ;
- matériau.

### 24.3 Lisibilité gameplay

Les FX doivent aussi communiquer :

- danger ;
- zone d’effet ;
- direction ;
- intensité ;
- rareté ;
- état élémentaire ;
- timing ;
- feedback d’impact.

### 24.4 Cohérence monde

Chaque monde généré doit avoir une signature FX :

- palette ;
- densité atmosphérique ;
- type de particules ambiantes ;
- magie/tech ;
- saleté/poussière ;
- humidité ;
- réaction des matériaux ;
- présence d’anomalies.

---

## 25. Systèmes FX supplémentaires pour enrichir IsoWorld

### 25.1 FX Director

Un système qui module les FX selon la scène :

- réduire densité en combat lourd ;
- augmenter ambiance en exploration ;
- intensifier météo avant événement ;
- déclencher FX rares ;
- éviter saturation visuelle ;
- respecter budget frame.

### 25.2 FX Ecology

Les FX ambiants suivent l’écologie :

- insectes selon humidité/température ;
- pollen selon saison ;
- spores selon champignons ;
- lucioles selon nuit/eau ;
- cendres selon volcans/incendies ;
- poussière selon sécheresse.

### 25.3 FX Memory

Le monde garde des traces :

- footprints temporaires ;
- boue projetée ;
- neige tassée ;
- brûlures ;
- pollution ;
- givre ;
- humidité locale ;
- poussière accumulée.

### 25.4 FX Anomalies

Selon le seed RPG :

- particules qui montent au lieu de tomber ;
- pluie lumineuse ;
- brouillard qui fuit les lumières ;
- cendres qui dessinent des runes ;
- cristaux qui chantent visuellement ;
- poussières temporelles ;
- glitchs spatiaux ;
- biomes avec météo inversée.

### 25.5 FX Crafting

Chaque métier peut avoir ses FX :

- forge ;
- cuisine ;
- alchimie ;
- couture ;
- menuiserie ;
- cristallurgie ;
- électronique ;
- hacking ;
- botanique ;
- rituel ;
- médecine ;
- enchantement ;
- ingénierie.

---

## 26. Risques techniques

### 26.1 Trop d’overdraw

Solution :

- low-res FX ;
- culling agressif ;
- budgets ;
- heatmap ;
- alpha erosion ;
- particle count clamp.

### 26.2 Trop de permutations shaders

Solution :

- modules compilés par familles ;
- function constants limitées ;
- material uber-shaders raisonnables ;
- pipeline cache ;
- précompilation.

### 26.3 Déterminisme GPU difficile

Solution :

- gameplay events CPU ;
- GPU seulement cosmétique ;
- seed stable ;
- snapshots tolérants ;
- pas de dépendance gameplay à l’ordre exact GPU.

### 26.4 Trop d’authoring

Solution :

- recettes paramétriques ;
- palettes par biome ;
- surface response tables ;
- templates ;
- inheritance ;
- randomization contrôlée.

### 26.5 Effets incohérents avec le monde

Solution :

- data interfaces obligatoires ;
- validation ;
- preview matrix ;
- règles biome/material/weather ;
- debug context.

---

## 27. Priorités pour IsoWorld

### Priorité 1

- système d’événements FX ;
- particles CPU simples ;
- sprites billboards ;
- footstep material response ;
- impacts ;
- decals ;
- seed stable.

### Priorité 2

- GPU particles ;
- soft particles ;
- flipbooks ;
- wind/weather ;
- terrain/material sampling ;
- mesh particles simples.

### Priorité 3

- ribbons/trails ;
- low-res soft FX ;
- lit particles ;
- distortion ;
- FX light proxies ;
- advanced decals.

### Priorité 4

- volumetric fog/smoke lite ;
- macro weather FX ;
- biome ambient FX ;
- FX Director.

### Priorité 5

- graph editor ;
- compiler ;
- procedural world styles ;
- anomalies RPG ;
- full debug/profiling suite.

---

## 28. Conclusion

Le système de particules/FX d’IsoWorld doit être pensé comme une **couche expressive du monde procédural**, pas comme une collection d’effets isolés.

La bonne architecture combine :

- un modèle type Niagara/Frostbite : systems, emitters, modules, data interfaces ;
- un backend GPU moderne avec Metal compute, argument buffers, indirect draws ;
- des renderers variés : sprites, meshes, ribbons, decals, volumes, distortion ;
- un pipeline hybride : runtime procedural + flipbooks/VDB baked pour les FX coûteux ;
- une réponse fine aux matériaux, météo, biomes, chaussures, terrain, props et règles RPG ;
- une forte gestion de LOD, culling, overdraw et budgets ;
- un déterminisme par seed au niveau événement/recette ;
- une énorme bibliothèque de types d’effets générables.

Pour IsoWorld, le point crucial est l’intégration : chaque pas, impact, feu, tempête, sort, machine, biome ou anomalie doit lire le monde et produire un effet cohérent avec la seed. C’est ce qui donnera au jeu un rendu vivant, systémique et haut de gamme sans dépendre d’un nombre infini d’assets manuels.

---

## 29. Sources principales

- Unreal Engine — Niagara Overview : https://dev.epicgames.com/documentation/unreal-engine/overview-of-niagara-effects-for-unreal-engine
- Unreal Engine — Niagara System and Emitter Module Reference : https://dev.epicgames.com/documentation/unreal-engine/system-and-emitter-module-reference-for-niagara-effects-in-unreal-engine
- Unreal Engine — Niagara Lightweight Emitters : https://dev.epicgames.com/documentation/unreal-engine/niagara-lightweight-emitters
- Unreal Engine — Niagara Collisions : https://dev.epicgames.com/documentation/unreal-engine/collisions-in-niagara-for-unreal-engine
- Unity — Visual Effect Graph : https://docs.unity3d.com/Packages/com.unity.visualeffectgraph%4012.0/
- Unity — Output Particle Mesh : https://docs.unity3d.com/Packages/com.unity.visualeffectgraph%4010.2/manual/Context-OutputParticleMesh.html
- Unity Blog — New possibilities with VFX Graph : https://unity.com/blog/engine-platform/new-possibilities-with-vfx-graph-in-2020-lts-and-beyond
- Frostbite — GPU Emitter Graph System : https://www.ea.com/news/frostbite-gpu-emitter-graph-system
- Frostbite — Physically-based & Unified Volumetric Rendering : https://www.ea.com/news/physically-based-unified-volumetric-rendering-in-frostbite
- Apple — Metal Sample Code : https://developer.apple.com/metal/sample-code/
- Apple — Transform your geometry with Metal mesh shaders : https://developer.apple.com/videos/play/wwdc2022/10162/
- NVIDIA GPU Gems 3 — High-Speed, Off-Screen Particles : https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-23-high-speed-screen-particles
- JangaFX — EmberGen : https://jangafx.com/software/embergen
- AMD / GDC Vault — Compute-Based GPU Particle Systems : https://gdcvault.com/play/1020622/Advanced-Visual-Effects-with-DirectX
- Game Developer — Shader and surface-driven GPU particle FX techniques : https://www.gamedeveloper.com/programming/video-shader-and-surface-driven-gpu-particle-fx-techniques
