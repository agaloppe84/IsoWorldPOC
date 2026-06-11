# Point 1 — Rendus procéduraux modernes : analyse, patterns industrie et recommandations IsoWorld

**Projet cible :** IsoWorldPOC — moteur procédural custom Swift/Metal sur macOS.  
**Date :** 2026-06-10  
**Fichier :** `procedural-modern-rendering.md`  
**Objectif :** document de référence pour concevoir un pipeline de rendu et de génération procédurale moderne, déterministe, scalable, orienté chunks, et compatible avec une trajectoire “moteur custom AAA-like” sur Apple Silicon / Metal.

---

## 0. Résumé exécutif

Pour IsoWorld, le bon cap n’est pas seulement de “générer des meshes aléatoires”. Le cap moderne est un **pipeline de monde procédural rendu comme un système de données** : une seed globale, des règles hiérarchiques, des contextes déterministes par chunk, des graphes de placement, une génération géométrique paramétrique, des matériaux PBR procéduraux, un streaming GPU, des LODs continus, du culling GPU, puis un renderer Metal qui consomme des snapshots propres sans piloter la simulation.

Le rendu procédural moderne en production AAA s’organise autour de quelques patterns récurrents :

1. **Le monde comme fonction pure partielle** : `World(seed, position, ruleset) -> data`, avec cache et invalidation, plutôt qu’un monde entièrement stocké.
2. **Génération multi-échelle** : macro monde, régions, biomes, chunks, cellules, props, détails shader.
3. **Graphes de règles authorables** : les artistes/tech artists manipulent des graphes de points, masques, contraintes, densités, matériaux, variants.
4. **Runtime GPU-driven** : culling, LOD, placement dense, commandes indirectes et, selon API/matériel, mesh shaders ou work graphs.
5. **Hybridation offline/runtime** : outils procéduraux offline pour authoring et baking, runtime déterministe pour variation et streaming.
6. **Matériaux procéduraux PBR** : albedo/normal/roughness/AO/height générés par graphes, masques, splats, atlases ou texture arrays.
7. **Virtualisation de données** : virtual geometry, virtual texturing, streaming de chunks, caches de ressources, hiérarchies LOD.
8. **Contrôle qualité systémique** : métriques, tests de déterminisme, validation de traversabilité, budgets CPU/GPU/mémoire.

Pour ton repo actuel, la direction est déjà saine : `EngineCore` découplé, snapshots de rendu, chunk streaming, matériaux abstraits, splat terrain, passes Metal légères. Le document propose de faire évoluer ça vers un **Procedural Render Substrate** : une couche intermédiaire qui transforme les sorties du WorldGenerator en buffers, textures, instances, matériaux et commandes de rendu, sans casser la séparation entre simulation/génération et renderer Metal.

---

## 1. Ce que signifie “rendu procédural moderne”

Le terme peut recouvrir plusieurs réalités. Pour IsoWorld, il faut les distinguer clairement.

### 1.1 Procédural de contenu

C’est la génération algorithmique de contenu : terrain, biomes, props, routes, grottes, villes, quêtes, règles du monde, météo, population. Le rendu n’est pas encore impliqué ; on produit des données abstraites.

Exemples de données :

```swift
struct GeneratedChunk {
    let coordinate: ChunkCoordinate
    let terrainSamples: TerrainSampleGrid
    let biomeFields: BiomeFieldSet
    let materialSplats: TerrainSplatField
    let propPlacements: [PropPlacement]
    let waterBodies: [WaterBodyPatch]
    let generationMetrics: ChunkGenerationMetrics
}
```

### 1.2 Procédural de géométrie

C’est la production algorithmique de vertices, indices, meshlets, implicit surfaces, billboards, impostors, hair/fur, branches, rochers, falaises, détails de terrain, etc.

Exemples :

- heightfield triangulé ;
- density field + marching cubes / dual contouring ;
- arbre généré par L-system ou croissance paramétrique ;
- rocher généré par superposition de primitives, noise et displacement ;
- herbe générée en mesh shader ou compute ;
- cliff mesh généré à partir des gradients de terrain.

### 1.3 Procédural de matériaux

C’est la génération ou la composition de textures et paramètres PBR : albedo, normal, roughness, metallic, AO, height, masks, wetness, snow, moss, dust, damage, variation par instance.

Substance Designer reste l’archétype industriel du workflow node-based : Adobe décrit Designer comme un logiciel d’authoring matériaux utilisant un node graph pour générer des textures depuis des patterns/noises procéduraux et manipuler des bitmaps.

### 1.4 Procédural de rendu

C’est le fait que le renderer lui-même fabrique ou sélectionne dynamiquement le travail GPU : commandes indirectes, culling GPU, LOD GPU, meshlet selection, streaming de textures/geometry, virtualisation.

Apple fournit notamment un sample “Modern Rendering with Metal” qui combine Indirect Command Buffers, Sparse Textures, Variable Rate Rasterization, GPU mesh culling, tile-based deferred lighting, ambient occlusion, volumetric fog et cascaded shadow maps. Apple fournit aussi un sample de terrain dynamique avec argument buffers, matériaux, végétation et particules dans un pipeline GPU-driven.

### 1.5 Procédural systémique

C’est le niveau le plus intéressant pour IsoWorld : les règles du monde, les époques, la présence ou non d’ennemis, les ressources, les objectifs, la physique, le gameplay et la narration changent selon la seed. Même si ce point sera traité plus tard, il influence déjà le rendu : un monde sans technologie ne doit pas produire de lampadaires modernes ; un monde futuriste doit produire d’autres matériaux, silhouettes, lumières et FX.

---

## 2. État de l’art industriel : les grands patterns

### 2.1 Pattern A — Le graphe de génération authorable

Le pattern dominant en production moderne est le **graphe de règles**. Unreal Engine PCG formalise ce modèle : son framework PCG permet de construire des outils de contenu procédural allant d’utilitaires d’assets, comme bâtiments ou biomes, jusqu’à des mondes entiers. Les graphes PCG manipulent des points 3D, densités, attributs, bounds, couleurs, pentes et seeds.

Pour IsoWorld, cela suggère de ne pas coder chaque système en dur. Il faut construire progressivement un format de **RuleGraph** ou **GenerationRecipe** :

```swift
struct GenerationRecipe: Codable, Hashable {
    let id: StableID
    let version: Int
    let seedPolicy: SeedPolicy
    let stages: [GenerationStage]
    let constraints: [GenerationConstraint]
    let outputs: [GenerationOutput]
}
```

Même sans éditeur visuel au début, le moteur peut utiliser un graphe textuel/JSON/Swift DSL. Plus tard, un éditeur SwiftUI peut manipuler ces graphes.

#### Recommandation IsoWorld

Créer une séparation stricte :

```text
WorldRules
  -> RegionRules
    -> BiomeRules
      -> TerrainRules
      -> PropRules
      -> MaterialRules
      -> FXRules
```

Chaque règle doit être :

- déterministe ;
- versionnée ;
- testable ;
- sérialisable ;
- capable de produire des métriques ;
- indépendante de Metal ;
- convertible en payload compact pour le renderer.

