# IsoWorld — Point 10 — Système LOD moderne inspiré de Nanite

**Sujet unique :** analyser le système **Nanite** d’Unreal Engine et d’autres méthodes modernes de LOD pour concevoir un système IsoWorld ultra bien pensé, moderne, déterministe, versatile, compatible avec un moteur custom Swift/Metal sur Apple Silicon.

**Contexte moteur :** IsoWorld vise un monde procédural déterministe, chunké, généré dynamiquement autour du joueur, avec terrain, biomes, props procéduraux/paramétriques, verticalité, structures, météo et gameplay systémique. Le système LOD doit donc être pensé comme une couche transversale du moteur, pas comme une simple option de rendu.

---

## 0. Résumé exécutif

Nanite n’est pas seulement un “LOD automatique”. C’est une architecture de **virtualized geometry** : les meshes sont convertis dans un format interne composé de petits groupes de triangles hiérarchisés, compressés, streamés et sélectionnés selon la vue. L’objectif n’est plus de choisir manuellement entre `LOD0`, `LOD1`, `LOD2`, mais de rendre uniquement la quantité de géométrie nécessaire à l’écran, avec des transitions invisibles, une très forte densité d’instances, une réduction du coût CPU et une meilleure compatibilité avec les pipelines GPU-driven.

Pour IsoWorld, la bonne direction n’est pas de copier Nanite à l’identique. La bonne direction est de construire un système **Nanite-inspired**, adapté à :

- un monde procédural infini ou quasi-infini ;
- une génération par chunks autour du joueur ;
- des assets procéduraux créés à partir de recettes paramétriques ;
- du terrain hybride heightfield + falaises mesh + grottes/SDF locaux ;
- beaucoup de props naturels et manufacturés ;
- des contraintes Apple Silicon / Metal ;
- une première cible MacBook Pro M1, avec évolutivité M2/M3/M4+ ;
- une architecture déterministe où les IDs, pages, chunks, variantes et décisions de streaming restent stables pour une seed donnée.

La proposition centrale est un système appelé ici :

```text
IsoWorld Virtual Detail System, ou IVDS
```

IVDS combine cinq familles de LOD :

1. **Chunk LOD** — sélection et streaming des zones du monde.
2. **Terrain LOD** — quadtree/clipmap pour sol, falaises, canyons, mers, grottes visibles.
3. **Cluster/Meshlet LOD** — géométrie statique dense, rochers, bâtiments, ruines, props.
4. **HLOD / Macro proxy** — agrégation de groupes de props, villages, forêts, formations rocheuses.
5. **Specialized LOD** — foliage, personnages, animaux, FX, eau, particules, cordes, tissus, transparences.

Le système doit commencer simple, puis évoluer vers une virtualisation géométrique plus agressive :

```text
Phase 1 : LOD classique + HLOD + culling GPU simple
Phase 2 : Meshlets/clusters + sélection GPU + indirect command buffers
Phase 3 : pages géométriques streamées + feedback GPU
Phase 4 : mesh shaders Metal quand disponibles + pipeline visibility-buffer
Phase 5 : micro-geometry virtuelle pour terrain/props haute densité
```

---

## 1. Ce que Nanite apporte réellement

### 1.1. Objectif réel

Nanite vise à résoudre plusieurs problèmes qui étaient traditionnellement séparés :

- coût des draw calls ;
- coût CPU de sélection des objets visibles ;
- fabrication manuelle de LODs ;
- popping visuel entre LODs ;
- mémoire géométrique ;
- streaming de meshes lourds ;
- scènes à très forte densité d’instances ;
- usage de meshes photogrammétriques ou sculptés très denses ;
- réduction de la dépendance aux normal maps pour simuler du détail géométrique.

La documentation d’Unreal décrit Nanite comme un système de géométrie virtualisée utilisant un format interne, un rendu à détail pixel-scale, une compression forte, du streaming fin et du LOD automatique. Elle précise aussi que les meshes sont analysés à l’import, divisés en clusters hiérarchiques de groupes de triangles, puis ces clusters sont échangés à différents niveaux de détail selon la caméra, sans fissures visibles entre clusters voisins d’un même objet.

### 1.2. Architecture conceptuelle

On peut résumer Nanite comme suit :

```text
High poly asset
  -> import/build step
  -> clusterization
  -> simplification hierarchy
  -> compression / quantization
  -> page streaming data
  -> runtime cluster selection
  -> GPU culling
  -> specialized rasterization / shading path
  -> fallback meshes for unsupported paths
```

Les mots importants :

- **cluster** : petit paquet cohérent de triangles ;
- **hiérarchie** : représentation multi-résolution ;
- **erreur géométrique** : mesure permettant de savoir si une version simplifiée est acceptable à l’écran ;
- **streaming fin** : charger seulement les détails nécessaires ;
- **fallback** : géométrie alternative pour collision, ray tracing, plateformes non compatibles, debug, etc. ;
- **GPU-driven** : le GPU prend une partie des décisions de visibilité et de niveau de détail ;
- **pixel scale** : la densité géométrique est bornée par la contribution réelle à l’écran.

### 1.3. Ce qu’il faut retenir pour IsoWorld

Nanite montre que le bon axe n’est pas seulement :

```text
objet loin = LOD bas
objet proche = LOD haut
```

Le bon axe est plutôt :

```text
Chaque petite portion de géométrie choisit sa représentation selon :
- sa taille à l’écran,
- son erreur visuelle,
- son occlusion,
- sa distance,
- sa priorité gameplay,
- sa matière,
- sa contribution ombre/GI,
- son coût mémoire,
- son état de streaming.
```

Pour IsoWorld, cela implique que le LOD doit être **local**, **hiérarchique**, **data-driven**, **budget-driven**, et pas seulement basé sur une distance globale.

---

## 2. Limites de Nanite à connaître avant de s’en inspirer

Nanite est très puissant, mais il n’est pas une solution magique universelle. Les limites sont aussi importantes que les points forts, car elles indiquent ce qu’IsoWorld doit gérer explicitement.

### 2.1. Déformation complexe

Nanite est historiquement plus naturel pour la géométrie rigide ou faiblement déformée. La documentation récente mentionne un support sur Static Mesh, Skeletal Mesh, Instanced Static Mesh, Spline Mesh, HISM, Geometry Collection, foliage/landscape grass, etc., mais les déformations complexes restent contraintes. Morph targets non supportés dans certains chemins, World Position Offset limité, bornes de clusters à gérer, clamping nécessaire.

Conséquence pour IsoWorld :

- les props statiques, rochers, falaises, murs, ruines, meubles, troncs morts, statues, routes, escaliers, ponts sont de bons candidats ;
- les personnages jouables, animaux articulés, vêtements, cordes dynamiques, tissus, tentacules et végétation très animée doivent avoir un pipeline spécialisé ;
- la végétation doit combiner meshlets, impostors, cartes alpha, animation légère et règles de densité.

### 2.2. Matériaux

Nanite privilégie les matériaux opaques ou masked. Les matériaux translucides, les effets de refraction, certains decals et certains shaders très custom peuvent nécessiter un autre chemin.

Conséquence pour IsoWorld :

- les géométries solides doivent passer dans IVDS ;
- l’eau, le verre, la fumée, les particules, les hologrammes et certains feuillages alpha doivent passer dans des systèmes spécialisés ;
- on doit éviter de lier le LOD géométrique à une unique stratégie matériau.

### 2.3. Streaming et data size

Nanite réduit énormément certains coûts, mais il déplace une partie du problème vers :

- la taille disque ;
- le streaming ;
- la compression/décompression ;
- la gestion de pools mémoire ;
- le cache thrashing si le pool est trop petit ;
- les fallbacks pour les systèmes non Nanite.

Conséquence pour IsoWorld :

- le système doit avoir des budgets mémoire stricts ;
- chaque asset procédural doit pouvoir produire un **root representation** toujours résident ;
- les détails doivent être divisés en pages ;
- les pages doivent avoir des priorités ;
- le streaming doit être prévisible et déterministe.

