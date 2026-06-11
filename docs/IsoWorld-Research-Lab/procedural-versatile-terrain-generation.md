# IsoWorld — Point 6 — Génération de terrain procédurale ultra versatile

> Sujet dédié uniquement au point 6 : génération de terrain déterministe, dynamique, très versatile, haute qualité, avec verticalité jouable.
>
> Cible projet : moteur custom Swift/Metal sur macOS, monde procédural par chunks autour du joueur, seed globale, rendu isométrique/orbital, architecture `EngineCore` découplée du renderer.
>
> Fichier : `procedural-versatile-terrain-generation.md`

---

## 0. Résumé exécutif

Pour IsoWorld, le terrain ne doit pas être pensé comme une simple heightmap bruitée. Une heightmap seule est rapide, simple, très compatible avec un streaming par chunks, mais elle est structurellement limitée : elle ne sait pas représenter proprement les surplombs, grottes, arches, falaises réellement verticales, tunnels, ponts naturels, plateformes encastrées ou structures attachées à une paroi. Pour obtenir un monde riche, vertical et jouable, il faut concevoir un **TerrainSystem hybride** :

1. **Heightfield principal** pour le sol majoritaire : plaines, collines, montagnes, vallées, dunes, plages, fonds marins, glaciers, plateaux, pentes, ravins modérés.
2. **Feature Graph géologique/hydrologique** pour les grandes structures : chaînes de montagnes, bassins versants, lits de rivières, lacs, canyons, failles, plateaux, crêtes, côtes, îles, mers, zones volcaniques.
3. **Patches volumétriques/SDF locaux** pour les structures non heightfield : grottes, arches, surplombs, falaises creusées, cavernes, tunnels, colonnes rocheuses, corniches, cavités dans les parois.
4. **Meshes procéduraux attachés** pour enrichir la verticalité : escaliers de falaise, passerelles, ponts suspendus, cordes, échelles, pitons, plateformes, ruines accrochées, racines, lianes, rebords de grimpe.
5. **Couches gameplay dérivées** : marchabilité, pente, rugosité, hauteur, escalade, glissade, danger, ancrage de corde, zones de saut, couverture, collision, navigation, spawn props, humidité, neige, boue.
6. **Rendu terrain moderne** : texture arrays, splat maps, triplanar sur parois, macro/micro variation, decals géologiques, wetness/snow masks, virtual/sparse textures à terme, LOD chunké, culling, stitching, collision simplifiée.

Le système doit être **déterministe par seed**, mais pas rigide : changer la seed doit modifier le monde radicalement, tout en gardant des règles cohérentes. Pour cela, chaque seed doit générer une **World Terrain Recipe** : un ensemble de lois géologiques, climatiques, hydrologiques, biomes, paramètres d’érosion, contraintes de verticalité et styles de matériaux. Le même point du monde doit toujours produire le même résultat, sans dépendre de l’ordre de chargement des chunks.

La recommandation centrale : construire un pipeline en **layers + graphes + contraintes** plutôt qu’une suite de noises indépendants. Les noises restent utiles, mais ils doivent être pilotés par des structures supérieures : tectonique, bassins, drainage, climat, altitude, exposition, érosion, gameplay.

---

## 1. Sources et patterns industriels retenus

### 1.1 Unreal Landscape : composants, LOD, collision, performance

Unreal Landscape divise le terrain en composants carrés utilisés comme unités de rendu, visibilité et collision. Les heightmaps sont stockées par composant, avec des contraintes de dimensions adaptées aux mipmaps et au LOD. Epic recommande de surveiller le coût CPU/draw calls lié au nombre de composants, et cite 1024 composants comme limite recommandée pour les très grands terrains. L’idée importante pour IsoWorld : **le chunk terrain doit être une unité de génération, streaming, collision, rendu et debug**, mais il faut limiter le nombre de draw calls et prévoir des tailles compatibles avec les LOD/mipmaps.

Source : https://dev.epicgames.com/documentation/unreal-engine/landscape-technical-guide-in-unreal-engine

### 1.2 Unreal PCG : points, densité, attributs, graphes procéduraux

Le framework PCG d’Unreal est intéressant parce qu’il formalise les mondes procéduraux sous forme de graphes : les points ont transform, bounds, densité, steepness, seed et attributs custom. Pour IsoWorld, le terrain lui-même doit produire des points/attributs : zones de falaise, bords de rivière, plages, crêtes, crevasses, trous de grotte, rebords de grimpe, emplacements de ponts, slots de props.

Source : https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-overview

### 1.3 Houdini HeightFields : layers, masks, erosion, limites des heightfields

Houdini HeightFields est un très bon modèle mental : plusieurs layers de hauteur et de masques peuvent être empilés, chaque opération peut être contrôlée par un masque, et les layers comme `flow`, `sediment`, `debris`, `flowdir` deviennent des sorties exploitables pour textures/props. Houdini documente aussi la limite structurelle des heightfields : une grille 2D ne représente pas correctement les zones verticales ; pour les détails verticaux, il faut convertir en géométrie, éroder, scatter des objets ou utiliser d’autres représentations.

Sources :
- https://www.sidefx.com/docs/houdini/heightfields/index.html
- https://www.sidefx.com/docs/houdini/heightfields/erosion.html

### 1.4 Hydrologie procédurale : rivières comme structure primaire

Les terrains réalistes ne sont pas seulement des bruits empilés. Les réseaux de drainage, bassins versants, rivières et lacs doivent influencer la forme du terrain. Le papier *Terrain Generation Using Procedural Models Based on Hydrology* propose de générer un réseau hiérarchique de drainage comme élément de modélisation, avec une représentation analytique/continue et une structure de construction. Pour IsoWorld, c’est une direction très importante : **placer les rivières avant de finaliser le terrain**, et pas seulement ajouter de l’eau après coup.

Source : https://www.cs.purdue.edu/cgvlab/www/resources/papers/Genevaux-ACM_Trans_Graph-2013-Terrain_Generation_Using_Procedural_Models_Based_on_Hydrology.pdf

### 1.5 Erosion fluviale contrôlable

La recherche récente sur l’érosion en terrain tile-based introduit des contraintes de hauteur, des niveaux de rainfall et la génération de gorges. C’est très pertinent pour IsoWorld : on doit pouvoir générer canyons, ravins, gorges, vallées et lits de rivières selon des paramètres lisibles par design, sans lancer une simulation lourde à chaque chunk runtime.

Source : https://arxiv.org/abs/2210.14496

### 1.6 GPU terrain et volumétrie

GPU Gems 3 décrit une génération de terrain complexe sur GPU à partir d’une fonction de densité 3D et de Marching Cubes. Le point clé : une fonction de densité 3D permet caves, surplombs et structures impossibles en heightfield. Pour IsoWorld, on ne doit pas forcément générer tout le monde en voxels, mais il faut utiliser une **couche volumétrique locale** pour les zones où la verticalité dépasse les capacités d’une heightmap.

Source : https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu

### 1.7 Outils production : World Machine, World Creator, Gaea

Les outils terrain modernes convergent vers plusieurs concepts : graphes de nodes, masques de pente/hauteur/flow, erosion multi-échelle, terrasses, rivières guidées, matériaux pilotés par masques, preview haute résolution. World Machine met en avant les rivières dessinées qui creusent des vallées, World Creator documente des distributions/masks basés sur height/slope/angle/flow, et Gaea permet des workflows de contrôle de l’érosion via masques et selective processing.