### 2.2 Pattern B — Données d’abord, rendu ensuite

Ton architecture actuelle suit déjà ce pattern : le renderer Metal consomme un `RenderWorldSnapshot` et ne décide pas quels chunks existent. C’est fondamental.

Le renderer doit rester un consommateur de données :

```text
WorldRuntime
  -> ChunkDataStreamer
  -> ProceduralChunkDataFactory
  -> RenderSnapshotBuilder
  -> RenderWorldSnapshot
  -> MetalRenderer
```

Le passage vers un rendu plus avancé doit ajouter une couche intermédiaire :

```text
RenderWorldSnapshot
  -> ProceduralRenderPreparation
      -> CPU staging
      -> GPU staging
      -> material tables
      -> instance tables
      -> visibility metadata
  -> MetalRenderGraph / passes
```

### 2.3 Pattern C — Runtime dense autour du joueur

Horizon Zero Dawn est un cas majeur : Guerrilla décrit un système de placement procédural GPU qui crée dynamiquement le monde autour du joueur, non limité aux arbres/rochers, mais incluant sons, effets, faune et éléments de gameplay. C’est très proche de ton objectif : monde généré dynamiquement autour du joueur avec chunks.

Le point clé est de ne pas stocker “un monde plein” mais des **règles et des champs** :

- champs de densité ;
- masques de biomes ;
- contraintes de pente/altitude/humidité ;
- champs de proximité des routes/rivières ;
- champs de visibilité ;
- zones d’exclusion gameplay ;
- graines stables par chunk et par feature.

### 2.4 Pattern D — Outils procéduraux hybrides offline/runtime

Houdini est le standard industriel pour générer des assets et mondes procéduraux. SideFX le présente comme un système conçu “from the ground up” pour des workflows procéduraux, avec itération rapide et partage de workflows, et met en avant terrain, océans, nuages, scattering de foliage/rocks pour le world building.

Pour IsoWorld, il ne faut pas forcément intégrer Houdini, mais il faut copier ses principes :

- graphes de nœuds ;
- paramètres exposés ;
- presets ;
- variations ;
- non-destruction ;
- cook/bake ;
- possibilité de régénérer ;
- séparation entre recette et résultat.

### 2.5 Pattern E — Génération multi-échelle

Un monde crédible ne sort pas d’une seule fonction de bruit. Il doit être composé par couches :

```text
Seed globale
  -> Univers / époque / règles globales
    -> Continents / grandes masses
      -> Régions climatiques
        -> Biomes globaux
          -> Sous-biomes
            -> Terrain local
              -> Props / végétation / ressources
                -> Micro-détails shader
```

Chaque niveau doit avoir sa propre fréquence spatiale, ses contraintes et son budget.

### 2.6 Pattern F — GPU-driven rendering

Les moteurs modernes déplacent de plus en plus le travail de visibilité, LOD et génération vers le GPU. Les raisons :

- réduire le coût CPU ;
- éviter des milliers de draw calls CPU ;
- culler plus finement ;
- générer des commandes indirectes ;
- traiter des millions d’instances ;
- produire des meshlets ou micro-meshes visibles uniquement.

Metal permet déjà plusieurs briques importantes : argument buffers, indirect command buffers, sparse textures, mesh shaders selon device family, compute kernels, tile shaders. Apple décrit Metal mesh shaders comme un pipeline flexible pour la création et le traitement de géométrie GPU-driven, capable de générer de la géométrie procédurale et d’améliorer le culling meshlet.

### 2.7 Pattern G — Virtualisation géométrique et texture

Nanite est la référence actuelle pour la virtualized geometry. Epic décrit Nanite comme un système de géométrie virtualisée avec format interne, rendu au détail pixel-scale, grand nombre d’objets, travail limité au détail visible, compression, streaming fin et LOD automatique.

IsoWorld n’a pas besoin de cloner Nanite immédiatement, mais doit s’inspirer de trois idées :

1. découper les meshes en clusters/meshlets ;
2. streamer les détails selon visibilité et distance ;
3. rendre le LOD automatique et invisible autant que possible.

Pour les textures, le pattern équivalent est virtual texturing / sparse textures : exposer un espace texture énorme mais ne résider en VRAM que les pages visibles ou probables.

### 2.8 Pattern H — Render graph

Les moteurs AAA évoluent vers un render graph/frame graph. Frostbite a popularisé ce pattern : le rendu est représenté comme un graphe de passes et ressources, ce qui permet des fonctionnalités découplées et modulaires tout en maintenant l’efficacité.

Un render graph n’est pas obligatoire tout de suite, mais IsoWorld doit préparer :

- passes déclaratives ;
- ressources nommées ;
- dépendances explicites ;
- lifetime des textures/buffers ;
- aliasing/transient resources ;
- debug capture ;
- possibilité de désactiver/activer des passes.

Ta base actuelle “passes légères sans RenderGraph complet” est bonne. Le risque serait de durcir trop tôt une API complexe. Il faut plutôt introduire un **mini render graph interne** quand les passes shadow, lighting, SSAO, volumetric fog, water, particles et post-processing arrivent.

---

## 3. Taxonomie des approches procédurales utiles pour IsoWorld

La littérature PCG classe les méthodes en familles : méthodes constructives, search-based, solver/constraint-based, grammaires, noise/fractales, machine learning, LLM et approches hybrides. Un survey récent catégorise notamment les méthodes PCG en search-based, learning-based, autres méthodes comme noise/generative grammars, LLM et méthodes combinées.

### 3.1 Méthodes constructives

Une méthode constructive génère directement un résultat en une passe ou plusieurs passes déterministes.

Exemples :

- heightmap par fBM ;
- placement d’arbres par Poisson disk ;
- route par A* ou spline descendante ;
- villages par grammaire ;
- rocher par primitives + bruit ;
- variation couleur par hash spatial.

Avantages : rapide, déterministe, simple à tester.  
Inconvénients : risque d’uniformité, difficile de garantir la qualité globale.

**IsoWorld :** c’est la base du runtime.

### 3.2 Méthodes generate-and-test

On génère plusieurs candidats, on mesure, on garde le meilleur.

Exemples :

- emplacement de lac respectant pente et bassin ;
- position de camp ennemi accessible ;
- grotte avec entrée visible ;
- biome transition satisfaisant plusieurs contraintes.

Avantages : qualité supérieure.  
Inconvénients : coût variable, attention au runtime.

**IsoWorld :** utiliser pour features rares, au niveau région/chunk, avec budget strict.

### 3.3 Search-based / évolutionnaire

On optimise une population de contenus avec une fitness function.

Exemples :

- layout de village ;
- réseau de routes ;
- donjon ;
- île avec objectifs ;
- distribution de ressources.

Avantages : diversité et adaptation à des objectifs.  
Inconvénients : coûteux, difficile à rendre déterministe sans discipline.

**IsoWorld :** plutôt offline ou à la génération régionale asynchrone, jamais dans le rendu frame-critical.

### 3.4 Constraint-based / solver

On exprime des contraintes, puis un solveur cherche une composition valide.