### 2.4. Pas une raison d’ignorer l’optimisation

Même avec Nanite, les performances restent dépendantes de :

- résolution écran ;
- complexité matériaux ;
- overdraw ;
- transparence ;
- instance count ;
- ombres ;
- ray tracing ;
- streaming ;
- cache ;
- fréquence de mise à jour.

Pour IsoWorld, il faut donc une philosophie :

```text
La virtualized geometry ne remplace pas les budgets. Elle rend les budgets plus intelligents.
```

---

## 3. Autres méthodes modernes à intégrer

### 3.1. LOD classique par niveaux discrets

Toujours utile pour :

- personnages ;
- animaux ;
- meshes skinnés ;
- objets interactifs ;
- plateformes faibles ;
- prototypes ;
- fallback ;
- collision ;
- shadow-only simplifications.

Pattern :

```text
LOD0 : très proche / interaction / cinématique
LOD1 : proche gameplay
LOD2 : distance moyenne
LOD3 : loin
LOD4 : très loin / silhouette
LOD5 : billboard / impostor / HLOD
```

À ne pas jeter. IVDS doit garder ce système comme fallback stable.

### 3.2. HLOD

Le HLOD agrège des objets pour les longues distances. Exemple : une ville, un hameau, une forêt, un champ de rochers ou un ensemble de ruines peut être rendu comme un proxy simplifié et matérialisé.

Utilisations IsoWorld :

- villages procéduraux ;
- villes futuristes ;
- forêts denses ;
- falaises composées de nombreux blocs ;
- champs de cailloux ;
- ruines ;
- camps ;
- zones industrielles ;
- formations géologiques ;
- biome lointain complet.

Le HLOD n’est pas seulement visuel. Il peut aussi être utilisé pour :

- navigation lointaine ;
- collision grossière ;
- audio/occlusion ;
- minimap ;
- génération de silhouettes ;
- ombres longues distance ;
- prévisualisation d’un chunk non chargé.

### 3.3. Meshlets / clusters

Un meshlet est un petit groupe de triangles optimisé pour le GPU, souvent autour de 32 à 128 triangles, avec un nombre borné de vertices. Il est adapté à :

- culling fin ;
- mesh shaders ;
- compression ;
- réutilisation cache ;
- calcul d’erreur local ;
- occlusion locale ;
- LOD local.

Pour IsoWorld, les meshlets sont la brique idéale entre “mesh entier” et “triangle individuel”.

### 3.4. GPU-driven rendering

Le principe : le CPU n’envoie pas des milliers de draw calls précis chaque frame. Il envoie des buffers de données, et le GPU décide :

- quels chunks sont visibles ;
- quelles instances sont visibles ;
- quels clusters sont visibles ;
- quels clusters ont besoin de plus de détails ;
- quels draws indirects doivent être produits.

Sur Metal, cela passe par :

- compute passes ;
- indirect command buffers ;
- argument buffers ;
- heaps ;
- sparse textures ;
- mesh shaders quand disponibles ;
- buffers de feedback.

### 3.5. Clipmaps terrain

Pour le terrain très large, un système de clipmaps ou quadtree LOD reste extrêmement pertinent.

Approche :

```text
autour du joueur : haute résolution
plus loin : anneaux de résolution décroissante
très loin : macro-mesh/HLOD/heightfield simplifié
horizon : sky/atmosphere/terrain impostor
```

IsoWorld peut utiliser :

- height clipmaps pour plaines, collines, dunes ;
- mesh clusters pour falaises, canyons, arches, grottes ouvertes ;
- SDF/voxel local pour grottes et surplombs ;
- HLOD pour silhouettes montagneuses lointaines.

### 3.6. Impostors

Les impostors restent indispensables pour :

- arbres lointains ;
- forêts denses ;
- herbe ;
- fougères ;
- nuages bas ;
- rochers très lointains ;
- détails urbains ;
- foules lointaines ;
- animaux très lointains.

Types :

- billboard simple ;
- cross billboard ;
- octahedral impostor ;
- volumetric impostor ;
- baked normal/depth impostor ;
- impostor animé par frames ;
- impostor par biome pour masses de végétation.

### 3.7. Appearance-preserving simplification

Les systèmes modernes ne simplifient pas seulement la géométrie. Ils essayent de préserver l’apparence :

- silhouette ;
- normales ;
- matériaux ;
- occlusion ;
- roughness ;
- variation de couleur ;
- détails perçus ;
- ombres.

IsoWorld doit utiliser des métriques perceptuelles, pas seulement le nombre de triangles.

### 3.8. Voxel/SDF LOD

Pour les grottes, falaises creuses, surplombs, terrains destructibles partiels ou volumes procéduraux, un LOD purement mesh peut être difficile. On peut utiliser :

- SDF local pour collision et génération ;
- extraction mesh à différentes résolutions ;
- voxel sparse pour structures modifiables ;
- mesh final clusterisé pour le rendu ;
- collision simplifiée par niveau.

### 3.9. Point cloud / Gaussian / neural LOD — recherche future

Les travaux récents sur les représentations type 3D Gaussian Splatting explorent aussi des LOD hiérarchiques/clusterisés. Ce n’est pas une priorité pour IsoWorld gameplay, mais c’est intéressant pour :

- décors photogrammétriques ;
- sky distant ;
- ruines scannées ;
- souvenirs/visions ;
- cinématiques ;
- volumes atmosphériques.

---

## 4. Vision IsoWorld : IVDS

### 4.1. Nom proposé

```text
IsoWorld Virtual Detail System
IVDS
```

Rôle : gérer la représentation multi-échelle de toute géométrie rendable, collisionnable ou streamable.

### 4.2. Objectifs

IVDS doit :

- réduire le coût CPU ;
- réduire les draw calls ;
- rendre des assets haute densité ;
- éviter les LOD pops ;
- gérer les mondes chunkés ;
- préserver la cohérence déterministe ;
- gérer terrain, props, structures, végétation, bâtiments ;
- produire des fallbacks collision/navigation ;
- fonctionner sur M1 avec un chemin robuste ;
- évoluer vers mesh shaders / GPU-driven complet ;
- fournir des debug views puissantes.

### 4.3. Non-objectifs immédiats

À ne pas viser en V1 :

- clone complet de Nanite ;
- rasterizer logiciel custom très complexe ;
- virtualisation parfaite des meshes skinnés ;
- streaming disque ultra agressif dès le prototype ;
- ray tracing full detail ;
- transparence virtualisée ;
- foliage Nanite-like complet.

Ces éléments peuvent venir plus tard.

---

## 5. Architecture globale

### 5.1. Niveaux du système

```text
World
  -> Region
    -> Chunk
      -> TerrainPatch
      -> StaticPropInstance
      -> ProceduralStructure
      -> FoliageCell
      -> Character/Creature
      -> FXEmitter
```

Chaque niveau a un LOD différent :

```text
World/Region        : streaming macro, biome/HLOD
Chunk               : load/unload, proxy, collision coarse
TerrainPatch        : quadtree/clipmap/mesh clusters
StaticPropInstance  : cluster LOD / meshlet LOD / HLOD
FoliageCell         : density LOD / impostor / wind LOD
Character           : skeletal LOD / animation LOD / material LOD
FXEmitter           : particle count LOD / simulation LOD
```

### 5.2. Les quatre couches de données

#### 5.2.1. Geometry source

Données hautes résolutions :

- mesh importé ;
- mesh généré procéduralement ;
- terrain extrait ;
- falaise générée ;
- structure assemblée ;
- végétation procédurale ;
- scan/photogrammétrie futur.

#### 5.2.2. Runtime render representation

Données optimisées pour le GPU :

- clusters ;
- meshlets ;
- pages ;
- bounds ;
- errors ;
- material bins ;
- compressed vertex streams ;
- index streams ;
- per-cluster metadata ;
- root mesh always resident.

#### 5.2.3. Runtime gameplay representation

Données optimisées pour simulation :