Sources :
- https://www.world-machine.com/
- https://docs.world-creator.com/reference/terrain/distributions
- https://docs.quadspinner.com/Guide/Using-Gaea/Erosion.html

### 1.8 Open worlds AAA : Far Cry 5 et Ghost Recon Wildlands

Les talks GDC Ubisoft sont utiles car ils décrivent des pipelines hybrides production : génération de biomes, texturing terrain, réseaux d’eau douce, cliff rocks, outils de réglage artistique, grands mondes multi-biomes. Le pattern à retenir : **les terrains AAA sont générés par outils procéduraux contrôlables, pas par une seule fonction random**. Les artistes/designers doivent pouvoir orienter la génération via recettes, masques, splines, tags, debug views et validations.

Sources :
- https://www.gdcvault.com/play/1025557/Procedural-World-Generation-of-Far
- https://www.gdcvault.com/play/1025261/Terrain-Rendering-in-Far-Cry
- https://gdcvault.com/play/1024708/-Ghost-Recon-Wildlands-Terrain

### 1.9 Metal moderne : mesh shaders, argument buffers, sparse textures

Metal mesh shaders apportent un pipeline géométrique plus flexible, avec object shader + mesh shader, utile pour la géométrie procédurale, le meshlet culling et certains chemins GPU-driven. Les argument buffers réduisent le coût CPU de binding de ressources, et les sparse textures/heaps ouvrent la voie à du streaming de textures terrain plus ambitieux. Pour IsoWorld M1, il faut feature-gater proprement selon les familles GPU supportées, et garder un fallback CPU/compute/vertex classique.

Sources :
- https://developer.apple.com/videos/play/wwdc2022/10162/
- https://developer.apple.com/documentation/metal/improving-cpu-performance-by-using-argument-buffers
- https://developer.apple.com/documentation/metal/creating-sparse-heaps-and-sparse-textures

### 1.10 Infinigen : variation mathématique complète

Infinigen démontre une approche totalement procédurale : formes, matériaux, scènes naturelles, phénomènes, variations illimitées via règles mathématiques randomisées. Pour IsoWorld, l’idée importante n’est pas de copier Blender/Infinigen runtime, mais de reprendre la philosophie : **chaque structure terrain doit avoir une recette paramétrique et des variations corrélées de forme, matériaux, props, climat et gameplay**.

Source : https://infinigen.org/

---

## 2. Objectifs spécifiques pour IsoWorld

### 2.1 Objectifs fonctionnels

Le système doit permettre de générer :

- plaines, collines, montagnes, falaises, canyons, gorges, rivières, lacs, mers, déserts, banquises, glaciers, côtes, îles, archipels, volcans, grottes, plateaux, badlands, mesas, marais, deltas, fjords, ravins, strates géologiques, formations alien/fantastiques ;
- des transitions cohérentes entre formes : une rivière doit pouvoir naître en montagne, traverser une vallée, élargir son lit, former un lac, créer un delta puis rejoindre la mer ;
- des structures verticales jouables : escalade à la corde, plateformes attachées, escaliers intégrés, ponts suspendus, chemins en corniche, grottes accessibles, falaises lisibles ;
- un rendu haute qualité avec variations macro/micro, matériaux PBR, parois rocheuses crédibles, neige, boue, sable, eau, glace, mousse, sédiments ;
- un runtime efficace sur MacBook Pro M1 : génération par chunks, caches, LOD, pas de simulation lourde synchrone pendant le frame.

### 2.2 Objectifs non fonctionnels

- **Déterminisme fort** : `seed + worldCoord + recipeVersion => même résultat`.
- **Stabilité locale** : charger un chunk avant/après un voisin ne change jamais les frontières.
- **Seams invisibles** : hauteur, normals, matériaux, flow maps et collisions doivent matcher aux frontières.
- **Debugabilité** : chaque couche terrain doit être visualisable : altitude, slope, biome, flow, erosion, climbability, material, nav, water.
- **Art direction** : malgré le procédural, on doit pouvoir forcer un style de monde : high fantasy, low tech, futuriste, désertique, glaciaire, tropical, vertical, hostile, paisible.
- **Évolutivité** : commencer en heightfield chunké, puis ajouter les patches volumétriques et les structures verticales sans réécrire tout le renderer.

---

## 3. Principe directeur : un terrain = des champs + des graphes + des contraintes

Un terrain moderne doit être représenté comme un ensemble de **champs spatiaux** et de **features nommées**, pas comme une seule hauteur.

### 3.1 Champs spatiaux principaux

Chaque position monde `(x, z)` doit pouvoir être échantillonnée pour obtenir :

```swift
struct TerrainSample {
    var worldXZ: SIMD2<Double>
    var height: Float
    var baseHeight: Float
    var finalHeight: Float

    var biomeID: BiomeID
    var subBiomeID: SubBiomeID
    var terrainArchetypeID: TerrainArchetypeID

    var slope: Float
    var aspect: Float
    var curvature: Float
    var ruggedness: Float
    var elevationBand: Float

    var moisture: Float
    var temperature: Float
    var rainfall: Float
    var windExposure: Float
    var solarExposure: Float

    var flowAccumulation: Float
    var flowDirection: SIMD2<Float>
    var riverDistance: Float
    var lakeDistance: Float
    var oceanDistance: Float
    var waterDepth: Float

    var erosion: Float
    var sediment: Float
    var debris: Float
    var talus: Float

    var materialWeights: TerrainMaterialWeights
    var wetness: Float
    var snow: Float
    var ice: Float
    var moss: Float
    var sand: Float
    var mud: Float

    var walkability: Float
    var climbability: Float
    var slideRisk: Float
    var fallDanger: Float
    var ropeAnchorScore: Float
    var ledgeScore: Float
    var stairAttachScore: Float

    var propSpawnMasks: PropSpawnMasks
}
```

Ce sample ne doit pas être nécessairement stocké partout. Une grande partie peut être calculée à la demande ou cuite par chunk dans des buffers compacts.

### 3.2 Feature Graph

Les grandes structures doivent être des objets déterministes avec ID, bounds et paramètres :

```swift
enum TerrainFeatureKind {
    case mountainRange
    case ridge
    case valley
    case river
    case stream
    case lake
    case ocean
    case canyon
    case cliffBand
    case mesa
    case crater
    case volcano
    case glacier
    case duneField
    case caveSystem
    case faultLine
    case roadCut
    case verticalTraversalRoute
}

struct TerrainFeature {
    let id: UInt64
    let kind: TerrainFeatureKind
    let seed: UInt64
    let bounds: WorldAABB
    let priority: Int
    let parameters: TerrainFeatureParameters
}
```

Un chunk ne doit pas inventer isolément ses rivières ou montagnes. Il doit interroger le **Feature Graph global/local** pour connaître les structures qui traversent sa zone. C’est la clé pour éviter les rivières coupées aux frontières, les falaises incohérentes, les lacs qui ne ferment pas, les routes verticales impossibles.

### 3.3 Contraintes

Chaque feature applique des contraintes :

- une rivière descend globalement vers une altitude plus basse ;
- un lac a une surface plane et des berges continues ;
- un canyon a un fond cohérent, des parois avec matériau rocheux, des talus et des accès rares ;
- une falaise escaladable doit avoir des zones suffisamment verticales, des points d’ancrage et une arrivée accessible ;
- une banquise dépend de température basse, eau, altitude/latitude/seed climatique ;
- un désert de dunes dépend d’aridité, vent, faible végétation, sable disponible ;
- une chaîne volcanique dépend d’une zone tectonique/failles et produit basaltes, cratères, cônes, coulées.