Exemples :

- pièces d’un bâtiment ;
- ville ;
- biome adjacency ;
- arbre technologique du monde ;
- règles RPG.

Avantages : contrôle fort.  
Inconvénients : complexité et debugging.

**IsoWorld :** excellent pour les règles globales et les props manufacturés.

### 3.5 Grammaires, L-systems, shape grammars

Utiles pour arbres, plantes, architectures, routes, grottes, décor manufacturé.

Exemple arbre :

```text
Trunk(depth, radius)
  -> Branch(depth-1, radius*0.65, angleA)
  -> Branch(depth-1, radius*0.55, angleB)
  -> Leaves(density, speciesProfile)
```

### 3.6 Noise, fractales, domain warping

C’est le socle terrain/matériaux, mais il ne suffit pas seul. Il faut combiner :

- value noise ;
- gradient noise ;
- simplex/open simplex ;
- fBM ;
- ridged noise ;
- cellular/Worley ;
- domain warping ;
- erosion approximée ;
- masks climatiques ;
- distance fields.

Usage :

```text
height = macroContinents
       + mountainMask * ridgedNoise
       + valleyMask * erosionApprox
       + localDetail * fBM
```

### 3.7 SDF / implicit surfaces / density fields

GPU Gems 3 montre une approche terrain basée sur une density function 3D dont la surface est l’isosurface `density = 0`, polygonisée par marching cubes sur des blocs de voxels. Cette famille permet grottes, arches, surplombs et formes organiques impossibles avec un simple heightfield.

Pour IsoWorld :

- heightfield pour terrain principal rapide ;
- density/SDF local pour grottes, arches, falaises, racines, gros rochers ;
- combinaison hybride : `heightfield + local implicit features`.

### 3.8 PCGML / génération assistée par IA

Les surveys PCGML décrivent la génération de contenu via modèles appris sur contenu existant. C’est prometteur pour style transfer, génération de matériaux, niveaux, quêtes, mais les problèmes récurrents sont le manque de données, la contrôlabilité, la validation et la robustesse.

**IsoWorld :** ne pas mettre de modèle ML dans la boucle runtime au départ. Utiliser plutôt l’IA comme outil offline pour :

- proposer des presets ;
- générer des graphes de règles ;
- classifier des biomes ;
- générer des textures sources ;
- explorer des paramètres.

Le runtime doit rester déterministe, léger et inspectable.

---

## 4. Études de cas industrielles et leçons pour IsoWorld

### 4.1 Unreal Engine PCG

Unreal PCG est important parce qu’il démocratise un pattern qui était souvent custom en studio : graphe de génération, points, densités, attributs, seed, temps réel, génération de bâtiments/biomes/mondes.

Leçons :

- le point procédural doit porter beaucoup d’attributs ;
- la densité est plus utile qu’un booléen spawn/no spawn ;
- les graphes permettent aux designers d’itérer ;
- les templates de graphes accélèrent la production ;
- la debug view est indispensable.

Implémentation IsoWorld :

```swift
struct ProcPoint: Hashable, Codable {
    var id: StableID
    var worldPosition: SIMD3<Float>
    var normal: SIMD3<Float>
    var tangent: SIMD3<Float>
    var density: Float
    var slope: Float
    var altitude: Float
    var moisture: Float
    var temperature: Float
    var biomeID: BiomeID
    var seed: UInt64
    var attributes: ProcAttributeSet
}
```

### 4.2 Houdini

Houdini montre que le procédural productif est avant tout un **workflow** : itération, graphes, paramètres, presets, partage, non-destruction.

Leçon : ne pas confondre “algorithme” et “outil”. Un bon moteur procédural doit exposer :

- des paramètres compréhensibles ;
- un mode debug ;
- des seeds locales ;
- des previews ;
- du bake ;
- des métriques ;
- une reproductibilité forte.

### 4.3 Substance Designer

Substance formalise le matériau procédural comme un graphe générant des canaux PBR. Pour IsoWorld, il faut adopter un modèle similaire même si les textures sont d’abord simples.

Recommandation : définir un `MaterialGraphDescriptor` moteur, puis le compiler vers :

- texture arrays ;
- petits LUTs ;
- paramètres constants ;
- variantes shader via function constants ;
- payload compact par vertex/instance.

### 4.4 Horizon Zero Dawn

Le système de Guerrilla est probablement le plus proche de ton besoin runtime : placement GPU dense autour du joueur, environnements complets, graph editor, règles artistiques, monde modifiable.

Leçon : le placement procédural ne doit pas seulement poser des meshes ; il doit produire un écosystème :

- géométrie ;
- sons ;
- FX ;
- gameplay ;
- animaux ;
- collisions ;
- zones d’intérêt ;
- règles de densité ;
- exclusion de chemins.

Pour IsoWorld, `PropPlacement` doit prévoir plus que `meshID` :

```swift
struct PropPlacement: Hashable, Codable {
    let id: StableID
    let archetype: PropArchetypeID
    let variant: UInt32
    let transform: Transform3D
    let biomeContext: BiomeContext
    let materialOverrides: MaterialOverrideSet
    let physicsProfile: PhysicsProfileID?
    let interactionProfile: InteractionProfileID?
    let audioProfile: AudioProfileID?
    let fxProfile: FXProfileID?
    let lodPolicy: LODPolicyID
}
```

### 4.5 Far Cry 5

Ubisoft a développé des outils pour remplir 100 km² de wilderness, générer biomes, texturer terrain, mettre en place réseaux d’eau douce, rochers de falaise, etc. Le talk terrain associé couvre un pipeline compute GPU pour LOD, culling, stitching et rendu du heightfield à toutes distances.

Leçons :

- la génération de monde doit inclure l’hydrographie et les falaises, pas seulement hauteur + arbres ;
- le terrain rendering doit être pensé dès le départ pour LOD/culling/stitching ;
- les outils doivent permettre la retouche locale ;
- la frontière art/procédural doit être flexible.

### 4.6 No Man’s Sky

No Man’s Sky est la référence “seed -> univers”. Les talks GDC décrivent la génération de terrains réalistes et alien par mathématiques, et l’architecture de génération continue temps réel de planètes.

Leçons :

- une seed seule ne suffit pas : il faut des lois globales ;
- la variété doit être contrôlée, pas bruitée ;
- le joueur doit découvrir des silhouettes mémorables ;
- tester un univers infini nécessite des outils statistiques ;
- la génération doit être random-access : on doit pouvoir générer un chunk sans générer tout ce qui l’entoure.

### 4.7 Infinigen

Infinigen est très pertinent pour ton point 4 futur, mais il donne déjà une direction pour le point 1. Le projet se définit comme un générateur procédural créant formes et matériaux depuis des règles mathématiques randomisées, du macro au micro détail, avec variations illimitées et contrôle par paramètres. Il couvre plantes, animaux, terrains, feu, nuages, pluie, neige et insiste sur la vraie géométrie plutôt que le fake par normal maps.

Leçons :