- collision simple ;
- collision détaillée proche ;
- navmesh ;
- climb surfaces ;
- footstep surfaces ;
- cover points ;
- sound occluders ;
- interaction anchors.

#### 5.2.4. Debug/authoring representation

Données de validation :

- erreur visuelle ;
- cluster ID ;
- page ID ;
- seed provenance ;
- source recipe ;
- budgets ;
- fallback actif ;
- raison de culling ;
- raison de LOD.

---

## 6. Data model proposé

### 6.1. `VirtualGeometryAsset`

Représente un asset compatible IVDS.

```swift
struct VirtualGeometryAssetID: Hashable, Codable {
    var sourceRecipeID: UInt64
    var seedHash: UInt64
    var variantHash: UInt64
    var buildVersion: UInt32
}

struct VirtualGeometryAssetHeader {
    var assetID: VirtualGeometryAssetID
    var bounds: AABB
    var rootNodeIndex: UInt32
    var clusterCount: UInt32
    var nodeCount: UInt32
    var pageCount: UInt32
    var materialCount: UInt16
    var collisionLODCount: UInt8
    var flags: UInt32
}
```

Important : l’ID doit être dérivé de la seed, de la recette, des paramètres et de la version du builder. Ainsi, un même monde produit les mêmes pages et clusters.

### 6.2. `VirtualCluster`

```swift
struct VirtualCluster {
    var clusterID: UInt32
    var pageID: UInt32
    var vertexOffset: UInt32
    var vertexCount: UInt16
    var indexOffset: UInt32
    var triangleCount: UInt16
    var bounds: AABB
    var coneAxis: SIMD3<Float>
    var coneCutoff: Float
    var geometricError: Float
    var materialBin: UInt16
    var childMaskOrOffset: UInt32
    var parentMaskOrOffset: UInt32
}
```

Données clés :

- `bounds` pour frustum/occlusion ;
- `coneAxis/coneCutoff` pour backface cone culling ;
- `geometricError` pour LOD ;
- `materialBin` pour batching ;
- parent/children pour hiérarchie.

### 6.3. `VirtualClusterNode`

```swift
struct VirtualClusterNode {
    var bounds: AABB
    var error: Float
    var firstChild: UInt32
    var childCount: UInt16
    var firstCluster: UInt32
    var clusterCount: UInt16
    var pageID: UInt32
    var minScreenPixels: Float
    var maxScreenPixels: Float
}
```

Un node peut représenter :

- un groupe de clusters détaillés ;
- un proxy simplifié ;
- un niveau intermédiaire ;
- un ensemble streamable.

### 6.4. `GeometryPage`

```swift
struct GeometryPage {
    var pageID: UInt32
    var compressedOffset: UInt64
    var compressedSize: UInt32
    var uncompressedSize: UInt32
    var clusterStart: UInt32
    var clusterCount: UInt16
    var priorityBase: UInt16
    var residencyFlags: UInt32
}
```

Page size recommandée :

```text
64 KB à 256 KB compressés
```

Règle : une page doit être assez grande pour amortir IO/décompression, mais assez petite pour streamer du détail fin.

### 6.5. `InstanceRecord`

```swift
struct IVDSInstanceRecord {
    var instanceID: UInt64
    var assetIDIndex: UInt32
    var transform: simd_float4x3
    var bounds: AABB
    var chunkID: UInt64
    var materialOverrideIndex: UInt32
    var gameplayPriority: UInt16
    var lodBias: Int8
    var flags: UInt32
}
```

`gameplayPriority` est important. Un objet interactif proche doit garder un meilleur LOD qu’un décor équivalent.

### 6.6. `ChunkLODRecord`

```swift
struct ChunkLODRecord {
    var chunkID: UInt64
    var worldBounds: AABB
    var terrainLODState: UInt32
    var visibleInstanceRange: Range<UInt32>
    var residentPageRange: Range<UInt32>
    var hlodProxyID: UInt32
    var biomePriority: UInt16
    var streamingPriority: UInt16
}
```

---

## 7. Build pipeline offline/procédural

### 7.1. Pourquoi un build pipeline est indispensable

Nanite fait énormément de travail à l’import. IsoWorld doit faire pareil, mais avec deux modes :

1. **Offline build** pour assets importés ou recettes stables.
2. **Runtime/async build** pour props procéduraux ou terrain généré dynamiquement.

Le runtime ne doit pas générer toute la hiérarchie haute qualité sur le thread render. Il faut :

- précompiler les recettes communes ;
- cacher les variantes ;
- générer les niveaux proches en priorité ;
- produire des proxies rapides avant les détails ;
- streamer les pages détaillées plus tard.

### 7.2. Étapes de build pour un asset statique

```text
1. Source mesh ou procedural mesh haute qualité
2. Nettoyage topologique
3. Split par matériau / contraintes de shading
4. Clusterization en meshlets
5. Calcul bounds / normal cones / erreurs
6. Simplification hiérarchique
7. Construction DAG ou arbre LOD
8. Quantization positions/normales/UVs
9. Compression pages
10. Génération fallback mesh
11. Génération collision LODs
12. Génération impostor optionnel
13. Génération debug metadata
14. Packaging asset IVDS
```

### 7.3. Étapes de build pour terrain procédural

```text
1. Générer heightfield macro du chunk
2. Identifier features : falaise, canyon, rive, crête, grotte, route
3. Créer patch terrain régulier
4. Créer meshes verticaux/overhangs séparés
5. Générer collision coarse proche/loin
6. Clusteriser falaises et features verticales
7. Créer HLOD terrain lointain
8. Créer pages matériau/texture virtuelle
9. Créer anchors gameplay : escalade, corde, escalier, saut
10. Créer debug overlays
```

### 7.4. Étapes de build pour props procéduraux

```text
Recipe + Seed + Biome + Era + MaterialRules
  -> paramètres morphologiques
  -> mesh haute qualité
  -> variantes de détail
  -> clusterization
  -> fallback/collision
  -> impostor si applicable
  -> cache par hash
```

Exemples :

- arbre généré : tronc/branches séparés, feuilles en pipeline foliage ;
- rocher : mesh dense virtualisé + collision simplifiée ;
- table : mesh simple LOD classique ou cluster si très détaillée ;
- lampadaire : HLOD urbain lointain, mesh détaillé proche ;
- statue : excellent candidat IVDS ;
- bâtiment : HLOD par façade, clusterisation des ornements, proxy lointain.

---

## 8. Sélection LOD

### 8.1. Erreur écran

Le cœur d’un système Nanite-like est de choisir selon l’erreur projetée à l’écran.

Concept :

```text
screenError = geometricError * projectionScale / distanceToCamera
```

Si `screenError` est inférieur à un seuil, le node simplifié est acceptable. Sinon, il faut descendre dans la hiérarchie.

Critères à combiner :

- erreur géométrique ;
- taille écran ;
- priorité gameplay ;
- matériau ;
- silhouette ;
- mouvement caméra ;
- contribution ombre ;
- contribution collision/interaction ;
- état de streaming ;
- budget frame.

### 8.2. Hystérésis

Pour éviter le flickering :

```text
LOD monte en qualité si screenError > thresholdHigh
LOD baisse en qualité si screenError < thresholdLow
```

Avec :

```text
thresholdLow < thresholdHigh
```

### 8.3. Budget global

Le système ne doit pas seulement dire “ce cluster veut plus de détail”. Il doit arbitrer un budget :

- maximum clusters visibles ;
- maximum triangles visibles ;
- maximum pages demandées par frame ;
- maximum décompression ;
- maximum ICB commands ;
- maximum GPU time ;
- maximum memory residency.

Une politique de qualité :

```text
Priorité 1 : gameplay proche / collision / silhouette joueur
Priorité 2 : objets proches visibles
Priorité 3 : ombres proches
Priorité 4 : structures moyennes distances
Priorité 5 : terrain lointain
Priorité 6 : détails décoratifs
Priorité 7 : éléments non interactifs lointains
```

### 8.4. LOD bias contextuel