---

## 4. Architecture proposée : `TerrainSystem`

### 4.1 Vue générale

```text
WorldSeed
  ↓
WorldTerrainRecipe
  ↓
GlobalFieldSamplers
  ├─ climate field
  ├─ tectonic/geology field
  ├─ continental/ocean mask
  ├─ biome field
  └─ macro elevation field
  ↓
TerrainFeatureGraph
  ├─ mountain ranges
  ├─ drainage basins
  ├─ rivers/lakes/oceans
  ├─ canyon/fault/cliff bands
  ├─ caves/volumetric patches
  └─ vertical traversal candidates
  ↓
ChunkTerrainBuildRequest
  ↓
TerrainChunkPipeline
  ├─ sample base fields with border margin
  ├─ apply feature modifiers
  ├─ solve water/shore/river masks
  ├─ apply erosion approximations/cached layers
  ├─ generate surface materials
  ├─ derive gameplay layers
  ├─ emit mesh/collision/LOD/render payload
  └─ emit prop/structure spawn requests
  ↓
EngineCore contracts
  ↓
RenderSnapshotBuilder
  ↓
MetalTerrainPass / MetalPropPass / future render graph
```

### 4.2 Modules proposés dans `EngineCore`

```text
EngineCore/
  Terrain/
    TerrainSystem.swift
    TerrainRecipe.swift
    TerrainSeed.swift
    TerrainCoordinates.swift
    TerrainChunkPipeline.swift
    TerrainChunkData.swift
    TerrainSample.swift
    TerrainFields/
      ClimateField.swift
      GeologyField.swift
      ElevationField.swift
      HydrologyField.swift
      BiomeTerrainField.swift
      NoiseField.swift
      DistanceField.swift
    TerrainFeatures/
      TerrainFeatureGraph.swift
      RiverFeature.swift
      LakeFeature.swift
      MountainRangeFeature.swift
      CliffBandFeature.swift
      CanyonFeature.swift
      CaveSystemFeature.swift
      VerticalTraversalFeature.swift
    TerrainMaterials/
      TerrainMaterialCatalog.swift
      TerrainMaterialLayer.swift
      TerrainSplatWeights.swift
      TerrainSurfaceClassifier.swift
    TerrainGameplay/
      TerrainTraversalMap.swift
      ClimbSurfaceDetector.swift
      RopeAnchorGenerator.swift
      StairAttachmentGenerator.swift
      TerrainNavClassifier.swift
    TerrainValidation/
      TerrainValidator.swift
      SeamValidator.swift
      HydrologyValidator.swift
      TraversalValidator.swift
```

### 4.3 Contrats renderer neutres

`EngineCore` ne doit pas importer Metal. Il doit produire des contrats neutres :

```swift
struct RenderTerrainChunk {
    let chunkID: ChunkID
    let origin: SIMD3<Float>
    let lod: Int
    let vertexBufferPayload: TerrainVertexPayload
    let indexBufferPayload: TerrainIndexPayload
    let materialSplatPayload: TerrainSplatPayload
    let bounds: WorldAABB
    let debugLayers: TerrainDebugLayers
}
```

Le renderer Metal convertit ensuite ces payloads en buffers GPU, texture arrays, indirect commands ou mesh shader paths selon le hardware disponible.

---

## 5. Représentation hybride : heightfield + volumétrique + meshes attachés

### 5.1 Heightfield principal

Le heightfield reste la base pour 80–95 % du monde :

- extrêmement efficace ;
- facile à streamer par chunks ;
- facile à collider ;
- adapté aux LOD ;
- simple à texturer par splat maps ;
- parfait pour plaines, collines, montagnes, vallées, déserts, glaciers, plages.

Mais il doit être enrichi par des couches et ne doit pas porter tout le poids créatif.

### 5.2 Patches volumétriques/SDF locaux

Pour les éléments impossibles en heightfield, utiliser des patches locaux :

- grottes ;
- arches rocheuses ;
- ponts naturels ;
- tunnels ;
- surplombs ;
- falaises creusées ;
- colonnes suspendues ;
- cavités verticales ;
- réseaux karstiques ;
- mines naturelles ou anciennes ;
- cavernes glacées ;
- tubes de lave.

Ces patches peuvent être générés à partir d’une fonction de densité locale :

```text
density(p) = baseRock(p)
           - caveTunnels(p)
           - archCutouts(p)
           + stalagmiteFields(p)
           + debrisPiles(p)
```

Le rendu peut passer par un mesh pré-généré CPU en arrière-plan pour V1, puis éventuellement par compute/mesh shader plus tard.

### 5.3 Meshes procéduraux attachés au terrain

Les verticalités jouables sont souvent mieux traitées comme des **structures attachées** :

- escaliers taillés dans la roche ;
- marches en bois fixées à une falaise ;
- échelles ;
- cordes ;
- tyroliennes ;
- ponts suspendus ;
- passerelles ;
- plateformes ;
- ancrages métalliques ;
- rebords de grimpe ;
- racines/lianes utilisables ;
- ruines incrustées ;
- échafaudages ;
- routes de montagne ;
- corniches naturelles.

Ces structures doivent être générées après l’analyse de la pente/paroi, puis validées par un système de gameplay.

---

## 6. Pipeline détaillé de génération par chunk

### 6.1 Entrée

```swift
struct TerrainChunkBuildRequest {
    let seed: UInt64
    let recipe: WorldTerrainRecipe
    let chunkCoord: ChunkCoord
    let lod: Int
    let sampleResolution: Int
    let borderMarginSamples: Int
    let requiredLayers: TerrainLayerMask
}
```

Le `borderMarginSamples` est essentiel : pour calculer normals, slope, hydrology locale, matériaux et seams, un chunk doit échantillonner au-delà de sa limite visible.

### 6.2 Étape 1 — champs globaux bas coût

Calculer les champs larges :

- continentalité ;
- altitude macro ;
- tectonique ;
- humidité ;
- température ;
- vent dominant ;
- distance océan ;
- latitude fictive ;
- style géologique régional.

Ces champs changent lentement, peuvent être échantillonnés à faible résolution, puis interpolés.

### 6.3 Étape 2 — features intersectant le chunk

Interroger `TerrainFeatureGraph.query(bounds)` pour récupérer :

- rivières ;
- lacs ;
- bords de mer ;
- chaînes de montagnes ;
- crêtes ;
- failles ;
- canyons ;
- bandes de falaises ;
- grottes proches ;
- routes verticales candidates.

Chaque feature applique une fonction d’influence continue, jamais une coupure brutale.

### 6.4 Étape 3 — hauteur initiale

Composer :

```text
height = continentalBase
       + tectonicUplift
       + mountainRangeInfluence
       + ridgeNoise
       + biomeShapeNoise
       + localDetailNoise
```

Les noises doivent être **domain-warpés** et modulés par les champs géologiques, pas appliqués uniformément partout.

### 6.5 Étape 4 — hydrologie et eau

Appliquer :

- carving des rivières ;
- aplatissement des lacs ;
- création de berges ;
- zones humides ;
- profondeur d’eau ;
- lit mineur/lit majeur ;
- rapides/cascades si forte pente ;
- dépôts de sédiments ;
- deltas/fan alluviaux.

### 6.6 Étape 5 — érosion multi-échelle

Ne pas lancer une simulation lourde complète à chaque chunk. Utiliser un mix :