- chaque asset peut être une recette paramétrique ;
- les matériaux et la géométrie doivent partager des paramètres ;
- la génération doit produire des métadonnées ;
- un système procédural mature doit pouvoir générer des scènes entières cohérentes.

### 4.8 Nanite

Nanite est important pour le point 10, mais dès le point 1 il influence le design de rendu procédural. La leçon n’est pas “faire Nanite maintenant”, mais :

- penser en clusters ;
- penser en hiérarchie ;
- penser streaming ;
- penser détail visible à l’écran ;
- penser compression ;
- éviter les LODs manuels partout.

### 4.9 GPU Work Graphs

D3D12 Work Graphs montre la trajectoire de l’industrie : permettre au GPU de générer lui-même du travail dynamique. Microsoft cite explicitement la montée des techniques GPU-driven comme Nanite et explique que le CPU tend à se concentrer sur la gestion de ressources/hazards, tandis que les pipelines variables peuvent tourner plus efficacement sur le GPU avec scheduling et data flow gérés par le runtime.

Metal n’est pas D3D12. Pour IsoWorld, il faut donc traduire l’idée plutôt que copier l’API :

- aujourd’hui : compute passes + indirect command buffers + argument buffers + mesh shaders si supportés ;
- demain : si Metal expose plus d’autonomie GPU, adapter l’architecture ;
- toujours : garder les données procédurales compactes et GPU-consommables.

---

## 5. Architecture recommandée pour IsoWorld

### 5.1 Vue globale

```text
GlobalSeed
  ↓
WorldRuleset
  ↓
WorldCoordinateSystem
  ↓
RegionGenerator
  ↓
ChunkGenerator
  ↓
BiomeFieldGenerator
  ↓
TerrainGenerator
  ↓
PropPlacementGenerator
  ↓
MaterialFieldGenerator
  ↓
RenderSnapshotBuilder
  ↓
ProceduralRenderPreparation
  ↓
MetalRenderer
```

### 5.2 Les couches de données

#### Couche 1 — World Identity

Identité du monde :

```swift
struct WorldIdentity: Codable, Hashable {
    let globalSeed: UInt64
    let rulesetID: RulesetID
    let rulesetVersion: Int
    let epochProfile: EpochProfileID
    let physicsProfile: WorldPhysicsProfileID
    let biomePaletteID: BiomePaletteID
}
```

#### Couche 2 — Region Fields

Champs à grande échelle :

- continentalness ;
- erosion ;
- ridges ;
- temperature ;
- humidity ;
- ocean distance ;
- river potential ;
- geological age ;
- civilization pressure ;
- danger pressure ;
- magic/tech pressure si RPG.

Ces champs doivent être random-access et continus.

#### Couche 3 — Chunk Fields

Données locales prêtes pour rendu/simulation :

- height samples ;
- normals ;
- slope ;
- biome weights ;
- material splat weights ;
- water masks ;
- prop candidate fields ;
- collision representation ;
- nav hints.

#### Couche 4 — Renderable Resources

Données compilées pour GPU :

- vertex/index buffers ;
- instance buffers ;
- material tables ;
- texture layer indices ;
- bounding volumes ;
- LOD metadata ;
- indirect command metadata.

### 5.3 Pipeline chunk recommandé

```text
RequestedChunk(coord, lodBand)
  -> Determine generation seed
  -> Sample macro fields
  -> Generate terrain base
  -> Apply geological modifiers
  -> Resolve biome weights
  -> Generate material splats
  -> Generate prop candidates
  -> Filter by constraints
  -> Produce collision/nav simplified data
  -> Build render mesh or GPU generation payload
  -> Upload/stage resources
  -> Expose metrics
```

### 5.4 Déterminisme

Le déterminisme doit être contractuel.

Règles :

1. Ne jamais utiliser `Float.random` ou `SystemRandomNumberGenerator` pour le contenu persistant.
2. Utiliser un PRNG stable maison : PCG, SplitMix64, Xoroshiro, etc.
3. Dériver les seeds par hashing structuré :

```swift
chunkSeed = hash64(globalSeed, chunkX, chunkY, "terrain")
propSeed  = hash64(globalSeed, chunkX, chunkY, "props", biomeID)
```

4. Le résultat d’un chunk ne doit pas dépendre de l’ordre de génération.
5. Les features traversant les chunks doivent être ancrées à une échelle supérieure : région, rivière, route, faille géologique.

### 5.5 Gestion des frontières de chunks

Problème critique : seams géométriques, matériaux discontinus, props coupés, rivières cassées.

Solutions :

- sampler en coordonnées monde, pas locales ;
- ajouter une bordure de génération `ghost samples` ;
- générer les features longues au niveau région ;
- utiliser des IDs stables pour les features trans-chunks ;
- rendre les splat weights continus ;
- stocker un `ChunkEdgeSignature` pour tests.

```swift
struct ChunkEdgeSignature: Hashable {
    let northHeightsHash: UInt64
    let southHeightsHash: UInt64
    let eastHeightsHash: UInt64
    let westHeightsHash: UInt64
    let northMaterialHash: UInt64
    let southMaterialHash: UInt64
    let eastMaterialHash: UInt64
    let westMaterialHash: UInt64
}
```

---

## 6. Terrain procédural moderne : rendu et génération

### 6.1 Ne pas choisir un seul modèle terrain

IsoWorld doit supporter plusieurs représentations :

| Représentation | Avantages | Limites | Usage recommandé |
|---|---|---|---|
| Heightfield | rapide, simple, LOD facile | pas de caves/surplombs | terrain principal |
| Density field | caves, arches, volumes | plus coûteux | grottes/falaises locales |
| SDF | bool ops, rochers, formes propres | rendu/meshing complexe | props, grottes, détails |
| Mesh paramétrique | contrôle artistique | moins naturel seul | falaises, routes, structures |
| Decals/displacement | détail visuel peu cher | collision approximée | micro détails |

### 6.2 Heightfield moderne

Base :

```text
height = continentBase
       + mountainRidge * mountainMask
       + hills * hillMask
       + erosionValleys
       + localNoise
       + biomeSpecificModifier
```

Champs nécessaires :

```swift
struct TerrainSample {
    var height: Float
    var normal: SIMD3<Float>
    var slope: Float
    var curvature: Float
    var wetness: Float
    var sediment: Float
    var biomeWeights: BiomeWeights
    var materialSplat: TerrainMaterialSplat
}
```

### 6.3 Geometry clipmaps

Les geometry clipmaps restent une référence pour terrains massifs : nested grids centrés sur le viewer, transitions douces, taux de rendu stable, synthèse de détail runtime. GPU Gems 2 décrit une implémentation où presque tous les calculs terrain passent au GPU et où l’élévation est stockée en textures plutôt qu’en vertex buffers dynamiques.

Pour IsoWorld :

- court terme : chunks meshés côté CPU/Swift ou compute simple ;
- moyen terme : anneaux LOD autour caméra ;
- long terme : clipmap hybride pour terrain lointain + chunks détaillés proches.

### 6.4 GPU terrain generation

GPU Gems 3 montre la génération de terrain complexe entièrement GPU via density function + marching cubes par blocs. Même si l’implémentation historique utilise DirectX 10, l’idée reste moderne : le terrain volumétrique est naturellement parallèle.