Le LOD ne doit pas être seulement une distance. Exemples :

- pendant une cinématique : augmenter la qualité des personnages/décors cadrés ;
- pendant une tempête : réduire le détail lointain caché par brume ;
- dans une grotte sombre : réduire certains détails invisibles ;
- en escalade : augmenter détail de la falaise proche ;
- en combat : garder les obstacles proches précis ;
- en mode photo : augmenter budgets ;
- sur batterie : réduire budgets.

---

## 9. Culling moderne

### 9.1. Culling par niveaux

```text
CPU coarse culling
  -> chunk frustum
GPU instance culling
  -> instance bounds
GPU cluster culling
  -> cluster bounds
GPU occlusion culling
  -> Hi-Z depth pyramid
GPU triangle/backface cone culling
  -> optional
```

### 9.2. Frustum culling

Simple et obligatoire. À appliquer sur :

- chunks ;
- instances ;
- cluster nodes ;
- clusters ;
- lights/shadow casters.

### 9.3. Occlusion culling Hi-Z

Créer une pyramide de profondeur de la frame précédente ou courante :

```text
Depth buffer -> downsample min/max -> Hi-Z texture
```

Ensuite, tester les bounds d’un cluster contre cette pyramide.

Deux phases possibles :

1. culling avec profondeur frame précédente ;
2. rendu visible ;
3. mise à jour profondeur ;
4. retest des faux occlus ;
5. rendu post-pass.

Cette approche évite de dépendre de proxies d’occlusion low-poly, et s’accorde bien avec un monde procédural dense.

### 9.4. Backface cone culling

Pour chaque cluster, stocker un cône de normales. Si le cluster est orienté dos caméra, il peut être ignoré.

Efficace pour :

- falaises ;
- murs ;
- rochers ;
- bâtiments ;
- sculptures ;
- terrains verticaux.

Moins efficace pour :

- feuillage ;
- meshes double face ;
- objets très convexes ;
- alpha cards.

### 9.5. Small feature culling

Certains détails deviennent invisibles même avant d’être simplifiés :

- petits cailloux ;
- branches fines ;
- fissures ;
- ornements ;
- boulons ;
- brins d’herbe.

Ils peuvent être :

- fusionnés dans un material detail ;
- remplacés par normal/detail map ;
- remplacés par impostor ;
- supprimés selon densité perceptuelle.

---

## 10. Streaming géométrique

### 10.1. Principe

Chaque asset IVDS a :

- une représentation racine toujours disponible ;
- des pages intermédiaires ;
- des pages détaillées ;
- des pages optionnelles pour ombres/collision/debug.

Runtime :

```text
1. Le GPU détecte les pages manquantes ou désirées.
2. Il écrit un feedback buffer.
3. Le CPU lit avec retard contrôlé.
4. Le streamer priorise les pages.
5. Les pages sont chargées/décompressées.
6. Les pages deviennent résidentes.
7. Le rendu augmente la qualité progressivement.
```

### 10.2. Priorisation

Critères de priorité :

- distance caméra ;
- taille écran ;
- direction caméra ;
- vitesse caméra ;
- gameplay priority ;
- visibilité frame précédente ;
- importance ombres ;
- proximité joueur ;
- proximité curseur/interaction ;
- risque de pop-in ;
- biome/zone active.

### 10.3. Root residency

Chaque asset doit avoir un root mesh très compact :

```text
Root geometry always resident
```

But : jamais de trou visuel. Si une page manque, on rend une version plus grossière.

### 10.4. Gestion anti-thrashing

Le streaming peut thrash si :

- caméra se déplace vite ;
- budget trop bas ;
- pages trop petites ;
- page cache trop petit ;
- seuils LOD trop agressifs ;
- scènes très denses.

Solutions :

- hysteresis de résidence ;
- min lifetime d’une page ;
- prefetch dans la direction de déplacement ;
- throttling pages/frame ;
- fallback stable ;
- priorité aux clusters visibles plusieurs frames ;
- “degrade gracefully” au lieu de demander trop.

---

## 11. Pipeline Metal proposé

### 11.1. Chemin M1 robuste

Même si Metal évolue, il faut un chemin robuste pour MacBook Pro M1 :

```text
CPU builds coarse chunk list
Compute pass : instance culling
Compute pass : cluster/node selection
Compute pass : compaction visible clusters
Compute pass : build indirect commands / draw lists
Render pass : draw indexed/instanced visible clusters
Render pass : material/shading
```

Composants Metal :

- `MTLBuffer` pour instances/clusters/pages ;
- `MTLHeap` pour ressources ;
- `MTLIndirectCommandBuffer` pour commands GPU-driven ;
- argument buffers pour ressources bindless-like ;
- sparse textures pour virtual textures ;
- depth pyramid en compute ;
- fence/events pour synchronisation.

### 11.2. Chemin mesh shader quand disponible

Avec mesh shaders Metal :

```text
Object shader : lit les nodes/clusters, cull, choisit LOD
Mesh shader   : génère triangles du meshlet ou décompresse localement
Fragment      : shade
```

Avantages :

- moins de buffers intermédiaires ;
- génération procédurale locale ;
- culling plus fin ;
- pipeline plus direct ;
- bon alignement avec meshlets.

À garder optionnel, détecté par capabilities.

### 11.3. Argument buffers

Utiliser des argument buffers pour :

- matériaux ;
- textures ;
- vertex streams ;
- page tables ;
- cluster metadata ;
- instance data ;
- samplers.

Objectif : éviter les rebinding CPU fréquents.

### 11.4. Sparse textures

Pour les textures, IVDS doit être couplé à un système de virtual textures :

- albedo ;
- normal ;
- roughness ;
- masks ;
- height/displacement ;
- biome splats ;
- terrain material layers.

Sparse textures permettent de charger seulement les tiles utiles.

### 11.5. Visibility buffer optionnel

Pour scènes très denses, un visibility buffer peut remplacer un G-buffer lourd :

```text
Pass 1 : écrire primitive/cluster/material ID + barycentrics/depth
Pass 2 : shade en compute ou full-screen pass
```

Avantages :

- texturing différé ;
- meilleure gestion overdraw ;
- séparation géométrie/material ;
- compatible avec virtual textures ;
- adapté aux clusters.

Inconvénients :

- complexité élevée ;
- gradients/derivatives à reconstruire ;
- transparence à part ;
- debug plus difficile.

Recommandation : pas V1, mais bon objectif V3/V4.

---

## 12. Terrain LOD pour IsoWorld

### 12.1. Ne pas traiter le terrain comme un seul mesh

Le terrain IsoWorld doit gérer :

- plaines ;
- collines ;
- montagnes ;
- falaises ;
- canyons ;
- grottes ;
- arches naturelles ;
- surplombs ;
- chemins ;
- rivières ;
- lacs ;
- mers ;
- escaliers attachés ;
- cordes d’escalade ;
- plateformes verticales.

Un heightfield seul ne suffit pas. Il faut :

```text
Terrain = Heightfield patches + Vertical feature meshes + SDF/voxel local + water surfaces + decals/material layers
```

### 12.2. LOD terrain par type

| Type terrain | LOD recommandé |
|---|---|
| Plaine | clipmap/quadtree heightfield |
| Colline | quadtree + normal/detail maps |
| Montagne | quadtree + HLOD silhouette |
| Falaise | cluster meshlets + backface culling |
| Canyon | terrain patches + cliff clusters + river spline |
| Grotte | mesh extracted + portal/occlusion cells |
| Surplomb | SDF local -> mesh clusterisé |
| Route | spline mesh LOD + decals |
| Escalier vertical | mesh interactif + collision précise proche |
| Corde | specialized skeletal/curve LOD |
| Rivière | water mesh LOD + flow map |
| Mer | ocean grid/FFT/gerstner LOD spécialisé |

### 12.3. Crack-free terrain

Transitions à gérer :

- entre chunks ;
- entre LOD rings ;
- entre heightfield et cliff mesh ;
- entre terrain et props rocheux ;
- entre route et sol ;
- entre grotte et extérieur.