- érosion macro prévisible par fields ;
- érosion fluviale guidée par features ;
- thermal erosion approximée sur fortes pentes ;
- talus/debris selon pente et matériau ;
- masks de flow/sediment/debris ;
- cache de résultats pour chunks proches.

### 6.7 Étape 6 — verticalité

Détecter :

- surfaces > 45° : pentes raides ;
- surfaces > 65° : falaises ;
- surfaces > 80° : parois verticales ;
- ruptures de pente ;
- lignes de crête ;
- corniches ;
- zones de chute ;
- zones où un escalier/corde pourrait connecter deux niveaux.

Puis générer des **VerticalTraversalCandidates**.

### 6.8 Étape 7 — matériaux et rendu

Classer chaque sample :

```text
material = f(biome, slope, height, wetness, snow, flow, sediment, curvature, rockType)
```

Exemples :

- pente forte + rockType granite => roche nue ;
- bas de vallée + flow élevé => boue/galets/herbe humide ;
- altitude haute + température basse => neige/glace ;
- désert + vent + faible humidité => sable/dune ;
- falaise humide + ombre => mousse/lichen ;
- bord de mer + altitude basse => sable/galets/algues.

### 6.9 Étape 8 — collision et navigation

Produire :

- collider heightfield simplifié ;
- collision mesh pour patches volumétriques ;
- nav regions : walkable, climbable, swim, dangerous, blocked ;
- anchors de corde ;
- ledges ;
- stair slots ;
- water volumes ;
- caves entrances.

### 6.10 Étape 9 — payload rendu

Produire :

- vertex positions ;
- normals/tangents ;
- splat weights ;
- layer indices ;
- material UV scale ;
- debug attributes ;
- bounds ;
- LOD metadata ;
- skirts/stitching data.

---

## 7. Taxonomie longue de terrains générables

Cette liste sert à définir les futurs `TerrainArchetype`, `SubArchetype`, `FeatureKind` et `RecipeTags`.

### 7.1 Plaines et surfaces douces

- plaine herbeuse tempérée ;
- steppe sèche ;
- savane ouverte ;
- prairie alpine ;
- prairie humide ;
- plaine alluviale ;
- plaine inondable ;
- plaine côtière ;
- plaine glaciaire ;
- plaine volcanique ;
- plaine de cendres ;
- plaine de lave refroidie ;
- plateau herbeux ;
- plateau rocheux ;
- plateau désertique ;
- plateau karstique ;
- toundra plate ;
- lande venteuse ;
- pampas ;
- steppe froide ;
- plaine agricole naturelle potentielle ;
- bassin sédimentaire ;
- cuvette sèche ;
- playa désertique ;
- marais salant asséché ;
- champ de graviers ;
- plaine de loess ;
- plaine de sable compact ;
- plaine de mousse/lichen ;
- plaine alien cristallisée.

### 7.2 Collines et ondulations

- collines douces ;
- collines forestières ;
- collines calcaires ;
- collines karstiques ;
- collines sèches méditerranéennes ;
- collines de loess ;
- collines morainiques ;
- collines volcaniques ;
- collines de dunes fossiles ;
- collines de badlands ;
- collines terrassées naturelles ;
- collines érodées par ravines ;
- collines de prairie ;
- collines de bruyère ;
- collines gelées ;
- collines de sable ;
- collines de cendres ;
- collines striées par le vent ;
- collines fracturées ;
- collines couvertes de blocs erratiques ;
- collines avec affleurements rocheux ;
- collines de toundra ;
- collines de mousse humide ;
- collines cristallines fantastiques.

### 7.3 Montagnes

- montagnes jeunes très abruptes ;
- montagnes anciennes arrondies ;
- montagnes alpines ;
- montagnes enneigées ;
- montagnes volcaniques ;
- montagnes désertiques ;
- montagnes de granite ;
- montagnes de basalte ;
- montagnes calcaires ;
- montagnes stratifiées ;
- montagnes karstiques ;
- montagnes glaciaires ;
- aiguilles rocheuses ;
- pics isolés ;
- cirques glaciaires ;
- arêtes alpines ;
- cols ;
- vallées suspendues ;
- pierriers ;
- champs de blocs ;
- crêtes dentelées ;
- plateaux d’altitude ;
- corniches neigeuses ;
- faces nord glacées ;
- versants secs ;
- versants forestiers ;
- zones de séracs ;
- glaciers de vallée ;
- glaciers suspendus ;
- moraines ;
- névés ;
- montagnes alien à piliers ;
- montagnes flottantes attachées par ponts naturels ;
- montagnes creuses avec grottes internes.

### 7.4 Falaises et verticalité naturelle

- falaise côtière ;
- falaise de canyon ;
- falaise de montagne ;
- falaise calcaire ;
- falaise basaltique colonnaire ;
- falaise stratifiée horizontale ;
- falaise sédimentaire friable ;
- falaise granitique massive ;
- falaise de glace ;
- falaise de sable compacté ;
- escarpement de faille ;
- mur de mesa ;
- paroi de ravin ;
- paroi de gouffre ;
- face de carrière naturelle ;
- falaise avec corniches ;
- falaise avec terrasses ;
- falaise avec arches ;
- falaise avec grottes ;
- falaise avec cascades ;
- falaise humide moussue ;
- falaise sèche fissurée ;
- falaise érodée en colonnes ;
- falaise fracturée ;
- falaise avec éboulis au pied ;
- falaise escaladable ;
- falaise inaccessible ;
- falaise avec route en corniche ;
- falaise avec escaliers taillés ;
- falaise avec ponts suspendus ;
- falaise avec ruines accrochées.

### 7.5 Canyons, gorges, ravins

- canyon profond sec ;
- canyon fluvial actif ;
- canyon à méandres encaissés ;
- slot canyon étroit ;
- gorge humide ;
- gorge glaciaire ;
- ravin boisé ;
- ravin de badlands ;
- ravine éphémère désertique ;
- canyon de grès ;
- canyon calcaire ;
- canyon basaltique ;
- canyon en terrasses ;
- canyon avec arches ;
- canyon avec ponts naturels ;
- canyon avec cascades ;
- canyon inondé ;
- canyon souterrain partiel ;
- canyon labyrinthique ;
- canyon à parois verticales ;
- canyon à parois instables ;
- canyon de glace ;
- canyon volcanique ;
- canyon alien à cristaux.

### 7.6 Hydrologie : rivières, lacs, mers

- source de montagne ;
- ruisseau ;
- torrent ;
- rivière de vallée ;
- rivière à méandres ;
- rivière tressée ;
- rivière encaissée ;
- rivière souterraine ;
- rivière glaciaire ;
- rivière boueuse ;
- rivière saisonnière ;
- oued ;
- rapides ;
- cascade ;
- chute haute ;
- succession de petites cascades ;
- vasque naturelle ;
- lac de montagne ;
- lac glaciaire ;
- lac de cratère ;
- lac salé ;
- lac marécageux ;
- lac gelé ;
- lac souterrain ;
- étang ;
- mare temporaire ;
- lagune ;
- delta ;
- estuaire ;
- bras mort ;
- zone inondable ;
- marais ;
- tourbière ;
- mangrove ;
- mer intérieure ;
- océan ;
- plateau continental ;
- récif ;
- barrière de sable ;
- fjord ;
- baie ;
- crique ;
- archipel ;
- île volcanique ;
- île corallienne ;
- île rocheuse ;
- île gelée.

### 7.7 Déserts et aridité