Pour Metal :

- compute kernel pour échantillonner density/height ;
- compute kernel pour générer triangles ou meshlets ;
- buffer append/compaction ;
- indirect draw ;
- mesh shaders si la device family le permet ;
- fallback CPU pour debug et compatibilité.

### 6.5 Falaises et formes géologiques

Un moteur procédural ambitieux doit produire :

- plaines ;
- collines ;
- montagnes jeunes ;
- montagnes érodées ;
- falaises calcaires ;
- canyons ;
- mesas ;
- badlands ;
- dunes ;
- glaciers ;
- moraines ;
- fjords ;
- archipels ;
- volcans ;
- cratères ;
- grottes karstiques ;
- arches ;
- cheminées de fée ;
- rivières encaissées ;
- deltas ;
- marais ;
- mangroves ;
- banquise ;
- toundra ;
- plateaux ;
- ravins ;
- champs de lave ;
- structures cristallines alien.

Pour le rendu procédural, cela implique d’exposer des **géomorphons** : des modules géologiques composables.

```swift
enum Geomorphon: String, Codable {
    case plain, rollingHills, ridgeMountain, erodedMountain
    case canyon, mesa, duneField, glacier, volcano, crater
    case karstCave, cliffBand, riverDelta, swamp, lavaField
    case alienCrystalField, basaltColumns
}
```

### 6.6 Hydrographie

Les rivières sont difficiles car elles ne sont pas purement locales. Une rivière doit connaître bassin, pente et continuité.

Approche recommandée :

1. Générer un champ régional d’écoulement grossier.
2. Choisir des sources selon altitude/humidité.
3. Tracer des splines régionales downhill.
4. Rasteriser influence dans les chunks.
5. Modifier terrain local : incision, berges, sédiments.
6. Générer mesh eau + wetness + végétation riveraine.

### 6.7 Erosion

Érosion physique complète = coûteuse. Pour un runtime dynamique :

- précompute régional léger ;
- approximation par champs : flow accumulation, curvature, slope ;
- filtres de thermal erosion limités ;
- hydraulic erosion offline pour presets ;
- noise appris/paramétrique pour patterns.

---

## 7. Props procéduraux : rendu et représentation

Même si le point 4 sera dédié aux props, le rendu procédural moderne doit déjà prévoir leur modèle.

### 7.1 Trois familles de props

#### Props purement instanciés

Même mesh, variations de transform/material.

Exemples : herbe, cailloux, feuilles, petits débris.

#### Props paramétriques bake-once

Un générateur crée un mesh par variant, stocké/cache.

Exemples : rochers, arbres moyens, tables, lampadaires.

#### Props générés GPU

La géométrie est produite ou amplifiée côté GPU.

Exemples : herbe, cheveux, fourrure, branches fines, particules meshées, micro-débris.

### 7.2 Représentation recommandée

```swift
struct PropArchetype: Codable, Hashable {
    let id: PropArchetypeID
    let category: PropCategory
    let generator: PropGeneratorID
    let parameterSchema: ParameterSchema
    let materialSlots: [MaterialSlotDescriptor]
    let lodPolicy: LODPolicy
    let physicsPolicy: PhysicsPolicy
    let renderPolicy: RenderPolicy
}
```

### 7.3 Variation contrôlée

Un prop ne doit pas être “random”. Il doit être variant selon :

- biome ;
- humidité ;
- altitude ;
- âge ;
- exposition solaire ;
- proximité eau ;
- époque du monde ;
- état narratif ;
- style global de la seed.

```swift
struct PropGenerationContext {
    let worldSeed: UInt64
    let localSeed: UInt64
    let biome: BiomeID
    let subBiome: SubBiomeID
    let climate: ClimateSample
    let terrain: TerrainSample
    let ruleset: WorldRulesetID
}
```

### 7.4 Instancing massif

Pour le rendu :

- grouper par mesh/material/LOD ;
- stocker transform + variation dans instance buffer ;
- culling par chunk puis cluster ;
- utiliser indirect draws dès que beaucoup d’instances ;
- éviter un draw call par prop ;
- prévoir impostors/billboards pour distance.

### 7.5 Variants shader

Ne pas multiplier les meshes si une variation shader suffit :

- teinte ;
- roughness ;
- wetness ;
- snow amount ;
- moss amount ;
- wind phase ;
- damage mask ;
- age.

---

## 8. Matériaux et textures procédurales modernes

### 8.1 PBR comme contrat de base

Même pour un prototype stylisé, utiliser un contrat PBR :

```swift
struct RenderMaterial {
    var baseColor: SIMD4<Float>
    var roughness: Float
    var metallic: Float
    var ao: Float
    var normalScale: Float
    var heightScale: Float
    var textureSlots: PBRTextureSlots
    var proceduralParams: ProceduralMaterialParams
}
```

Unreal rappelle que le PBR vise à approximer le comportement réel de la lumière sur les surfaces, plutôt qu’un réglage purement intuitif. Cela donne des matériaux plus cohérents sous différentes lumières.

### 8.2 Texture arrays d’abord, virtual texturing ensuite

Court terme : texture arrays par canal :

- albedo array ;
- normal array ;
- roughness array ;
- metallic/AO array ;
- height array.

Moyen terme : atlas + bindless/argument buffers.

Long terme : sparse/virtual textures pour terrain/world énorme.

### 8.3 Splat terrain

Ton architecture a déjà un modèle de splat jusqu’à 4 couches. C’est une excellente base.

Prochaine évolution :

```swift
struct TerrainMaterialLayer {
    let materialID: MaterialID
    let weight: Float
    let uvScale: Float
    let macroVariation: Float
    let wetness: Float
    let snow: Float
    let slopeBlend: Float
}
```

### 8.4 Macro/micro variation

Pour éviter la répétition :

- macro color variation par biome/région ;
- noise world-space basse fréquence ;
- triplanar mapping pour falaises ;
- stochastic texture sampling ;
- random rotation/scale des UV ;
- decals procéduraux ;
- masks wetness/snow/moss.

### 8.5 Matériaux génératifs

Le modèle Substance/Infinigen suggère que chaque matériau doit être une recette :

```swift
struct ProceduralMaterialRecipe: Codable, Hashable {
    let id: MaterialRecipeID
    let graphID: MaterialGraphID
    let exposedParameters: [MaterialParameter]
    let outputChannels: Set<PBRChannel>
    let bakePolicy: MaterialBakePolicy
}
```

Au runtime, il ne faut pas forcément générer des textures complètes. On peut générer :

- paramètres ;
- petites LUT ;
- masks ;
- variation maps basse résolution ;
- textures de chunk à la demande.

---

## 9. Pipeline renderer moderne pour contenu procédural

### 9.1 Court terme : renforcer les passes existantes

Ton architecture actuelle : `MetalTerrainPass`, `MetalPropPass`, `MetalPlayerPass`, `MetalDebugPass`. À court terme, garder cette simplicité.

Ajouter :