Techniques :

- skirts ;
- shared border samples ;
- deterministic edge quantization ;
- stitching patches ;
- morphing LOD ;
- decals/material blend ;
- snapping des features à la grille chunk ;
- edge ownership déterministe.

### 12.4. Verticalité gameplay

Pour escalade/corde/escaliers attachés aux falaises :

Chaque cluster ou feature verticale peut exposer des metadata :

```swift
struct VerticalGameplaySurface {
    var surfaceID: UInt64
    var bounds: AABB
    var normalMean: SIMD3<Float>
    var slopeRange: SIMD2<Float>
    var climbability: Float
    var ropeAnchorCandidates: UInt32
    var stairAttachCandidates: UInt32
    var ledgeCandidates: UInt32
    var materialID: UInt16
}
```

Les LOD visuels ne doivent pas casser les anchors gameplay. Les points d’interaction doivent être générés dans une couche stable, indépendante du LOD détaillé.

---

## 13. Props et structures

### 13.1. Catégories très compatibles IVDS

- rochers ;
- cailloux détaillés ;
- falaises ;
- statues ;
- ruines ;
- murs ;
- bâtiments ;
- ponts ;
- escaliers ;
- arches ;
- véhicules statiques ;
- machines ;
- mobilier détaillé ;
- colonnes ;
- sculptures ;
- débris ;
- rails ;
- panneaux ;
- lampadaires ;
- portails ;
- ossements géants ;
- épaves ;
- vaisseaux abandonnés ;
- architectures alien ;
- structures cristallines.

### 13.2. Catégories à pipeline mixte

- arbres ;
- buissons ;
- herbes ;
- lianes ;
- fougères ;
- cultures agricoles ;
- tentures ;
- drapeaux ;
- cordes ;
- chaînes ;
- câbles ;
- personnages ;
- animaux ;
- machines animées.

### 13.3. HLOD de structures

Exemple ville :

```text
Maison proche : mesh détaillé IVDS
Maison moyenne : cluster LOD simplifié
Quartier lointain : HLOD proxy
Ville horizon : silhouette + baked material + lights impostors
```

Exemple forêt :

```text
Arbres proches : trunks meshlets + leaves cards
Arbres moyens : simplified tree mesh + density cards
Forêt lointaine : canopy impostor field
Biome horizon : texture/volumetric haze
```

---

## 14. Végétation

### 14.1. Pourquoi c’est difficile

La végétation est difficile car elle combine :

- très grand nombre d’instances ;
- alpha/masked overdraw ;
- animation vent ;
- silhouettes fines ;
- densité variable ;
- ombres coûteuses ;
- interaction joueur ;
- saison/météo.

### 14.2. Stratégie IsoWorld

Diviser en sous-systèmes :

```text
Troncs / grosses branches -> IVDS clusters
Petites branches          -> simplified mesh / cards
Feuilles proches          -> cards/masked mesh
Feuilles moyennes         -> cluster cards + density LOD
Feuillage lointain        -> impostors / canopy fields
Herbe proche              -> procedural blades / mesh shader/compute
Herbe moyenne             -> cards instanced
Herbe lointaine           -> material layer / color noise
```

### 14.3. Preserve area

Lorsqu’on simplifie des feuilles, la surface peut disparaître. Il faut compenser :

- agrandir légèrement les cartes restantes ;
- préserver la masse visuelle ;
- préserver la silhouette ;
- préserver la densité de couleur ;
- réduire animation et ombre avec distance.

---

## 15. Personnages, animaux et objets déformables

### 15.1. Ne pas forcer IVDS partout

Un personnage jouable AAA a besoin de :

- skeletal mesh ;
- morphs ;
- cloth ;
- skinning ;
- animation LOD ;
- hair/fur ;
- physics ;
- decals/sang/boue ;
- équipement modulaire.

Le chemin Nanite-like n’est pas forcément le meilleur en V1.

### 15.2. Stratégie

```text
Corps proche : skeletal mesh LOD0/LOD1
Corps moyen : skeletal mesh LOD2 + reduced bones
Lointain : impostor animated / baked animation cards
Crowd : animation banks + instancing
Equipement rigide : IVDS possible par pièce
Armure/statue/robot rigide : IVDS partiel
```

### 15.3. Animation LOD

LOD pour l’animation :

- fréquence d’update ;
- nombre d’os actifs ;
- IK activée ou non ;
- cloth activé ou non ;
- physics activée ou non ;
- facial animation activée ou non ;
- foot placement précis seulement proche.

---

## 16. Collision LOD

### 16.1. Séparer rendu et collision

La géométrie de rendu ne doit pas être la collision. Il faut plusieurs niveaux :

```text
Collision LOD0 : proche, gameplay précis
Collision LOD1 : moyenne distance, déplacement joueur/NPC
Collision LOD2 : navigation et raycasts grossiers
Collision LOD3 : streaming/occlusion/audio
```

### 16.2. Cas terrain vertical

Pour falaises/escalade :

- collision proche précise ;
- anchors de grimpe stables ;
- ledges indépendants du rendu ;
- surface materials stables ;
- raycasts de pied/main sur LOD collision, pas sur cluster rendu ;
- update collision progressive quand un chunk devient proche.

### 16.3. Cas petits objets

Un petit rocher peut être :

- rendu en haute qualité proche ;
- collision capsule/convex simplifiée ;
- ignoré par navmesh lointain ;
- utilisé par foot IK seulement si proche ;
- intégré dans material roughness lointain.

---

## 17. Matériaux, textures et LOD

### 17.1. Le LOD géométrique doit être synchronisé avec les textures

Si on rend de la géométrie haute densité avec des textures pauvres, le résultat n’est pas AAA. Si on rend de bonnes textures sur une silhouette pauvre, pareil.

Il faut coupler :

```text
geometry LOD
texture mip/residency
material complexity
normal/detail intensity
shadow LOD
```

### 17.2. Virtual texturing

À terme, coupler IVDS à :

- virtual terrain textures ;
- sparse material pages ;
- splat maps biome ;
- decals virtuels ;
- baked HLOD materials.

### 17.3. Material LOD

Chaque material peut avoir plusieurs niveaux :

```text
Material LOD0 : full PBR, detail normals, parallax/displacement optionnel
Material LOD1 : PBR simplifié, detail normal réduit
Material LOD2 : textures mips, moins de layers
Material LOD3 : baked material atlas
Material LOD4 : color/roughness aggregate
```

### 17.4. Shading bins

Regrouper les clusters par material/shading mode :

- opaque simple ;
- opaque PBR complexe ;
- masked foliage ;
- terrain material ;
- emissive ;
- decal receiver ;
- shadow-only.

Objectif : réduire divergence shader et draw/dispatch fragmentation.

---

## 18. Ombres et LOD

### 18.1. Les ombres ont leur propre LOD

Un objet peut être invisible à la caméra mais visible dans une shadow map. Il faut donc une sélection LOD par vue :

- camera view ;
- shadow cascade 0 ;
- shadow cascade 1 ;
- local light shadow ;
- reflection capture ;
- minimap/debug.

### 18.2. Virtual shadow maps inspiration

Même si IsoWorld n’implémente pas tout de suite des virtual shadow maps, il faut préparer :

- page-based shadow rendering ;
- culling par light frustum ;
- LOD plus grossier pour ombres lointaines ;
- ombres détaillées pour gameplay proche ;
- ombres simplifiées pour foliage dense.

---

## 19. Déterminisme

### 19.1. Pourquoi c’est critique

IsoWorld dépend d’un monde déterministe par seed. Le système LOD ne doit pas modifier le monde, mais il doit être reproductible :

- mêmes assets ;
- mêmes IDs ;
- mêmes chunks ;
- mêmes pages ;
- mêmes caches ;
- mêmes fallbacks ;
- mêmes anchors gameplay.

### 19.2. Ce qui doit être déterministe