- désert de dunes ;
- erg ;
- reg caillouteux ;
- hamada rocheuse ;
- désert salé ;
- playa ;
- badlands arides ;
- canyon désertique ;
- plateau désertique ;
- oasis ;
- oued sec ;
- champ de dunes longitudinales ;
- dunes en croissant ;
- dunes étoilées ;
- dunes paraboliques ;
- dunes fossiles ;
- yardangs ;
- roches champignons ;
- pavage désertique ;
- croûte saline ;
- bassin évaporitique ;
- désert froid ;
- désert volcanique ;
- désert noir basaltique ;
- désert rouge ferrugineux ;
- désert alien de verre/silice.

### 7.8 Glace, neige, banquise

- banquise marine ;
- plaques de glace fracturées ;
- iceberg échoué ;
- glacier de vallée ;
- glacier suspendu ;
- calotte glaciaire ;
- champ de neige ;
- névé ;
- séracs ;
- crevasses ;
- grotte de glace ;
- moraine ;
- lac gelé ;
- rivière sous-glaciaire ;
- toundra gelée ;
- pergélisol ;
- falaise de glace ;
- mur de glace côtier ;
- plaine de glace bleue ;
- banquise fracturée navigable ;
- zone de fonte saisonnière ;
- neige poudreuse ;
- neige durcie ;
- glace noire ;
- glace salée ;
- tempête de neige sculptant les dunes de neige.

### 7.9 Volcanisme et géothermie

- volcan conique ;
- volcan bouclier ;
- caldeira ;
- cratère ;
- lac de lave ;
- coulée de lave récente ;
- coulée refroidie ;
- champ de basalte ;
- orgues basaltiques ;
- tunnels de lave ;
- fumerolles ;
- geysers ;
- sources chaudes ;
- dépôts de soufre ;
- cendres volcaniques ;
- cône de scories ;
- dôme de lave ;
- faille géothermique ;
- sol craquelé chaud ;
- zone toxique ;
- île volcanique ;
- archipel volcanique ;
- montagne volcanique érodée.

### 7.10 Karst, grottes, souterrain

- plateau karstique ;
- doline ;
- gouffre ;
- aven ;
- grotte horizontale ;
- grotte verticale ;
- réseau de cavernes ;
- rivière souterraine ;
- lac souterrain ;
- stalactites ;
- stalagmites ;
- colonnes calcaires ;
- arche karstique ;
- pont naturel ;
- lapiaz ;
- résurgence ;
- siphon ;
- cavité effondrée ;
- entrée de grotte en falaise ;
- grotte marine ;
- grotte de lave ;
- grotte de glace ;
- mine naturelle fantastique ;
- caverne cristalline.

### 7.11 Côtes et interfaces terre/eau

- plage de sable ;
- plage de galets ;
- plage noire volcanique ;
- falaise côtière ;
- dune côtière ;
- lagune ;
- marais côtier ;
- mangrove ;
- récif ;
- côte rocheuse ;
- crique ;
- baie ;
- cap ;
- péninsule ;
- île-barrière ;
- tombolo ;
- estuaire ;
- delta ;
- fjord ;
- côte glaciaire ;
- côte volcanique ;
- côte fracturée ;
- archipel ;
- grotte marine ;
- arche marine ;
- stack rocheux ;
- estran ;
- marée basse/haute simulée par masks.

### 7.12 Structures géologiques particulières

- faille linéaire ;
- escarpement ;
- pli géologique ;
- strates inclinées ;
- strates horizontales ;
- anticlinaux/synclinaux stylisés ;
- dykes ;
- filons ;
- veines minérales ;
- affleurements ;
- cheminées de fée ;
- hoodoos ;
- arches naturelles ;
- ponts naturels ;
- mesas ;
- buttes ;
- tepuis ;
- tors granitiques ;
- chaos rocheux ;
- champs de blocs ;
- orgues basaltiques ;
- roches plissées ;
- impact crater ;
- cratère érodé ;
- bassin circulaire ;
- anneau montagneux ;
- structure cristalline ;
- terrain fractal alien ;
- terrain à gravité ancienne/fantastique ;
- îlots flottants ancrés ;
- racines géantes minéralisées.

### 7.13 Terrains anthropisés ou semi-naturels

Même si le point 6 est terrain, le terrain peut préparer des emplacements pour structures :

- route de montagne ;
- sentier ;
- chemin en corniche ;
- escaliers taillés ;
- terrasses agricoles ;
- carrière abandonnée ;
- mine ouverte ;
- digue ;
- barrage naturel/ancien ;
- pont de pierre ;
- tunnel ;
- tranchée ;
- remblai ;
- ruines intégrées à la falaise ;
- village en terrasse ;
- plateformes sur pilotis ;
- murs de soutènement ;
- forteresse de falaise ;
- aqueduc ;
- canal ;
- route submergée ;
- chemin de pèlerinage ;
- ascenseur minier ;
- passerelles suspendues ;
- tyroliennes ;
- cordes fixes ;
- ponts de singe.

---

## 8. Variantes : comment éviter la répétition

### 8.1 Variation hiérarchique

Chaque terrain doit varier à plusieurs niveaux :

```text
World seed
  → planète/région : climat, géologie, niveau d'eau, style global
  → macro-zone : continent, océan, chaîne, bassin, désert, banquise
  → biome : température, humidité, végétation, matériaux
  → terrain archetype : canyon, plaine, montagne, falaise, delta...
  → feature : rivière A, lac B, falaise C
  → chunk : détails locaux, debris, micro relief
  → sample : matériau, wetness, cailloux, fissures, normals
```

Un changement de seed doit modifier les paramètres haut niveau et donc produire des mondes radicalement différents. Mais un changement local ne doit pas casser les règles globales.

### 8.2 Paramètres de recette

Exemple de recette :

```swift
struct WorldTerrainRecipe {
    let seed: UInt64
    let recipeVersion: Int

    let seaLevel: Float
    let averageElevation: Float
    let verticalityBias: Float
    let erosionIntensity: Float
    let hydrologyDensity: Float
    let tectonicActivity: Float
    let volcanicActivity: Float
    let glaciation: Float
    let aridity: Float
    let caveDensity: Float
    let cliffFrequency: Float
    let traversalDensity: Float

    let geologyPalette: GeologyPalette
    let materialPalette: TerrainMaterialPalette
    let biomeRules: BiomeTerrainRules
    let terrainArchetypeWeights: WeightedTable<TerrainArchetypeID>
}
```

### 8.3 Corrélation des variantes

Il ne faut pas tirer tous les paramètres indépendamment. Exemples :

- forte tectonique → montagnes plus hautes, failles plus fréquentes, falaises plus nombreuses ;
- forte glaciation → vallées en U, moraines, lacs glaciaires, neige persistante ;
- forte aridité → rivières rares, oueds, canyons secs, dunes, croûtes salines ;
- volcanisme élevé → basalte, cratères, tunnels de lave, sols noirs ;
- humidité élevée + calcaire → karst, grottes, mousses, cascades ;
- monde vertical → routes de grimpe, ponts, paliers, corniches, chute danger plus forte.

### 8.4 Seeds par feature

Chaque feature doit avoir une seed dérivée stable :

```swift
let featureSeed = hash64(worldSeed, featureKind.rawValue, featureGridCoord.x, featureGridCoord.y, recipeVersion)
```

Ne jamais utiliser un RNG global consommé dans un ordre variable. Cela garantit que le résultat ne dépend pas du streaming.

---

## 9. Règles de génération par terrain archetype

### 9.1 Plaine

Inputs : faible relief macro, faible slope, climat, proximité eau.

Règles :