- `MetalDepthPrepass` optionnelle ;
- `MetalShadowPass` ;
- `MetalLightingPass` ;
- `MetalWaterPass` ;
- `MetalParticlePass` ;
- `MetalPostProcessPass` ;
- `MetalDebugGBufferPass`.

### 9.2 Moyen terme : mini render graph

Quand les ressources deviennent nombreuses :

```swift
struct RenderGraphPassDescriptor {
    let name: String
    let reads: [RenderResourceID]
    let writes: [RenderResourceID]
    let execute: (RenderGraphContext) -> Void
}
```

Bénéfices :

- documentation du pipeline ;
- debug ;
- meilleure gestion mémoire ;
- activation/désactivation de features ;
- préparation aux effets AAA.

### 9.3 GPU-driven visibility

Pipeline recommandé :

```text
CPU:
  - construit liste chunks potentiellement visibles
  - upload metadata compacte
GPU compute:
  - frustum culling chunks
  - culling instances
  - LOD selection
  - build indirect commands
Render:
  - draw indirect par catégorie/material
```

### 9.4 Meshlets

Même sans Nanite, découper les meshes en meshlets donne :

- culling plus fin ;
- LOD plus flexible ;
- meilleure compatibilité mesh shaders ;
- base future pour virtualized geometry.

```swift
struct MeshletDescriptor {
    let vertexOffset: UInt32
    let vertexCount: UInt16
    let indexOffset: UInt32
    let indexCount: UInt16
    let bounds: BoundingSphere
    let coneCulling: NormalCone
    let lodError: Float
}
```

### 9.5 Indirect command buffers

Pour beaucoup de chunks/props :

- CPU prépare buffers de metadata ;
- GPU écrit/filtre commandes ;
- Metal exécute indirectement ;
- réduire overhead CPU.

Apple mentionne explicitement ICB dans ses samples modernes. C’est une cible importante pour IsoWorld.

### 9.6 Mesh shaders Metal

Apple décrit les mesh shaders comme une pipeline remplaçant le vertex stage par object/mesh stages, permettant de générer de la géométrie qui n’existe que dans le draw call sans buffer intermédiaire, et de faire du culling meshlet GPU-driven.

Usage potentiel IsoWorld :

- herbe procédurale ;
- petites plantes ;
- cheveux/fourrure ;
- branches fines ;
- micro-rochers ;
- terrain detail proche ;
- impostor expansion.

Règle : toujours prévoir fallback compute/vertex classique selon support device.

---

## 10. Système de LOD recommandé

### 10.1 LOD par type

| Type | LOD proche | LOD moyen | LOD loin |
|---|---|---|---|
| Terrain | mesh dense + splat | mesh réduit | clipmap/impostor height |
| Herbe | géométrie GPU | billboards | texture/detail map |
| Arbres | mesh complet | mesh simplifié | impostor/billboard |
| Rochers | mesh + displacement | mesh simplifié | cluster merged |
| Eau | simulation locale | plane shader | réflexion simplifiée |
| FX | particules lit | particules simples | off ou volumetric low |

### 10.2 LOD continu

Éviter popping :

- morph terrain ;
- dithered transition ;
- alpha fade ;
- cross-fade impostor ;
- stochastic LOD ;
- temporal stability.

### 10.3 Inspiré Nanite, version IsoWorld

Phase 1 : chunks + LOD statique.  
Phase 2 : meshlets + culling GPU.  
Phase 3 : cluster hierarchy par asset/terrain.  
Phase 4 : streaming de clusters.  
Phase 5 : virtual geometry custom pour certains assets.

Ne pas viser “trillions triangles” tôt. Viser :

- 60 FPS stable ;
- budgets mesurables ;
- culling robuste ;
- mémoire bornée ;
- transitions propres.

---

## 11. Biomes et rendu procédural

### 11.1 Biome comme distribution, pas enum simple

Un biome ne doit pas être un seul ID. Il faut des poids.

```swift
struct BiomeWeights: Codable, Hashable {
    var entries: [(BiomeID, Float)] // normalized, max 4 or 8
}
```

### 11.2 Champs déterminants

- altitude ;
- température ;
- humidité ;
- continentalité ;
- latitude fictive ;
- exposition ;
- pente ;
- sol ;
- proximité eau ;
- pression civilisation ;
- corruption/magie/technologie selon ruleset.

### 11.3 Transitions naturelles

Le rendu doit refléter les transitions :

- blend matériaux terrain ;
- espèces végétales mixtes ;
- props de transition ;
- wetness/snow progressifs ;
- brouillard/couleur ambiance ;
- sons et FX ;
- densité graduelle.

### 11.4 Sous-biomes

Exemple initial :

- Forêt tempérée
  - clairière
  - sous-bois humide
  - lisière
  - forêt dense
  - forêt rocheuse
- Montagne
  - pierrier
  - alpage
  - falaise
  - glacier
  - col venteux
- Désert
  - dunes
  - reg
  - canyon sec
  - oasis
  - plateau salin
- Toundra/banquise
  - neige profonde
  - glace bleue
  - roche gelée
  - marécage froid
- Marais
  - tourbière
  - mangrove
  - roselière
  - étang stagnant
- Littoral
  - plage
  - falaise marine
  - delta
  - récif
- Alien/fantastique
  - cristaux
  - champignons géants
  - biome bioluminescent
  - ruines organiques

---

## 12. Budget et performance sur MacBook Pro M1

### 12.1 Principes

- garder le CPU libre pour simulation/streaming ;
- batcher par chunk/material ;
- limiter allocations par frame ;
- préférer buffers persistants/ring buffers ;
- profiler dans Xcode GPU tools ;
- rendre les passes désactivables ;
- stocker des métriques visibles dans l’overlay.

### 12.2 Budgets initiaux conseillés

Ces budgets sont des points de départ, pas des vérités :

| Domaine | Budget cible initial |
|---|---:|
| Chunks visibles proches | 9 à 25 |
| Chunks terrain total draw | 25 à 81 selon LOD |
| Props visibles | 5k à 50k instances selon complexité |
| Draw calls CPU | < 500 court terme, < 100 moyen terme GPU-driven |
| Upload GPU/frame | minimal, éviter reupload chunks stables |
| Chunk generation | amortie, cache, jamais spike visible |
| Texture arrays | commencer petit, streamer plus tard |

### 12.3 Stratégie CPU/GPU

| Travail | CPU | GPU |
|---|---|---|
| Règles globales | oui | non |
| Macro biomes | oui/cache | possible sampling |
| Terrain heightfield | CPU au début | compute plus tard |
| SDF local | CPU debug | compute/mesh shader |
| Placement dense herbe | non | oui |
| Placement gameplay important | oui | non/ou hybride |
| Culling | CPU simple au début | GPU ensuite |
| LOD | CPU simple | GPU ensuite |
| Matériaux splat | CPU génération | GPU blending |

---

## 13. Debuggabilité et outils indispensables

Un moteur procédural sans debug est incontrôlable.

### 13.1 Overlay runtime

Afficher :