- hashing des recettes ;
- ordering des clusters ;
- génération de meshlets ;
- simplification ;
- quantization ;
- IDs de pages ;
- IDs de matériaux ;
- liens parent/enfant ;
- collision LOD ;
- HLOD build ;
- anchors gameplay.

### 19.3. Ce qui peut être non déterministe

- ordre exact de rendu ;
- timing de streaming ;
- cache residency ;
- budget qualité selon FPS ;
- debug overlays ;
- priorité frame locale.

Mais cela ne doit jamais changer la simulation persistante.

---

## 20. Qualité visuelle AAA

### 20.1. Ce qui rend un LOD “visible”

Un LOD se voit quand :

- la silhouette change brutalement ;
- les normales changent ;
- les matériaux changent ;
- la densité de feuillage change ;
- les ombres changent ;
- les détails disparaissent en périphérie ;
- les transitions se produisent pendant mouvement caméra ;
- les chunks pop-in ;
- le streaming manque des pages.

### 20.2. Règles de qualité

- préserver silhouette avant détails internes ;
- préserver landmarks ;
- préserver formes verticales ;
- préserver points d’interaction ;
- ne jamais changer collision gameplay à cause du LOD visuel ;
- utiliser hysteresis ;
- utiliser fade/dither uniquement quand utile ;
- utiliser morph LOD pour terrain ;
- utiliser impostors avec normal/depth ;
- utiliser matériaux compatibles à chaque LOD.

### 20.3. Métriques de validation

- erreur écran en pixels ;
- triangle/pixel ;
- clusters visibles ;
- overdraw ;
- page misses ;
- streaming latency ;
- shader cost ;
- shadow caster count ;
- VRAM/resident memory ;
- CPU render submission time ;
- GPU frame time ;
- LOD switches/frame ;
- visual diff screenshot A/B.

---

## 21. Liste longue : types de contenu et stratégie LOD

### 21.1. Terrain naturel

| Contenu | Stratégie LOD |
|---|---|
| Plaines | heightfield clipmap + material detail |
| Collines | quadtree + detail normals |
| Montagnes | terrain LOD + HLOD silhouette |
| Falaises | cluster meshlets + collision anchors |
| Canyons | terrain + cliff clusters + water spline |
| Plateaux | quadtree + edge cliff clusters |
| Ravins | feature meshes + occlusion cells |
| Crêtes | silhouette-preserving LOD |
| Éboulis | instancing + density LOD + HLOD |
| Champs de rochers | meshlets proches + impostors loin |
| Dunes | procedural material + low geom LOD |
| Banquise | terrain patches + crack decals |
| Glaciers | mesh clusters + translucent ice path séparé |
| Grottes | portal culling + mesh clusters |
| Arches naturelles | IVDS static mesh |
| Surplombs | SDF extracted mesh + clusters |
| Volcans | terrain + lava specialized material |
| Récifs | underwater cluster meshes + fog LOD |
| Fonds marins | terrain LOD + vegetation impostors |
| Marais | terrain + water/foliage specialized LOD |

### 21.2. Eau et surfaces fluides

| Contenu | Stratégie LOD |
|---|---|
| Rivière étroite | spline mesh + flow map + mesh LOD |
| Fleuve | tiled water surface + bank LOD |
| Lac | planar grid + shoreline detail |
| Mer | ocean LOD spécialisé |
| Cascade | mesh + particle LOD + mist impostor |
| Flaque | decal/plane LOD |
| Eau souterraine | simplified lighting + reflection LOD |
| Marée | terrain wetness + waterline LOD |

### 21.3. Rochers/minéraux

| Contenu | Stratégie LOD |
|---|---|
| Caillou | instance/proxy/merge by density |
| Rocher moyen | IVDS cluster asset |
| Mégalithe | IVDS + high quality close |
| Cristal | opaque/masked path, transparency separate |
| Minerai | material LOD + geometry close |
| Stalactite | IVDS + cave HLOD |
| Stalagmite | IVDS + collision simple |
| Fossile géant | IVDS candidate fort |
| Statue naturelle | IVDS + fallback collision |

### 21.4. Végétation

| Contenu | Stratégie LOD |
|---|---|
| Brin d’herbe | procedural close, material far |
| Touffe d’herbe | instancing + density LOD |
| Fleur | mesh/card close, impostor far |
| Roseau | cards + wind LOD |
| Buisson | mesh/card hybrid |
| Arbuste | trunk mesh + foliage cards |
| Arbre petit | hybrid IVDS/impostor |
| Arbre géant | trunk IVDS + canopy HLOD |
| Liane | curve/spline LOD |
| Racine | mesh clusters near ground |
| Champ cultivé | density field + impostor rows |
| Forêt | cell HLOD + canopy impostors |
| Champignon | IVDS proche, instancing loin |
| Corail | IVDS/masked hybrid |

### 21.5. Architecture

| Contenu | Stratégie LOD |
|---|---|
| Mur | IVDS / HLOD block |
| Maison | IVDS proche + HLOD quartier |
| Immeuble | facade clusters + HLOD |
| Tour | silhouette-preserving HLOD |
| Château | hierarchical structure LOD |
| Ruine | IVDS excellent candidate |
| Pont | IVDS + collision/nav stable |
| Escalier | collision precise + mesh LOD |
| Rempart | HLOD + occlusion |
| Temple | ornaments IVDS + proxy distant |
| Ville | World HLOD layers |
| Station futuriste | module HLOD + material bins |
| Base industrielle | instancing + HLOD |
| Village | grouped HLOD + impostor lights |

### 21.6. Props manufacturés

| Contenu | Stratégie LOD |
|---|---|
| Table | classic LOD or IVDS if ornate |
| Chaise | instancing + LOD |
| Lampe | mesh LOD + light LOD |
| Lampadaire | IVDS/instanced |
| Caisse | instanced LOD |
| Baril | instanced LOD |
| Machine | IVDS for rigid parts |
| Véhicule statique | IVDS + fallback collision |
| Arme au sol | high quality close, icon/impostor far |
| Outil | classic LOD |
| Panneau | mesh + texture LOD |
| Clôture | HLOD rows + alpha care |
| Câble | curve LOD |
| Tuyau | spline mesh LOD |
| Rail | spline HLOD |

### 21.7. Monde RPG/systemic

| Contenu | Stratégie LOD |
|---|---|
| Objet mythique | always high priority close |
| Autel | IVDS + interaction anchors |
| Portail magique | geometry + FX specialized |
| Totem | IVDS + material emissive LOD |
| Camp ennemi | HLOD + AI proxy |
| Donjon | portal/cell culling + HLOD |
| Caverne sacrée | cave LOD + lighting proxy |
| Ruine alien | IVDS + unique materials |
| Épave spatiale | IVDS + HLOD macro |
| Artefact animé | rigid IVDS pieces + animation LOD |

### 21.8. Personnages et créatures

| Contenu | Stratégie LOD |
|---|---|
| Joueur | skeletal LOD + equipment IVDS possible |
| PNJ proche | skeletal + animation LOD |
| PNJ foule | impostor/animation bank |
| Animal petit | skeletal LOD |
| Animal grand | skeletal + rigid armor IVDS |
| Insectes | particle/instanced LOD |
| Oiseaux lointains | impostor/point sprites |
| Boss géant | hybrid: skeletal + static armor clusters |
| Robot | rigid segmented IVDS + anim transforms |

### 21.9. FX et atmosphère

| Contenu | Stratégie LOD |
|---|---|
| Fumée | volumetric/particle LOD |
| Feu | particles + light LOD |
| Étincelles | particle count LOD |
| Poussière | screen-space/volumetric LOD |
| Brouillard | volumetric grid LOD |
| Nuages | atmospheric LOD |
| Neige | particle/material accumulation |
| Pluie | screen-space/near particles |
| Hologrammes | separate translucent path |

---

## 22. Règles de variantes LOD

### 22.1. Variantes par classe d’asset

Chaque asset doit déclarer une politique LOD :