- noise basse fréquence très doux ;
- micro undulations ;
- matériaux selon biome ;
- rares ruptures de pente ;
- forte walkability ;
- prop spawn élevé ;
- routes faciles ;
- eau stagnante possible si flow faible et humidité haute.

### 9.2 Montagne

Inputs : uplift tectonique, altitude, rugosité.

Règles :

- ridged noise + chaînes orientées ;
- lignes de crête continues ;
- vallée sculptée par hydrologie/glace ;
- slope et curvature fortes ;
- roche nue sur pente ;
- snow/ice selon température ;
- pierriers sous falaises ;
- rare walkability directe ;
- génération de cols et routes verticales candidates.

### 9.3 Falaise

Inputs : rupture de pente, faille, canyon, côte, montagne.

Règles :

- gradient fort local ;
- matériau rocheux forcé ;
- triplanar obligatoire ;
- decals de fissures/strates ;
- debris au pied ;
- ledges probabilistes ;
- climbability selon rockType et gameplay ;
- anchors pour corde si haut/bas accessibles ;
- possible structure attachée.

### 9.4 Canyon

Inputs : rivière ou ancien lit, aridité/érosion, roche stratifiée.

Règles :

- carving profond suivant spline/graph ;
- fond relativement continu ;
- parois raides ;
- terrasses latérales ;
- méandres encaissés ;
- matériaux stratifiés ;
- zones d’ombre/humidité ;
- routes de sortie rares ;
- ponts naturels possibles ;
- risque chute élevé.

### 9.5 Rivière

Inputs : drainage graph, rainfall, source, altitude.

Règles :

- monotonicité approximative descendante ;
- largeur augmente avec flow accumulation ;
- profondeur augmente selon débit ;
- méandres si pente faible ;
- rapides/cascades si pente forte ;
- berges humides ;
- galets/sédiments ;
- végétation riveraine ;
- collision water volume ;
- navigation swim/wade selon profondeur.

### 9.6 Lac

Inputs : bassin fermé, barrage naturel, cratère, glacier, plaine.

Règles :

- surface plane ;
- shoreline continue ;
- profondeur selon cuvette ;
- plages/galets/marais selon slope ;
- exutoire si niveau dépasse seuil ;
- lac gelé si température basse ;
- îlots possibles ;
- props aquatiques.

### 9.7 Désert de dunes

Inputs : aridité, sable, vent.

Règles :

- dunes orientées par vent dominant ;
- matériaux sable ;
- micro ripples ;
- faible végétation ;
- roches exposées ;
- oasis rares ;
- tempêtes/visibilité possible ;
- walkability variable ;
- glissade sur fortes dunes.

### 9.8 Banquise/glacier

Inputs : température, latitude fictive, eau/altitude.

Règles :

- surfaces glace/neige ;
- crevasses selon tension/slope ;
- water/ice masks ;
- glissade élevée ;
- collision spécifique ;
- grottes de glace ;
- séracs ;
- fractures de banquise ;
- matériaux translucides/frost.

### 9.9 Karst/grottes

Inputs : calcaire, humidité, drainage.

Règles :

- dolines ;
- gouffres ;
- grottes SDF ;
- résurgences ;
- rivières souterraines ;
- entrées en falaise ;
- nav souterrain ;
- stalactites/stalagmites ;
- humidité/mousse.

---

## 10. Gestion de la verticalité jouable

### 10.1 Problème

Le user story explicite : on doit pouvoir grimper sur une falaise avec une corde, ou attacher une structure type escalier à une structure verticale. Cela implique que le terrain ne doit pas seulement être beau : il doit produire des **affordances gameplay**.

### 10.2 Classification des surfaces

Chaque chunk doit dériver une carte :

```swift
struct VerticalSurfaceSample {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let height: Float
    let slopeDegrees: Float
    let rockStability: Float
    let ledgeScore: Float
    let climbGrip: Float
    let fallHeight: Float
    let topAccessScore: Float
    let bottomAccessScore: Float
    let attachableScore: Float
}
```

### 10.3 Routes verticales

Une route verticale est une connexion entre deux zones jouables :

```swift
struct VerticalTraversalRoute {
    let id: UInt64
    let kind: VerticalTraversalKind
    let start: SIMD3<Float>
    let end: SIMD3<Float>
    let path: [SIMD3<Float>]
    let difficulty: Float
    let requiredTool: TraversalTool?
    let generatedStructure: GeneratedStructureID?
}

enum VerticalTraversalKind {
    case naturalLedges
    case rope
    case ladder
    case carvedStairs
    case woodenStairs
    case switchbackPath
    case climbingWall
    case zipline
    case elevatorLikeStructure
    case rootOrVine
}
```

### 10.4 Génération d’une corde

Conditions :

- falaise assez verticale ;
- point haut accessible ;
- point bas accessible ;
- distance verticale utile ;
- pas d’obstacle majeur ;
- matériau stable ou structure d’ancrage ;
- cohérent avec époque/règles RPG du monde.

Pipeline :

1. détecter une paroi candidate ;
2. trouver haut/bas via flood fill nav local ;
3. lancer une courbe verticale/spline ;
4. valider collision ;
5. générer anchors ;
6. générer rope mesh/physics proxy ;
7. ajouter interaction gameplay ;
8. ajouter debug route.

### 10.5 Génération d’un escalier attaché

Types :

- escalier taillé dans la roche ;
- escalier en bois accroché ;
- escalier métallique ;
- escalier ruiné ;
- lacets naturels ;
- sentier en corniche ;
- marches irrégulières ;
- échelle/plateforme mixte.

Contraintes :

- pente trop forte pour marche naturelle ;
- assez d’espace latéral ;
- points de repos ;
- pas de clipping dans la falaise ;
- supports visuels ;
- collision simplifiée ;
- LOD/impostor à distance.

### 10.6 Corniches et rebords

Les rebords naturels peuvent être générés par :

- strates rocheuses horizontales ;
- bruit de fracture ;
- terraces ;
- erosion différentielle ;
- ajout de mesh strips sur paroi ;
- decals géométriques.

Ils doivent être classés en :

- décoratifs ;
- utilisables pour grimpe ;
- dangereux/glissants ;
- bloqués.

### 10.7 Debug views nécessaires

- `debugSlope` ;
- `debugClimbability` ;
- `debugRopeAnchors` ;
- `debugLedges` ;
- `debugVerticalRoutes` ;
- `debugAttachableSurfaces` ;
- `debugFallDanger` ;
- `debugNavTopBottomAccess`.

---

## 11. Hydrologie robuste

### 11.1 Générer l’eau comme structure, pas comme texture

Un bon terrain a besoin d’un système hydrologique :

```text
rainfall field
  ↓
watershed basins
  ↓
stream graph
  ↓
river/lake/ocean features
  ↓
terrain carving + materials + gameplay + props
```

### 11.2 Données rivière

```swift
struct RiverFeature {
    let id: UInt64
    let seed: UInt64
    let polyline: [SIMD2<Double>]
    let sourceElevation: Float
    let mouthElevation: Float
    let flow: Float
    let widthRange: ClosedRange<Float>
    let depthRange: ClosedRange<Float>
    let riverType: RiverType
}

enum RiverType {
    case mountainTorrent
    case meanderingLowland
    case braided
    case canyonRiver
    case seasonalWadi
    case glacial
    case underground
    case deltaic
}
```

### 11.3 Carving

La rivière modifie le terrain autour de son axe :

```text
valleyProfile(d) = bedDepth * smoothMin(channel(d), floodplain(d), valley(d))
```