- seed globale ;
- chunk coordinate joueur ;
- chunks chargés/générés/dessinés ;
- temps génération chunk ;
- draw calls ;
- triangles ;
- instances ;
- buffer memory ;
- GPU frame time par passe ;
- cache hit/miss ;
- biome dominant ;
- material splat debug.

### 13.2 Vues debug monde

Modes :

- height ;
- slope ;
- normals ;
- biome primary ;
- biome secondary ;
- biome transition ;
- wetness ;
- temperature ;
- humidity ;
- erosion ;
- prop density ;
- culling bounds ;
- LOD rings ;
- nav/collision.

### 13.3 Tests automatiques

Tests indispensables :

```text
same seed + same coordinate => same chunk hash
neighbor chunk edges => equal border samples
prop placements => stable IDs
biome weights => normalized
no NaN in terrain/material data
LOD transitions => valid bounds
all generated meshes => valid indices
```

### 13.4 Golden seeds

Créer une suite de seeds de test :

- seed plaines ;
- seed montagnes ;
- seed eau dominante ;
- seed désert ;
- seed extrême ;
- seed densité props énorme ;
- seed transitions complexes ;
- seed régression bugs.

---

## 14. Plan d’implémentation recommandé pour le point 1

### Phase 1 — Stabiliser le contrat procédural/rendu

Objectif : rendre le monde plus riche sans complexifier Metal prématurément.

À créer :

- `WorldIdentity` ;
- `GenerationContext` ;
- `ProcPoint` ;
- `BiomeWeights` ;
- `TerrainSample` enrichi ;
- `PropArchetype` ;
- `PropPlacement` enrichi ;
- hash déterministe de chunk ;
- debug views.

### Phase 2 — Génération multi-couches terrain/biomes

- macro fields ;
- température/humidité/altitude ;
- sous-biomes ;
- splats matériaux continus ;
- transitions naturelles ;
- edge tests chunks.

### Phase 3 — Props procéduraux batchés

- archetypes ;
- placement par densité ;
- contraintes pente/eau/biome ;
- variations matériaux ;
- instance buffers ;
- culling CPU simple.

### Phase 4 — GPU-driven preparation

- instance metadata buffers ;
- bounding volumes ;
- indirect draw prototype ;
- culling compute ;
- LOD selection simple ;
- metrics GPU.

### Phase 5 — Terrain avancé

- LOD terrain ;
- stitching ;
- clipmap ou chunk LOD rings ;
- water meshes ;
- cliffs/rocks procéduraux ;
- density/SDF local.

### Phase 6 — Mini render graph

À introduire quand les passes deviennent :

- shadow ;
- G-buffer ou forward+ ;
- SSAO ;
- volumetric fog ;
- water ;
- particles ;
- post-processing.

---

## 15. Décisions d’architecture proposées

### Décision 1 — Le renderer ne génère pas le monde

Le renderer peut générer de la géométrie de rendu temporaire, mais il ne décide pas des règles monde.

Accepté :

- générer herbe GPU depuis un champ de densité ;
- générer meshlets depuis un payload ;
- culler/LOD.

Interdit :

- choisir biome dans shader sans source déterministe CPU ;
- décider gameplay en renderer ;
- créer props interactifs uniquement GPU sans ID stable.

### Décision 2 — Tout contenu persistant a un ID stable

Même si un arbre est généré dynamiquement, s’il peut brûler, tomber, être looté ou bloquer le joueur, il doit avoir un ID stable.

### Décision 3 — Les données de rendu sont compressées mais inspectables

Ne pas optimiser trop tôt au point de perdre la debugabilité.

### Décision 4 — Le moteur supporte plusieurs backends de génération

```swift
protocol TerrainGenerator {
    func generateChunk(context: ChunkGenerationContext) -> TerrainChunkData
}
```

Permettre :

- CPU deterministic ;
- GPU compute ;
- debug flat ;
- imported/baked ;
- test generator.

### Décision 5 — Le procédural est versionné

Un changement d’algorithme casse potentiellement les seeds. Il faut versionner :

- ruleset ;
- generators ;
- material recipes ;
- biome palettes ;
- prop archetypes.

---

## 16. Anti-patterns à éviter

### 16.1 “Une seed + du bruit = un monde”

Ça donne vite des paysages répétitifs et sans logique.

### 16.2 Génération dépendante de l’ordre

Si générer chunk A avant B change le résultat, le streaming devient instable.

### 16.3 Draw call par objet

Impossible pour une scène dense. Utiliser instancing/indirect.

### 16.4 Matériaux par biome en draw séparés

Préférer splat + texture arrays pour garder les chunks batchables.

### 16.5 Trop de simulation physique pour générer

Hydraulic erosion complète, growth simulation, fluid sim : utile offline ou local, pas partout en runtime.

### 16.6 Ne pas prévoir le debug

Chaque champ généré doit pouvoir être visualisé.

### 16.7 Tout faire côté GPU

Le GPU est puissant, mais gameplay, IDs stables, règles globales et validation restent souvent plus robustes côté CPU.

---

## 17. Proposition de structure de dossiers

```text
EngineCore/
  Generation/
    Seeds/
    Noise/
    Fields/
    Rules/
    Terrain/
    Biomes/
    Props/
    Materials/
    Validation/
  Rendering/
    Contracts/
    Materials/
    Meshes/
    LOD/
    Debug/
IsoWorldPOC/
  Rendering/Metal/
    Core/
    Passes/
    Resources/
    Pipelines/
    GPUDriven/
    Debug/
```

### 17.1 Nouveaux modules suggérés

```text
EngineCore/Generation/Fields
  ScalarField2D
  VectorField2D
  FieldSampler
  FieldCombiner
  DomainWarp

EngineCore/Generation/Rules
  WorldRuleset
  BiomeRule
  PropRule
  TerrainRule
  MaterialRule

EngineCore/Rendering/LOD
  LODPolicy
  MeshletDescriptor
  ChunkLODState

IsoWorldPOC/Rendering/Metal/GPUDriven
  MetalInstanceCullingPass
  MetalIndirectCommandBuilder
  MetalChunkVisibilityBuffer
```

---

## 18. Exemple de pipeline concret : chunk terrain + props

```text
Input:
  globalSeed = 1234
  chunk = (12, -4)
  lodBand = near

1. seed dérivée:
  terrainSeed = hash(1234, 12, -4, "terrain")

2. sample macro fields:
  altitudeBase, humidity, temperature, erosion, continentalness

3. biome weights:
  forest 0.55, rock 0.30, meadow 0.15

4. terrain mesh:
  33x33 grid + normals + slope

5. materials:
  grass, rock, dirt, wetValley avec weights par vertex

6. props candidates:
  400 points Poisson/blue-noise

7. filters:
  remove slope > 38° for trees
  rock on slope > 22°
  flowers if humidity > 0.5 and meadow > 0.3

8. outputs:
  terrain vertex/index buffer
  prop instance buffer
  material splat buffer
  debug metrics
```

---

## 19. Roadmap courte pour ton repo

### Étape immédiate 1

Ajouter un document `docs/PROCEDURAL_RENDERING.md` dans le repo à partir de ce fichier, puis créer des tickets :