```json
{
  "lodPolicy": "VirtualClusteredStatic",
  "minRootQuality": 0.08,
  "screenErrorTarget": 1.0,
  "shadowBias": 1.5,
  "collisionPolicy": "SeparateConvexChain",
  "impostorPolicy": "OctahedralFar",
  "materialLOD": "PBRToBaked",
  "streamingPriority": "Medium"
}
```

### 22.2. Variantes par biome

Une même recette peut produire des LOD différents selon biome :

- désert : moins de foliage, plus de silhouettes rocheuses ;
- jungle : foliage density LOD plus agressif ;
- montagne : falaises high priority ;
- ville : HLOD très important ;
- monde futuriste : beaucoup de matériaux emissive, gérer light LOD ;
- banquise : surfaces réfléchissantes/glace, matériaux plus coûteux ;
- marais : transparence/eau/foliage, overdraw critique.

### 22.3. Variantes par gameplay

- objet interactif : LOD plus haut ;
- objet destructible : fallback fracture/collision ;
- objet pure déco : LOD agressif ;
- objet quête : jamais réduit au point de perdre silhouette ;
- cover combat : collision stable ;
- escalade : anchors stables.

---

## 23. Debug tools indispensables

### 23.1. Visualizations

Créer un panneau `IVDS Debug` avec :

- cluster IDs ;
- LOD selected ;
- screen error heatmap ;
- page residency ;
- missing pages ;
- streaming priority ;
- root fallback active ;
- HLOD active ;
- terrain cracks ;
- overdraw ;
- material bins ;
- occlusion culled ;
- frustum culled ;
- backface culled ;
- collision LOD ;
- anchors gameplay ;
- shadow LOD.

### 23.2. Stats

Par frame :

```text
Visible chunks
Visible instances
Candidate clusters
Visible clusters
Rendered triangles
ICB commands
Pages resident
Pages requested
Pages missing
Geometry memory MB
Texture memory MB
CPU cull ms
GPU cull ms
Render geometry ms
Shading ms
Shadow geometry ms
LOD transitions count
Fallback renders count
```

### 23.3. Tests automatisés

- seed reproducibility test ;
- chunk border crack test ;
- LOD pop screenshot diff ;
- streaming stress test ;
- fast camera flight ;
- low memory mode ;
- M1 baseline test ;
- material bin explosion test ;
- HLOD mismatch test ;
- collision/render mismatch test.

---

## 24. Roadmap d’implémentation

### Phase 0 — Baseline propre

Objectif : avoir un système LOD classique solide.

- `LODPolicy` par asset ;
- LOD distance + screen size ;
- hysteresis ;
- chunk culling CPU ;
- instancing ;
- collision LOD séparée ;
- debug overlay.

Livrables :

- `LODSystem.swift` ;
- `LODPolicy.swift` ;
- `RenderInstanceLOD.swift` ;
- debug view.

### Phase 1 — HLOD et terrain LOD

Objectif : gérer monde large.

- HLOD par chunk ;
- proxy terrain lointain ;
- HLOD props groupés ;
- impostors arbres lointains ;
- terrain quadtree simple ;
- transition chunk/LOD stable.

Livrables :

- `HLODBuilder` ;
- `ChunkProxyMesh` ;
- `TerrainPatchLOD`.

### Phase 2 — Meshlets/clusters

Objectif : petite granularité.

- clusterizer offline ;
- meshlet metadata ;
- bounds/cones ;
- cluster culling compute ;
- compaction visible clusters ;
- indirect draw generation.

Livrables :

- `VirtualClusterBuilder` ;
- `ClusterCulling.metal` ;
- `VisibleClusterBuffer`.

### Phase 3 — Streaming pages géométriques

Objectif : virtual geometry partielle.

- geometry pages ;
- page cache ;
- feedback GPU ;
- root resident geometry ;
- async decompression ;
- missing page fallback.

Livrables :

- `GeometryPageCache` ;
- `GeometryStreamingSystem` ;
- `IVDSAssetPackage`.

### Phase 4 — Mesh shader path

Objectif : chemin moderne Metal.

- capability detection ;
- object shader culling ;
- mesh shader meshlet draw ;
- fallback compute+ICB ;
- comparative profiler.

Livrables :

- `MeshShaderClusterPipeline` ;
- `LegacyClusterPipeline`.

### Phase 5 — Visibility buffer / virtual material

Objectif : scène dense AAA.

- visibility buffer ;
- material resolve compute ;
- virtual texture feedback ;
- shadow LOD avancé ;
- material bins.

Livrables :

- `VisibilityBufferPass` ;
- `MaterialResolvePass` ;
- `VirtualTextureSystem`.

### Phase 6 — Procedural runtime build avancé

Objectif : générer des assets IVDS depuis recettes.

- procedural mesh -> cluster build async ;
- cache par seed/recipe ;
- progressive quality ;
- deterministic local simplification ;
- terrain feature IVDS.

Livrables :

- `ProceduralIVDSBuilder` ;
- `RecipeGeometryCache` ;
- `AsyncBuildQueue`.

---

## 25. Organisation code proposée

```text
EngineCore/
  LOD/
    LODPolicy.swift
    LODSelection.swift
    ScreenError.swift
    Hysteresis.swift
    LODBudget.swift

  VirtualGeometry/
    VirtualGeometryAsset.swift
    VirtualCluster.swift
    GeometryPage.swift
    GeometryPageCache.swift
    VirtualGeometryBuilder.swift
    VirtualGeometryStreaming.swift

  Terrain/
    TerrainPatchLOD.swift
    TerrainClipmap.swift
    TerrainFeatureLOD.swift

  Rendering/
    GPUDriven/
      InstanceCulling.metal
      ClusterCulling.metal
      HiZPyramid.metal
      IndirectCommandBuild.metal
    MeshShaders/
      ClusterObjectShader.metal
      ClusterMeshShader.metal
    Passes/
      DepthPrepass.swift
      VisibilityPass.swift
      OpaqueClusterPass.swift
      HLODPass.swift

  Debug/
    IVDSDebugOverlay.swift
    IVDSStats.swift
    LODVisualizationMode.swift
```

---

## 26. Exemple d’algorithme runtime

### 26.1. Frame loop simplifiée

```text
Frame N
  1. Update camera/player state
  2. Determine active regions/chunks
  3. CPU coarse cull chunks
  4. Upload instance/chunk buffers
  5. Build or reuse depth pyramid
  6. GPU instance culling
  7. GPU cluster/node selection
  8. GPU occlusion culling
  9. GPU compaction visible clusters
 10. GPU writes page feedback
 11. GPU builds indirect command buffers
 12. Render depth/visibility
 13. Render opaque/material resolve
 14. Render foliage specialized
 15. Render translucent/FX
 16. CPU consumes delayed page feedback
 17. Stream/decompress next pages
 18. Update debug stats
```

### 26.2. LOD decision pseudo-code

```swift
func shouldUseChild(node: ClusterNode, camera: Camera, policy: LODPolicy) -> Bool {
    let distance = max(0.001, distance(camera.position, node.bounds.center))
    let projectedError = node.error * camera.projectionScale / distance
    let priorityBoost = policy.gameplayPriorityBoost
    let adjustedThreshold = policy.screenErrorThreshold / priorityBoost
    return projectedError > adjustedThreshold
}
```

### 26.3. Budget arbitration pseudo-code

```swift
for candidate in visibleCandidates.sorted(by: priority) {
    if budget.canAccept(candidate) {
        budget.accept(candidate)
        output.append(candidate)
    } else {
        output.append(candidate.fallbackParent)
    }
}
```

---

## 27. Décisions clés pour IsoWorld

### 27.1. Ne pas faire un seul système LOD

Il faut un **orchestrateur LOD**, pas un seul algorithme.

```text
LODOrchestrator
  -> TerrainLODSystem
  -> VirtualGeometrySystem
  -> FoliageLODSystem
  -> CharacterLODSystem
  -> FXLODSystem
  -> HLODSystem
```

### 27.2. Tout asset doit déclarer sa politique

Pas de comportement implicite incontrôlable.

### 27.3. Gameplay > rendu