Sorties :

- water mask ;
- riverbed mask ;
- bank mask ;
- wetness ;
- sediment ;
- pebbles ;
- vegetation corridor ;
- crossing candidates.

### 11.4 Cascades

Conditions :

- rivière traverse une rupture de pente ;
- falaise/canyon/plateau ;
- différence d’altitude significative ;
- bassin au pied ;
- spray/mist/foam ;
- bruit sonore futur ;
- route de grimpe possible à côté.

### 11.5 Lacs

Un lac est défini par :

- surface plane ;
- niveau d’eau ;
- contour ;
- profondeur ;
- entrée/sortie ;
- shoreline material ;
- ice state ;
- wave state.

Ne jamais laisser un lac suivre la heightmap. L’eau doit être plane localement.

---

## 12. Érosion : approche réaliste mais pas trop lourde

### 12.1 Types d’érosion à simuler ou approximer

- érosion hydraulique ;
- érosion thermique ;
- érosion glaciaire ;
- érosion éolienne ;
- érosion côtière ;
- effondrement/talus ;
- dissolution karstique ;
- sédimentation ;
- weathering/fissuration.

### 12.2 Stratégie runtime

Ne pas faire de simulation longue synchrone. Utiliser :

- érosion analytique par feature ;
- erosion masks prévisibles ;
- kernels courts async ;
- cache disque/mémoire par chunk ;
- plusieurs niveaux de qualité ;
- approximation pour LOD loin.

### 12.3 Layers inspirés Houdini

Chaque chunk peut produire :

```text
height
baseHeight
bedrock
soilDepth
flow
flowDir
sediment
debris
talus
wetness
snow
ice
rockExposure
strata
```

Ces layers alimentent les matériaux, props, gameplay et FX.

---

## 13. Matériaux terrain haute qualité

### 13.1 Approche PBR par texture arrays

Le terrain doit évoluer vers :

- `albedoArray` ;
- `normalArray` ;
- `roughnessArray` ;
- `metallicAOArray` ;
- `height/displacementArray` ;
- `macroVariationArray`.

Chaque vertex/sample porte jusqu’à 4–8 couches de splat :

```swift
struct TerrainMaterialSplat {
    var layerIDs: SIMD4<UInt16>
    var weights: SIMD4<Float>
    var uvScales: SIMD4<Float>
    var macroBlend: Float
}
```

### 13.2 Triplanar sur pentes fortes

Sur les falaises, les UV heightfield s’étirent. Règle :

```text
if slope > cliffThreshold:
    use triplanar rock shader
else:
    use terrain UV/splat shader
```

### 13.3 Variation macro/micro

Pour éviter la répétition :

- macro color noise très basse fréquence ;
- hue shift par région ;
- roughness variation ;
- normal detail selon slope ;
- decals de fissures ;
- wetness dynamic ;
- snow accumulation selon normal/altitude/température ;
- moss selon humidité/ombre ;
- sand drift selon vent.

### 13.4 Matériaux par géologie

Palette initiale :

- herbe courte ;
- herbe humide ;
- mousse ;
- terre ;
- boue ;
- sable fin ;
- sable humide ;
- galets ;
- gravier ;
- roche granite ;
- roche calcaire ;
- roche basaltique ;
- roche stratifiée ;
- argile rouge ;
- sel ;
- neige ;
- glace ;
- cendre ;
- lave refroidie ;
- soufre ;
- vase ;
- corail/récif ;
- algues littorales ;
- cristal/fantastique.

---

## 14. LOD, streaming et performance

### 14.1 Niveaux de données

```text
LOD0 proche : mesh dense, splat détaillé, collision précise, gameplay layers complets
LOD1 moyen  : mesh réduit, matériaux complets, collision simplifiée
LOD2 loin   : mesh clipmap/quadtree, matériaux baked/macro
LOD3 horizon: impostor height/normal/color, pas de collision
```

### 14.2 Chunk borders

Pour éviter les seams :

- sampling en coordonnées monde ;
- bordure de samples partagée ;
- normals calculées avec margin ;
- quantification identique ;
- feature graph global ;
- stitching skirts ou morph LOD ;
- validation automatisée.

### 14.3 Pipeline async

```text
Frame N:
  - déterminer chunks nécessaires
  - scheduler génération manquante
  - dessiner cache disponible

Worker queue:
  - fields low res
  - terrain mesh
  - materials
  - collision
  - gameplay layers
  - GPU upload staging

Renderer:
  - culling
  - LOD selection
  - draw terrain
  - draw attached structures
```

### 14.4 M1 pragmatique

Pour MacBook Pro M1 :

- commencer CPU multi-thread + Metal vertex/fragment classique ;
- utiliser compute pour certains masks si utile ;
- limiter les draw calls par chunk ;
- texture arrays plutôt qu’un matériau par biome ;
- éviter les simulations lourdes runtime ;
- ajouter argument buffers quand le nombre de ressources augmente ;
- feature-gater mesh shaders/sparse textures selon support réel ;
- profiler tôt avec GPU counters/Xcode.

---

## 15. Règles de placement des structures verticales attachées

### 15.1 Générateurs dédiés

- `RopeRouteGenerator` ;
- `CliffStairGenerator` ;
- `LadderGenerator` ;
- `CornicePathGenerator` ;
- `SuspendedBridgeGenerator` ;
- `RockLedgeGenerator` ;
- `CaveEntranceGenerator` ;
- `WaterfallSidePathGenerator`.

### 15.2 Score d’attachement

```text
attachScore = cliffScore
            * rockStability
            * accessTop
            * accessBottom
            * gameplayNeed
            * biomeCompatibility
            * worldEraCompatibility
            * spacingConstraint
```

### 15.3 Règles d’époque/style

Le point 14 du projet prévoit des mondes RPG où les règles changent selon seed. Le terrain doit préparer cela :

- monde primitif : lianes, racines, sentiers, marches taillées ;
- médiéval/fantasy : ponts de bois, cordes, escaliers en pierre, ruines ;
- moderne : routes, tunnels, escaliers métalliques, câbles ;
- futuriste : ascenseurs, plateformes, drones, ponts énergétiques ;
- monde hostile : accès rares, falaises dangereuses ;
- monde exploration : accès nombreux, routes verticales lisibles.

---

## 16. Validation automatique

### 16.1 Métriques qualité

Chaque chunk ou région doit produire :

- min/max height ;
- slope histogram ;
- walkable ratio ;
- climbable ratio ;
- water ratio ;
- material coverage ;
- seam error ;
- collision triangle count ;
- render vertex count ;
- prop spawn density ;
- traversal route count ;
- unreachable area ratio.

### 16.2 Validateurs

```swift
protocol TerrainValidator {
    func validate(_ chunk: TerrainChunkData, context: TerrainValidationContext) -> [TerrainIssue]
}
```

Issues :

- seam visible ;
- rivière qui monte trop ;
- lac non plat ;
- falaise sans matériau rocheux ;
- route verticale sans accès haut/bas ;
- collision trop dense ;
- nav bloquée ;
- matériau absent ;
- biome incohérent ;
- chunk trop cher.

---

## 17. Debug tooling indispensable

Modes de debug renderer :

- altitude ;
- slope ;
- curvature ;
- biome ;
- sub-biome ;
- archetype ;
- rock type ;
- material layer 0–3 ;
- splat weights ;
- flow accumulation ;
- river distance ;
- wetness ;
- snow ;
- erosion ;
- sediment ;
- debris ;
- walkability ;
- climbability ;
- rope anchor score ;
- stair attach score ;
- fall danger ;
- feature IDs ;
- chunk LOD ;
- seam diagnostics.