- `GenerationContext` ;
- `WorldIdentity` ;
- tests déterminisme chunk ;
- `BiomeWeights` multi-biome ;
- debug fields.

### Étape immédiate 2

Renforcer `ProceduralChunkDataFactory` pour produire des couches séparées :

```text
TerrainGeometryLayer
TerrainMaterialLayer
BiomeDebugLayer
PropPlacementLayer
ChunkMetricsLayer
```

### Étape immédiate 3

Préparer l’instancing des props :

- un buffer instances par chunk ou par archetype ;
- regroupement par material/mesh ;
- IDs stables ;
- metrics.

### Étape immédiate 4

Ajouter un prototype de culling :

- CPU frustum par chunk ;
- CPU distance LOD ;
- bounds debug ;
- ensuite compute GPU.

### Étape immédiate 5

Créer les golden seeds :

```text
seed_plain
seed_mountain
seed_river
seed_desert
seed_dense_forest
seed_transition_biome
seed_extreme_height
```

---

## 20. Checklist de qualité

### Déterminisme

- [ ] Même seed + même coordonnée = même hash chunk.
- [ ] Les frontières de chunks matchent.
- [ ] Les props stables gardent le même ID.
- [ ] Les règles sont versionnées.

### Rendu

- [ ] Les chunks sont batchables.
- [ ] Les matériaux ne multiplient pas les draw calls inutilement.
- [ ] Les buffers GPU sont réutilisés.
- [ ] Les passes ont des métriques.
- [ ] Le debug peut isoler terrain/props/matériaux.

### Procédural

- [ ] Les champs macro sont visibles.
- [ ] Les biomes sont pondérés.
- [ ] Les transitions sont continues.
- [ ] Les props respectent pente/eau/biome.
- [ ] Les features longues sont ancrées hors chunk.

### Performance

- [ ] Pas d’allocation massive par frame.
- [ ] Pas de génération complète synchrone au moment visible.
- [ ] Streaming amorti.
- [ ] Culling avant draw.
- [ ] LOD mesuré.

---

## 21. Synthèse finale

Pour IsoWorld, le rendu procédural moderne doit être pensé comme une **chaîne complète de génération-rendu** :

```text
seed -> règles -> champs -> chunks -> placements -> matériaux -> ressources GPU -> rendu
```

La priorité n’est pas de tout mettre sur GPU immédiatement. La priorité est de créer des **contrats de données propres**, des IDs stables, des règles versionnées, des champs visualisables, puis de déplacer progressivement les parties massives vers Metal : instancing, culling, LOD, génération de détails, meshlets.

La meilleure trajectoire est :

1. renforcer le système déterministe et les données procédurales ;
2. améliorer terrain/biomes/material splats ;
3. rendre les props massivement instanciables ;
4. ajouter culling/LOD GPU-driven ;
5. introduire un mini render graph ;
6. s’inspirer de Nanite/Work Graphs pour les futures hiérarchies de clusters, sans tenter de les reproduire trop tôt.

Ce point 1 pose donc la base de tous les points suivants : Metal avancé, WorldGenerator radicalement seed-driven, props paramétriques, animation procédurale, terrain versatile, transitions biomes, textures/lumières, LOD Nanite-like, météo, FX et RPG systémique.

---

## 22. Sources principales consultées

1. **IsoWorldPOC — README et architecture**  
   https://github.com/agaloppe84/IsoWorldPOC  
   https://github.com/agaloppe84/IsoWorldPOC/blob/main/docs/ARCHITECTURE.md

2. **Apple Developer — Metal Sample Code / Modern Rendering with Metal**  
   https://developer.apple.com/metal/sample-code/

3. **Apple Developer — Transform your geometry with Metal mesh shaders, WWDC22**  
   https://developer.apple.com/videos/play/wwdc2022/10162/

4. **Unreal Engine Documentation — Procedural Content Generation Overview**  
   https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-overview

5. **Unreal Engine Documentation — Nanite Virtualized Geometry**  
   https://dev.epicgames.com/documentation/unreal-engine/nanite-virtualized-geometry-in-unreal-engine

6. **Guerrilla Games — GPU-Based Procedural Placement in Horizon Zero Dawn**  
   https://www.guerrilla-games.com/read/gpu-based-procedural-placement-in-horizon-zero-dawn

7. **GDC Vault — Procedural World Generation of Far Cry 5**  
   https://www.gdcvault.com/play/1025557/Procedural-World-Generation-of-Far

8. **GDC Vault — Terrain Rendering in Far Cry 5**  
   https://www.gdcvault.com/play/1025261/Terrain-Rendering-in-Far-Cry

9. **GDC Vault — Building Worlds Using Math(s), No Man’s Sky**  
   https://www.gdcvault.com/play/1024514/Building-Worlds-Using

10. **GDC Vault — Continuous World Generation in No Man’s Sky**  
    https://www.gdcvault.com/play/1024265/Continuous_World_Generation_in__No_Man_s_Sky_

11. **SideFX — Houdini procedural content creation tools**  
    https://www.sidefx.com/products/houdini/

12. **Adobe — Substance 3D Designer user guide**  
    https://experienceleague.adobe.com/en/docs/substance-3d-designer/using/home

13. **NVIDIA GPU Gems 3 — Generating Complex Procedural Terrains Using the GPU**  
    https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu

14. **NVIDIA GPU Gems 2 — Terrain Rendering Using GPU-Based Geometry Clipmaps**  
    https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-2-terrain-rendering-using-gpu-based-geometry

15. **Frostbite / GDC Vault — FrameGraph: Extensible Rendering Architecture in Frostbite**  
    https://www.gdcvault.com/play/1024612/FrameGraph-Extensible-Rendering-Architecture-in

16. **Microsoft DirectX Developer Blog — D3D12 Work Graphs**  
    https://devblogs.microsoft.com/directx/d3d12-work-graphs/

17. **GPUOpen — Work Graphs mesh nodes procedural generation**  
    https://gpuopen.com/learn/work_graphs_mesh_nodes/work_graphs_mesh_nodes-procedural_generation/

18. **Infinigen — Infinite Photorealistic Worlds using Procedural Generation**  
    https://infinigen.org/  
    https://arxiv.org/abs/2306.09310

19. **Procedural Content Generation in Games: A Survey with Insights on Emerging LLM Integration**  
    https://arxiv.org/html/2410.15644v1

20. **Procedural Content Generation via Machine Learning (PCGML)**  
    https://arxiv.org/abs/1702.00539

21. **Physically Based Shading at Disney**  
    https://media.disneyanimation.com/uploads/production/publication_asset/48/asset/s2012_pbs_disney_brdf_notes_v3.pdf

22. **Unreal Engine Documentation — Physically Based Materials**  
    https://dev.epicgames.com/documentation/unreal-engine/physically-based-materials-in-unreal-engine

23. **GPU Driven Rendering Overview**  
    https://www.vkguide.dev/docs/gpudriven/gpu_driven_engines/

24. **AMD Render Pipeline Shaders SDK / Render Graphs**  
    https://gpuopen.com/rps/