Les collisions, anchors de grimpe, navmesh, raycasts et interactions doivent être stables même quand le rendu change de LOD.

### 27.4. Streaming progressif

Toujours afficher quelque chose. Jamais de trou.

### 27.5. Debug avant sophistication

Un système Nanite-like sans visualizer devient impossible à maintenir.

---

## 28. Scalability tiers

### Tier 0 — Low / debug

- LOD classique ;
- HLOD agressif ;
- pas de virtual geometry détaillée ;
- peu de shadow casters ;
- foliage density réduite.

### Tier 1 — M1 target

- cluster culling compute ;
- ICB/indirect rendering si disponible ;
- terrain quadtree ;
- HLOD chunks ;
- geometry page cache modéré ;
- foliage impostor fort.

### Tier 2 — M2/M3/M4+

- mesh shaders si disponibles ;
- plus de clusters visibles ;
- meilleure virtual texture ;
- terrain plus détaillé ;
- shadow LOD plus fin ;
- visibility buffer expérimental.

### Tier 3 — Ultra / future

- virtual geometry avancée ;
- page streaming agressif ;
- virtual shadow maps ;
- material resolve compute ;
- dense procedural worlds ;
- éventuellement path/ray features.

---

## 29. Pièges à éviter

### 29.1. Faire du Nanite-like trop tôt

Il faut d’abord :

- bons buffers ;
- bonnes stats ;
- bon culling ;
- bon HLOD ;
- bonnes collisions.

### 29.2. Coupler LOD et gameplay

Erreur grave : changer le mesh de collision selon le rendu sans stabilité.

### 29.3. Ignorer foliage/transparency

La géométrie opaque peut être parfaite, mais le jeu peut rester lent à cause du feuillage alpha.

### 29.4. Ne pas contrôler la taille disque

La virtual geometry peut exploser le stockage si toutes les variantes procédurales sont cachées sans règles.

### 29.5. Matériaux trop complexes

Réduire les triangles ne suffit pas si le shader coûte trop cher.

### 29.6. Pas de fallback

Il faut toujours :

- fallback mesh ;
- fallback collision ;
- fallback material ;
- fallback platform ;
- fallback no-page.

---

## 30. Checklist de design

Pour chaque asset/terrain feature :

- [ ] source haute qualité disponible ?
- [ ] ID déterministe ?
- [ ] LOD policy définie ?
- [ ] collision LOD séparée ?
- [ ] gameplay anchors séparés ?
- [ ] clusterization possible ?
- [ ] HLOD possible ?
- [ ] impostor nécessaire ?
- [ ] material LOD défini ?
- [ ] shadow LOD défini ?
- [ ] root mesh always resident ?
- [ ] pages streamables ?
- [ ] debug metadata ?
- [ ] budget mémoire ?
- [ ] test de transition ?
- [ ] test chunk border ?

---

## 31. Recommandation finale

Le système LOD d’IsoWorld devrait être construit comme une **infrastructure de virtualisation du détail**, pas comme une liste de distances. La meilleure stratégie est progressive :

1. faire un LOD classique propre ;
2. ajouter HLOD par chunk et terrain LOD ;
3. introduire les meshlets/clusters ;
4. passer au culling GPU + indirect command buffers ;
5. ajouter streaming de pages géométriques ;
6. ajouter mesh shaders Metal quand disponibles ;
7. coupler avec virtual textures ;
8. ajouter visibility buffer si le rendu devient très dense ;
9. garder des pipelines spécialisés pour foliage, personnages, eau et FX.

La version IsoWorld ne doit pas être “Nanite clone”. Elle doit être :

```text
Nanite-inspired + chunk-aware + procedural-aware + gameplay-aware + Metal-friendly
```

C’est cette combinaison qui rendra le système vraiment versatile pour un monde procédural déterministe.

---

## 32. Sources et références consultées

### Nanite / Unreal Engine

- Epic Games — Nanite Virtualized Geometry in Unreal Engine 5.7 Documentation  
  https://dev.epicgames.com/documentation/unreal-engine/nanite-virtualized-geometry-in-unreal-engine

- Epic Games — Nanite Technical Details  
  https://dev.epicgames.com/documentation/unreal-engine/nanite-technical-details

- Brian Karis / Epic Games — A Deep Dive into Nanite Virtualized Geometry, SIGGRAPH 2021 Advances in Real-Time Rendering  
  https://advances.realtimerendering.com/s2021/Karis_Nanite_SIGGRAPH_Advances_2021_final.pdf

- Brian Karis — Journey to Nanite, High Performance Graphics 2022  
  https://www.highperformancegraphics.org/slides22/Journey_to_Nanite.pdf

### GPU-driven rendering / mesh clusters

- Aaltonen, Haar — GPU-Driven Rendering Pipelines, SIGGRAPH 2015 Advances in Real-Time Rendering  
  https://advances.realtimerendering.com/s2015/aaltonenhaar_siggraph2015_combined_final_footer_220dpi.pdf

- meshoptimizer — Mesh optimization library, meshlets, cluster culling, simplification  
  https://meshoptimizer.org/

- NVIDIA — Introduction to Turing Mesh Shaders  
  https://developer.nvidia.com/blog/introduction-turing-mesh-shaders/

### Metal / Apple Silicon

- Apple — Transform your geometry with Metal mesh shaders, WWDC22  
  https://developer.apple.com/videos/play/wwdc2022/10162/

- Apple — Adjusting the level of detail using Metal mesh shaders  
  https://developer.apple.com/documentation/Metal/adjusting-the-level-of-detail-using-Metal-mesh-shaders

- Apple — Encoding indirect command buffers on the GPU  
  https://developer.apple.com/documentation/Metal/encoding-indirect-command-buffers-on-the-gpu

- Apple — Modern rendering with Metal  
  https://developer.apple.com/documentation/Metal/modern-rendering-with-metal

- Apple — Streaming large images with Metal sparse textures  
  https://developer.apple.com/documentation/Metal/streaming-large-images-with-metal-sparse-textures

- Apple — Metal Feature Set Tables  
  https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf

### HLOD / LOD tools

- Epic Games — World Partition HLOD  
  https://dev.epicgames.com/documentation/unreal-engine/world-partition---hierarchical-level-of-detail-in-unreal-engine

- Epic Games — Static Mesh Automatic LOD Generation  
  https://dev.epicgames.com/documentation/unreal-engine/static-mesh-automatic-lod-generation-in-unreal-engine

- Simplygon — HLOD / LOD Recipes / Impostors  
  https://documentation.simplygon.com/

### Recherches complémentaires

- Appearance-Driven Automatic 3D Model Simplification  
  https://arxiv.org/abs/2104.03989

- Performance Comparison of Meshlet Generation Strategies  
  https://jcgt.org/published/0012/02/01/

- Virtualized 3D Gaussians: Flexible Cluster-based LOD System  
  https://arxiv.org/abs/2505.06523

---

## 33. Glossaire

**Cluster** : groupe local de triangles rendu/cullé comme unité.

**Meshlet** : petit cluster optimisé pour GPU, souvent borné en vertices/triangles.

**HLOD** : Hierarchical Level of Detail, proxy d’un groupe d’objets ou d’une zone.

**IVDS** : IsoWorld Virtual Detail System, proposition de système LOD/virtual geometry pour IsoWorld.

**Screen-space error** : erreur projetée à l’écran, en pixels ou unité comparable.

**Root geometry** : représentation grossière toujours résidente pour éviter les trous.

**Page géométrique** : bloc compressé de données géométriques streamable.

**ICB** : Indirect Command Buffer, commandes de rendu préparées/réutilisées ou générées indirectement.

**Hi-Z** : pyramide hiérarchique de profondeur pour tests d’occlusion rapides.

**Visibility buffer** : buffer stockant IDs de primitives/matériaux au lieu d’un G-buffer complet.

**Impostor** : représentation image/atlas/depth/normal d’un objet distant.

**Material LOD** : réduction de complexité shader/texture selon distance/budget.