Sans ces vues, le système deviendra impossible à régler.

---

## 18. Design d’un DSL de règles terrain

Un mini DSL interne peut rendre les règles lisibles :

```swift
let alpineCliffRule = TerrainRule(
    id: "alpine_cliff_rock",
    when: .all([
        .slopeGreaterThan(62),
        .elevationGreaterThan(900),
        .biomeIn([.alpine, .snowMountain])
    ]),
    apply: [
        .material(.granite, weight: 0.8),
        .material(.snow, weight: .byTemperature),
        .setClimbability(.fromRockStability),
        .spawnDebrisAtFoot,
        .enableTriplanar
    ],
    priority: 80
)
```

Règles importantes :

- règles de matériau ;
- règles de gameplay ;
- règles hydrologie ;
- règles de props ;
- règles de danger ;
- règles de LOD.

---

## 19. Proposition de roadmap d’implémentation

### Phase 1 — Terrain fields propres

- `TerrainSample` complet ;
- world-space sampling ;
- slope/curvature ;
- debug layers ;
- materials par slope/height/biome ;
- seams robustes.

### Phase 2 — Feature Graph minimal

- `TerrainFeatureGraph` ;
- mountain ranges ;
- rivers simples ;
- lakes simples ;
- cliffs bands ;
- query par chunk.

### Phase 3 — Hydrologie jouable

- river graph déterministe ;
- carving ;
- lake flattening ;
- water masks ;
- waterfalls simples ;
- shore materials.

### Phase 4 — Verticalité gameplay

- climbability map ;
- rope anchor candidates ;
- stair attach candidates ;
- routes verticales ;
- génération de rope/ladder/stair props ;
- validation haut/bas.

### Phase 5 — Matériaux AAA-ish

- texture arrays réelles ;
- triplanar cliffs ;
- macro variation ;
- wetness/snow/moss ;
- decals ;
- debug splat.

### Phase 6 — Patches volumétriques

- cave system SDF local ;
- arches/overhangs ;
- mesh extraction CPU async ;
- collision mesh ;
- entrances connected to terrain.

### Phase 7 — LOD/streaming avancé

- chunk LODs ;
- geomorph/stitching ;
- collision LOD ;
- GPU culling ;
- argument buffers ;
- sparse/virtual textures si besoin.

### Phase 8 — Authoring tools

- visualiseur seed ;
- sliders recipe ;
- export/import recipe JSON ;
- screenshot/debug batch ;
- validation automatique ;
- galerie de seeds.

---

## 20. Recommandations concrètes pour IsoWorld maintenant

### 20.1 À faire en premier

1. Créer `TerrainSample` et `TerrainDebugLayers`.
2. Remplacer progressivement les décisions ad hoc par des fields nommés.
3. Ajouter slope/curvature/wetness/material weights.
4. Ajouter un `TerrainFeatureGraph` même minimal.
5. Faire les rivières comme features continues.
6. Ajouter un debug mode `climbability` avant même d’avoir l’escalade.
7. Ajouter `VerticalTraversalCandidate` dans les données de chunk.
8. Garder `EngineCore` pur et testable.

### 20.2 À éviter

- générer une rivière indépendamment dans chaque chunk ;
- baser tous les biomes sur un seul noise ;
- multiplier les draw calls par matériau ;
- texturer les falaises avec les mêmes UV que le sol plat ;
- lancer une grosse érosion runtime synchrone ;
- rendre la verticalité uniquement décorative ;
- stocker des décisions dans un RNG consommé dans un ordre variable ;
- ne pas avoir de debug views.

### 20.3 Structure de données prioritaire

```swift
struct TerrainChunkData {
    let chunkID: ChunkID
    let coord: ChunkCoord
    let seed: UInt64
    let sampleGrid: TerrainSampleGrid
    let mesh: TerrainMeshData
    let collision: TerrainCollisionData
    let materialSplats: TerrainSplatGrid
    let water: TerrainWaterData
    let traversal: TerrainTraversalData
    let features: [TerrainFeatureRef]
    let validation: TerrainValidationReport
}
```

---

## 21. Conclusion

Le bon système pour IsoWorld est un **terrain génératif hybride, field-driven, feature-driven et gameplay-aware**. Le terrain ne doit pas être seulement une surface à rendre, mais une source de règles pour tout le reste : props, biomes, eau, navigation, RPG, verticalité, collisions, météo, matériaux et storytelling.

La verticalité doit être un concept de première classe. Cela veut dire : détecter les parois, classifier leur jouabilité, générer des routes verticales, attacher des structures, valider l’accès, produire les collisions et afficher les debug layers. C’est cette approche qui permettra d’avoir des falaises qu’on peut grimper, des escaliers attachés, des canyons explorables, des grottes connectées et un monde qui semble à la fois naturel et conçu pour le jeu.

La trajectoire recommandée est progressive : d’abord un heightfield propre et très instrumenté, puis un Feature Graph, puis hydrologie/verticalité, puis matériaux avancés, puis patches volumétriques. Cela donne un chemin réaliste sur MacBook Pro M1 tout en préparant une architecture ambitieuse et moderne.

---

## 22. Sources principales

- IsoWorldPOC README — https://github.com/agaloppe84/IsoWorldPOC
- IsoWorldPOC Architecture — https://github.com/agaloppe84/IsoWorldPOC/blob/main/docs/ARCHITECTURE.md
- Unreal Engine Landscape Technical Guide — https://dev.epicgames.com/documentation/unreal-engine/landscape-technical-guide-in-unreal-engine
- Unreal Engine PCG Overview — https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-overview
- Houdini Heightfields and Terrains — https://www.sidefx.com/docs/houdini/heightfields/index.html
- Houdini Heightfield Erosion — https://www.sidefx.com/docs/houdini/heightfields/erosion.html
- NVIDIA GPU Gems 3, Chapter 1 — https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-1-generating-complex-procedural-terrains-using-gpu
- Terrain Generation Using Procedural Models Based on Hydrology — https://www.cs.purdue.edu/cgvlab/www/resources/papers/Genevaux-ACM_Trans_Graph-2013-Terrain_Generation_Using_Procedural_Models_Based_on_Hydrology.pdf
- Visually Improved Erosion Algorithm for Tile-based Terrain — https://arxiv.org/abs/2210.14496
- World Machine — https://www.world-machine.com/
- World Creator Distributions — https://docs.world-creator.com/reference/terrain/distributions
- Gaea Erosion Documentation — https://docs.quadspinner.com/Guide/Using-Gaea/Erosion.html
- Far Cry 5 Procedural World Generation — https://www.gdcvault.com/play/1025557/Procedural-World-Generation-of-Far
- Far Cry 5 Terrain Rendering — https://www.gdcvault.com/play/1025261/Terrain-Rendering-in-Far-Cry
- Ghost Recon Wildlands Terrain Tools — https://gdcvault.com/play/1024708/-Ghost-Recon-Wildlands-Terrain
- Apple Metal Mesh Shaders WWDC22 — https://developer.apple.com/videos/play/wwdc2022/10162/
- Apple Argument Buffers — https://developer.apple.com/documentation/metal/improving-cpu-performance-by-using-argument-buffers
- Apple Sparse Heaps and Sparse Textures — https://developer.apple.com/documentation/metal/creating-sparse-heaps-and-sparse-textures
- Infinigen — https://infinigen.org/
