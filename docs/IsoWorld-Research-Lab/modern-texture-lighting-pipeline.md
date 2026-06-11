# Point 9 — Pipeline moderne pour les textures et les lumières, sans ray tracing / path tracing

Document de référence pour **IsoWorld** — moteur procédural custom en **Swift/Metal** sur Apple Silicon.

Objectif : définir un système **ultra pensé, moderne, versatile et scalable** pour produire un rendu haute qualité avec des textures, matériaux et lumières crédibles, tout en restant réaliste pour un moteur procédural chunké, déterministe, sans ray tracing ni path tracing dans un premier temps.

---

## 0. Résumé exécutif

Pour IsoWorld, le pipeline texture/lumière ne doit pas être une simple collection de shaders PBR. Il doit devenir un **système unifié de surface, environnement, météo, biomes, streaming et éclairage**. Le monde étant généré dynamiquement autour du joueur, chaque chunk doit pouvoir produire :

- ses matériaux terrain ;
- ses variations de biome ;
- ses textures virtuelles ou sparse ;
- ses light probes locales ;
- ses volumes de brouillard ;
- ses paramètres météo ;
- ses ombres dynamiques ;
- ses états de surface : sec, humide, enneigé, brûlé, poussiéreux, boueux, gelé, contaminé, etc.

Le système recommandé n’est pas “tout temps réel dynamique” ni “tout précalculé”. Le bon compromis est un pipeline hybride :

1. **PBR temps réel strict et cohérent** pour tous les matériaux.
2. **Material Graph interne** pour authoring procédural, layering et variations.
3. **Material Runtime compact** pour éviter de payer le coût d’un graphe complet par pixel.
4. **Virtual / sparse textures** pour gérer les grands terrains, les biomes et les matériaux haute résolution.
5. **Forward+ ou clustered deferred lighting** selon le type de passe.
6. **IBL + probe volumes + lightmaps/probes chunkées** pour l’indirect sans ray tracing.
7. **Cascaded shadow maps + local shadow atlases** pour les ombres.
8. **GTAO / bent normals / screen-space effects** pour renforcer les contacts et l’occlusion.
9. **Weather surface modifiers** pour pluie, neige, boue, gel, sable, poussière.
10. **Debug tooling fort** pour visualiser albedo, roughness, normal, AO, light clusters, probes, overdraw, texture residency, mip bias.

Le principe architectural central :

> Les matériaux ne sont pas seulement des textures. Ce sont des surfaces vivantes, modifiées par le monde.

---

## 1. Contraintes IsoWorld

### 1.1 Contraintes moteur

IsoWorld vise un monde procédural déterministe, généré autour du joueur par chunks. Le pipeline texture/lumière doit donc fonctionner avec :

- des chunks créés et détruits dynamiquement ;
- des assets procéduraux et paramétriques ;
- des biomes très variés ;
- des terrains verticaux ;
- des props générés ;
- des règles météo et saison ;
- des matériaux dépendants du seed ;
- un renderer Metal sur MacBook Pro M1 ;
- un budget CPU limité ;
- un GPU Apple tile-based très performant si l’on organise bien les passes.

### 1.2 Contraintes artistiques

Le pipeline doit permettre :

- rendu terrain haute qualité ;
- roches crédibles ;
- végétation riche ;
- eau/lacs/rivières/mer sans path tracing ;
- métal, bois, verre approximé, tissus, peau, boue, neige, glace ;
- props manufacturés ;
- époques RPG très différentes ;
- rendu stylisé ou réaliste selon le `WorldRenderDNA` ;
- variations massives sans explosion mémoire.

### 1.3 Contraintes de non-raytracing

Sans ray tracing/path tracing, il faut compenser avec :

- PBR très propre ;
- bonnes normal maps ;
- IBL préfiltré ;
- probes ;
- screen-space reflections ;
- screen-space ambient occlusion ;
- shadow maps stables ;
- fake GI contrôlée ;
- volumes de lumière ;
- decals et détails de surface ;
- temporal accumulation ;
- art direction rigoureuse.

Le rendu ne sera pas physiquement parfait, mais il peut être **cohérent, stable, performant et très beau**.

---

## 2. Recherche industrie — ce qu’il faut retenir

### 2.1 PBR comme fondation

Les moteurs modernes convergent autour du rendu physiquement basé : albedo/base color, metallic, roughness, normal, emissive, occlusion, transmission ou clearcoat selon les besoins. Le pipeline Frostbite a été l’un des grands exemples industriels de transition vers un PBR cohérent sur toute la production. Filament fournit également une documentation très claire sur un renderer PBR temps réel, image-based lighting et choix de modèles efficaces.

Références utiles :

- [Moving Frostbite to Physically Based Rendering](https://seblagarde.wordpress.com/2015/07/14/siggraph-2014-moving-frostbite-to-physically-based-rendering/)
- [Course notes Frostbite PBR](https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf)
- [Physically Based Rendering in Filament](https://google.github.io/filament/Filament.md.html)

### 2.2 Matériaux standards : glTF, USD, MaterialX, OpenPBR

Un moteur custom ne doit pas réinventer toute la représentation artistique. Il doit avoir un format interne, mais compatible avec les standards :

- **glTF 2.0 metallic-roughness** comme format runtime simple ;
- **USD Preview Surface** pour échange DCC / pipeline ;
- **MaterialX** pour les graphes de lookdev ;
- **OpenPBR Surface** comme inspiration pour un modèle de surface plus large à long terme.

Références :

- [glTF 2.0 Specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
- [UsdPreviewSurface Specification](https://openusd.org/release/spec_usdpreviewsurface.html)
- [MaterialX](https://materialx.org/)
- [MaterialX Specification](https://github.com/AcademySoftwareFoundation/MaterialX/blob/main/documents/Specification/MaterialX.Specification.md)
- [OpenPBR Surface](https://academysoftwarefoundation.github.io/OpenPBR/)

### 2.3 Authoring procédural : Substance, Houdini, MaterialX

Pour IsoWorld, les textures doivent souvent être générées ou modulées par règles. Les pipelines modernes utilisent des graphes node-based : Substance Designer pour les matériaux procéduraux, Houdini pour les assets/procédures, MaterialX pour la représentation portable de graphes matériaux.

À retenir :

- les graphes artistiques peuvent être complexes ;
- le runtime ne doit pas exécuter tous les graphes complets par pixel ;
- on doit compiler/baker les graphes en textures, lookup tables, paramètres et petites fonctions shader ;
- les variations doivent être paramétriques et seedées.

Références :

- [Adobe Substance 3D Designer User Guide](https://experienceleague.adobe.com/en/docs/substance-3d-designer/using/home)
- [Adobe PBR Guide Part 1](https://www.adobe.com/learn/substance-3d-designer/web/the-pbr-guide-part-1)
- [Adobe PBR Guide Part 2](https://www.adobe.com/learn/substance-3d-designer/web/the-pbr-guide-part-2)

### 2.4 Virtual texturing et sparse textures

Pour un monde procédural vaste, les textures classiques mip-streamées par asset ne suffisent pas toujours. Les solutions modernes utilisent :

- streaming de mipmaps ;
- virtual texturing ;
- runtime virtual textures ;
- sparse textures ;
- caches de pages ;
- page tables ;
- feedback GPU ;
- atlases de matériaux.

Unreal propose Streaming Virtual Texturing et Runtime Virtual Texturing. Metal expose les sparse textures : les shaders peuvent sampler la texture comme une texture normale, mais les régions non mappées retournent zéro ou ignorent les écritures. C’est particulièrement utile pour un monde chunké où seules les zones proches ont besoin de pages haute résolution.

Références :

- [Unreal Streaming Virtual Texturing](https://dev.epicgames.com/documentation/unreal-engine/streaming-virtual-texturing-in-unreal-engine)
- [Unreal Runtime Virtual Texturing](https://dev.epicgames.com/documentation/unreal-engine/runtime-virtual-texturing-in-unreal-engine)
- [Metal sparse textures](https://developer.apple.com/documentation/metal/reading-and-writing-to-sparse-textures)

### 2.5 Lighting moderne sans ray tracing

Sans RT, les moteurs utilisent un mix :

- forward+ ;
- tiled deferred ;
- clustered shading ;
- shadow maps ;
- light probes ;
- volumetric lightmaps ;
- baked lightmaps ;
- IBL ;
- reflection probes ;
- screen-space reflections ;
- ambient occlusion ;
- fog volumétrique.

Apple fournit notamment des samples Metal pour forward+ avec tile shaders, deferred lighting, modern rendering avec ICB, sparse textures, VRS, tile-based deferred lighting, AO, volumetric fog et cascaded shadow maps.

Références :

- [Apple Metal Sample Code](https://developer.apple.com/metal/sample-code/)
- [Rendering a scene with Forward Plus lighting using tile shaders](https://developer.apple.com/documentation/Metal/rendering-a-scene-with-forward-plus-lighting-using-tile-shaders)
- [Apple argument buffers](https://developer.apple.com/documentation/metal/improving-cpu-performance-by-using-argument-buffers)

### 2.6 Probe volumes et indirect lighting

Unreal Volumetric Lightmaps stocke de l’éclairage indirect précalculé dans des points 3D interpolés à runtime pour les objets dynamiques. Unity HDRP Adaptive Probe Volumes place automatiquement des probes selon la densité géométrique afin de créer de l’indirect baked. Pour IsoWorld, l’idée à retenir n’est pas de copier l’éditeur, mais de générer des volumes de probes par chunk ou par zone, avec streaming.

Références :

- [Unreal Volumetric Lightmaps](https://dev.epicgames.com/documentation/unreal-engine/volumetric-lightmaps-in-unreal-engine)
- [Unreal Global Illumination](https://dev.epicgames.com/documentation/unreal-engine/global-illumination-in-unreal-engine)
- [Unity Adaptive Probe Volumes](https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition%4017.0/manual/probevolumes-concept.html)

### 2.7 AO moderne : GTAO / GTSO

L’occlusion ambiante reste essentielle sans RT. Le GTAO d’Activision vise une occlusion écran plus physiquement fondée que des SSAO plus empiriques et inclut aussi une approximation de specular occlusion sous probe lighting. Cela correspond très bien à IsoWorld : améliorer les contacts terrain/props/personnages sans payer de ray tracing.

Références :

- [Practical Real-Time Strategies for Accurate Indirect Occlusion](https://research.activision.com/publications/archives/practical-real-time-strategies-for-accurate-indirect-occlusion)
- [GTAO paper PDF](https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf)
- [XeGTAO implementation](https://github.com/GameTechDev/XeGTAO)

---

## 3. Proposition globale : IsoWorld Surface & Lighting Pipeline

Nom proposé : **ISLP — IsoWorld Surface & Lighting Pipeline**.

ISLP regroupe :

- `IsoMaterialGraph` : représentation authoring ;
- `IsoMaterialRecipe` : recette procédurale déterministe ;
- `IsoMaterialRuntime` : version compacte pour GPU ;
- `IsoTextureStreamingSystem` : textures, mips, pages, sparse textures ;
- `IsoSurfaceStateSystem` : pluie, neige, boue, poussière, usure ;
- `IsoLightingSystem` : lumières directes, clusters, ombres ;
- `IsoProbeSystem` : probes d’irradiance/reflection ;
- `IsoAtmosphereSystem` : ciel, soleil, lune, brouillard ;
- `IsoPostProcessSystem` : tonemapping, color grading, bloom, TAA, sharpening ;
- `IsoDebugViewSystem` : vues de validation.

### 3.1 Pipeline haut niveau

```text
World Seed
  -> WorldRenderDNA
  -> Biome/Climate/Weather/TimeOfDay
  -> Chunk Surface Inputs
  -> Material Selection + Layer Blending
  -> Texture Residency / Virtual Pages
  -> GBuffer ou Forward Material Pass
  -> Lighting Passes
  -> Shadows / AO / Probes / IBL
  -> Transparent / Water / Particles
  -> Atmosphere / Fog
  -> Post-Process
  -> Final HDR Output
```

### 3.2 Philosophie

Le moteur doit éviter deux extrêmes :

- **Extrême 1 : tout est un matériau unique énorme**. Cela devient impossible à maintenir.
- **Extrême 2 : chaque asset a son shader spécifique**. Cela casse le batching et la cohérence.

La bonne solution :

- peu de familles de shaders robustes ;
- beaucoup de données paramétriques ;
- graphes compilés ;
- material instances ;
- layering contrôlé ;
- variantes seedées ;
- états de surface mondiaux.

---

## 4. WorldRenderDNA

Comme les autres systèmes IsoWorld, le rendu doit être influencé par une ADN déterministe.

### 4.1 Exemple de structure

```swift
struct WorldRenderDNA: Codable, Sendable {
    var pbrProfile: PBRProfile
    var colorStyle: ColorStyle
    var contrastCurve: ContrastCurve
    var materialComplexity: MaterialComplexity
    var textureDensityScale: Float
    var weatherSurfaceIntensity: Float
    var biomeMaterialMutation: Float
    var lightTemperatureBias: Float
    var fogDensityBias: Float
    var shadowSoftnessBias: Float
    var wetnessModel: WetnessModel
    var snowModel: SnowModel
    var dustModel: DustModel
    var worldAgeVisualBias: WorldAgeVisualBias
}
```

### 4.2 Ce que le seed peut modifier

Le seed peut changer :

- la palette globale ;
- la couleur du ciel ;
- la température du soleil ;
- l’intensité du fog ;
- l’apparence des roches ;
- les familles de matériaux dominantes ;
- les sols plus ou moins saturés ;
- l’abondance de mousse ;
- la fréquence des surfaces humides ;
- la rugosité moyenne des matériaux ;
- la granularité des textures ;
- le style d’usure ;
- la propreté du monde ;
- les teintes de végétation ;
- les variations de neige/glace ;
- l’aspect technologique ou archaïque ;
- la luminosité nocturne ;
- la couleur des brumes ;
- le niveau de réalisme/stylisation.

### 4.3 Important : rester physiquement plausible

Même si le seed modifie l’art direction, il faut conserver des contraintes :

- albedo dans des plages réalistes ;
- roughness non aberrante ;
- metallic binaire ou très contrôlé ;
- conservation d’énergie ;
- normals cohérentes ;
- pas de lumière bakée dans l’albedo ;
- pas de contraste excessif dans base color ;
- pas de specular inventé hors modèle.

---

## 5. Modèle matériau IsoWorld

### 5.1 Modèle de base recommandé

Pour le premier pipeline AAA-like mais raisonnable :

```text
BaseColor RGB
Metallic
Roughness
Normal
AmbientOcclusion
Height / DisplacementScalar
Emissive RGB
Opacity / Alpha
Subsurface / Translucency optional
Clearcoat optional
Anisotropy optional
```

### 5.2 Matériaux runtime standards

Créer un ensemble limité de `MaterialModels` :

1. `OpaquePBR`
2. `MaskedPBR`
3. `FoliagePBR`
4. `TerrainLayeredPBR`
5. `WaterSurface`
6. `GlassApprox`
7. `SkinApprox`
8. `HairFurApprox`
9. `ClothPBR`
10. `EmissivePBR`
11. `DecalPBR`
12. `ParticleLit`
13. `ParticleUnlit`
14. `SkyAtmosphere`
15. `VolumetricFog`

### 5.3 Pourquoi limiter les modèles ?

Limiter les modèles permet :

- moins de pipelines Metal ;
- meilleur batching ;
- shader permutation control ;
- performances prévisibles ;
- validation plus simple ;
- debug plus clair.

Les variations passent par les données, pas par mille shaders.

### 5.4 IsoMaterialRuntime

```swift
struct IsoMaterialRuntime: Sendable {
    var materialID: UInt32
    var model: MaterialModel
    var textureSetID: UInt32
    var parameterBlockOffset: UInt32
    var flags: MaterialFlags
    var layerCount: UInt8
    var surfaceStateMask: UInt32
}
```

### 5.5 Parameter block compact

```metal
struct MaterialParams {
    float4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
    float normalStrength;
    float aoStrength;
    float heightScale;
    float wetnessResponse;
    float snowResponse;
    float dustResponse;
    float mossResponse;
    float edgeWearResponse;
    float emissiveStrength;
    uint textureFlags;
    uint materialClass;
};
```

---

## 6. Material Graph authoring

### 6.1 Rôle

`IsoMaterialGraph` sert à authorer les matériaux, mais il ne doit pas forcément être exécuté tel quel au runtime.

Il peut contenir :

- bruits procéduraux ;
- blends ;
- height blends ;
- masks ;
- weather responses ;
- biome variations ;
- color ramps ;
- triplanar mapping ;
- decals intégrés ;
- micro details ;
- wetness layers ;
- snow accumulation ;
- moss accumulation ;
- wear/damage layers.

### 6.2 Trois chemins d’exécution

Chaque graph peut être compilé vers :

1. **Bake offline** : génération de textures PBR classiques.
2. **Bake chunk-time** : calcul CPU/GPU à la génération du chunk.
3. **Runtime shader** : uniquement pour les parties dynamiques légères.

### 6.3 Exemple de graph roche

```text
RockMaterialGraph
  Inputs:
    geologicalFamily
    altitude
    humidity
    slope
    biome
    worldAge
    seed
  Nodes:
    stratificationNoise
    crackMask
    mineralVeins
    lichenMask
    wetnessMask
    edgeDirtMask
  Outputs:
    baseColor
    roughness
    normal
    height
    AO
```

### 6.4 Compilation

Le compilateur doit produire :

- textures bakées ;
- paramètres runtime ;
- fonctions shader spécialisées ;
- metadata de qualité ;
- debug thumbnails ;
- min/max roughness ;
- albedo average ;
- tiling scale ;
- physical size ;
- biome compatibility.

---

## 7. Taxonomie de matériaux

### 7.1 Sols naturels

- terre sèche ;
- terre humide ;
- terre compacte ;
- terre craquelée ;
- terre argileuse ;
- terre noire fertile ;
- terre volcanique ;
- terre rouge ferrugineuse ;
- limon ;
- sédiment de rivière ;
- tourbe ;
- boue épaisse ;
- boue liquide ;
- boue gelée ;
- sol sableux ;
- sol caillouteux ;
- sol forestier ;
- humus ;
- tapis de feuilles mortes ;
- racines affleurantes ;
- mousse humide ;
- mousse sèche ;
- lichen ;
- algues de rive ;
- sel cristallisé ;
- cendre ;
- poussière fine ;
- poussière ocre ;
- sol brûlé ;
- sol contaminé ;
- sol magique/fantastique ;
- sol radioactif stylisé ;
- mycélium ;
- sol spongieux ;
- sol marécageux ;
- sol gelé ;
- permafrost ;
- neige fraîche ;
- neige tassée ;
- neige sale ;
- glace lisse ;
- glace fissurée ;
- givre ;
- verglas.

### 7.2 Roches

- granite ;
- basalte ;
- calcaire ;
- grès ;
- schiste ;
- ardoise ;
- marbre ;
- quartzite ;
- obsidienne ;
- pierre ponce ;
- roche volcanique rouge ;
- roche volcanique noire ;
- roche stratifiée ;
- roche fracturée ;
- roche polie par l’eau ;
- roche érodée par le vent ;
- roche couverte de lichen ;
- roche humide ;
- roche enneigée ;
- roche salée ;
- roche cristalline ;
- roche métallique ;
- minerai apparent ;
- veines minérales ;
- stalactite ;
- stalagmite ;
- roche corallienne ;
- falaise sèche ;
- falaise humide ;
- falaise glacée ;
- falaise sableuse ;
- falaise friable.

### 7.3 Végétation

- feuille large ;
- feuille fine ;
- aiguille de conifère ;
- herbe courte ;
- herbe haute ;
- roseau ;
- fougère ;
- mousse ;
- lichen ;
- écorce rugueuse ;
- écorce lisse ;
- écorce craquelée ;
- écorce humide ;
- bois vivant ;
- bois mort ;
- bois brûlé ;
- racine ;
- champignon mat ;
- champignon humide ;
- pétale translucide ;
- fruit cireux ;
- fruit pourri ;
- algue ;
- corail ;
- végétation alien ;
- plante bioluminescente ;
- plante cristallisée.

### 7.4 Eau et liquides

- eau claire ;
- eau trouble ;
- eau boueuse ;
- eau glacée ;
- eau tropicale ;
- eau sombre ;
- rivière rapide ;
- lac calme ;
- mer agitée ;
- flaque ;
- mousse de vague ;
- écume ;
- vase liquide ;
- huile ;
- lave stylisée ;
- acide fictif ;
- liquide magique ;
- liquide industriel ;
- gel translucide.

### 7.5 Matériaux manufacturés

- bois brut ;
- bois verni ;
- bois peint ;
- bois usé ;
- bois humide ;
- bois brûlé ;
- métal ferreux ;
- acier poli ;
- acier rouillé ;
- cuivre ;
- cuivre oxydé ;
- bronze ;
- laiton ;
- aluminium ;
- chrome ;
- métal peint ;
- métal écaillé ;
- plastique mat ;
- plastique brillant ;
- caoutchouc ;
- tissu coton ;
- laine ;
- cuir ;
- cuir usé ;
- céramique ;
- porcelaine ;
- verre approximé ;
- verre sale ;
- béton ;
- béton fissuré ;
- brique ;
- tuile ;
- goudron ;
- asphalte ;
- peinture murale ;
- néon ;
- écran emissive ;
- fibre futuriste ;
- composite carbone ;
- matériau alien.

### 7.6 Matériaux d’époque RPG

- pierre taillée antique ;
- marbre sacré ;
- bois médiéval ;
- fer forgé ;
- cuir médiéval ;
- tissu grossier ;
- os poli ;
- ivoire fictif ;
- cristal magique ;
- runes emissives ;
- métal enchanté ;
- béton moderne ;
- verre industriel ;
- acier urbain ;
- plastique futuriste ;
- polymère spatial ;
- céramique high-tech ;
- bio-matériau vivant ;
- nano-surface ;
- matériau post-apocalyptique recyclé.

---

## 8. Textures : organisation des données

### 8.1 TextureSet standard

```swift
struct TextureSetDescriptor: Codable, Sendable {
    var id: TextureSetID
    var baseColor: TextureRef?
    var normal: TextureRef?
    var orm: TextureRef?        // occlusion, roughness, metallic
    var height: TextureRef?
    var emissive: TextureRef?
    var detailNormal: TextureRef?
    var masks: TextureRef?
    var physicalSizeMeters: SIMD2<Float>
    var preferredMipBias: Float
    var compressionProfile: TextureCompressionProfile
}
```

### 8.2 Packing recommandé

Pour limiter la bande passante :

```text
BaseColor:       RGB/A, sRGB
Normal:          BC5/ASTC two-channel ou RG normal
ORM:             R=AO, G=Roughness, B=Metallic
Height:          R8/R16 selon besoin
Masks:           R=wetness, G=snow, B=dirt, A=moss ou custom
Emissive:        RGB si nécessaire seulement
```

### 8.3 Attention color space

- base color et emissive authoring en sRGB ;
- normal, roughness, metallic, AO, height en linéaire ;
- lighting en HDR linéaire ;
- tonemapping à la fin ;
- color grading après tonemapping ou dans pipeline HDR selon choix.

### 8.4 Densité texel

Définir une unité :

```text
Default terrain:     512 px/m à proximité, descente mip rapide
Hero props:          1024 px/m ou plus localement
Large props:         256–512 px/m
Background props:    64–128 px/m
Micro detail:        overlay procédural à haute fréquence
```

Le moteur doit debugger la densité texel visuellement.

---

## 9. Streaming textures

### 9.1 Niveaux de maturité

#### Niveau 0 — simple

- textures chargées par asset ;
- mipmaps ;
- LRU cache ;
- unload par distance.

#### Niveau 1 — streaming par chunk

- chaque chunk déclare ses matériaux ;
- préchargement autour du joueur ;
- budget mémoire ;
- fallback texture basse résolution.

#### Niveau 2 — virtual texturing partiel

- grandes textures terrain paginées ;
- page table ;
- feedback GPU ;
- sparse textures Metal ;
- cache de pages.

#### Niveau 3 — runtime virtual textures

- le terrain et les decals écrivent dans une texture virtuelle locale ;
- les props/foliage samplent la couleur/normal/roughness du sol ;
- traces, boue, neige, routes et chemins peuvent se mélanger naturellement.

### 9.2 IsoVirtualTextureSystem

```swift
final class IsoVirtualTextureSystem {
    func registerVirtualTexture(_ descriptor: VirtualTextureDescriptor) -> VirtualTextureHandle
    func requestPage(_ page: VTPageID, priority: Float)
    func updateResidency(camera: CameraState, visibleChunks: [ChunkID])
    func encodePageUploads(commandBuffer: MTLCommandBuffer)
    func bindMaterialPages(argumentBuffer: MTLBuffer)
}
```

### 9.3 Page priority

Priorité d’une page :

```text
priority = visibility * screenSize * materialImportance * cameraVelocityCompensation * gameplayImportance
```

Exemples :

- sol sous le joueur : priorité maximale ;
- falaise devant le joueur : élevée ;
- arrière-plan montagne : basse ;
- prop interactif : élevée ;
- asset décoratif lointain : basse.

### 9.4 Feedback GPU

À terme :

1. Pass feedback écrit les pages nécessaires.
2. CPU lit un buffer compacté avec latence de 1–2 frames.
3. Streaming charge pages manquantes.
4. Shaders utilisent fallback mip jusqu’à disponibilité.

---

## 10. Terrain materials

Le terrain est le cas le plus critique.

### 10.1 TerrainLayeredPBR

Un chunk terrain doit pouvoir mélanger :

- roche ;
- terre ;
- herbe ;
- sable ;
- neige ;
- glace ;
- boue ;
- mousse ;
- gravier ;
- végétation basse ;
- eau de surface ;
- decals de gameplay.

### 10.2 Inputs de terrain

```text
height
slope
curvature
altitude
humidity
temperature
biomeWeight[]
geologyID
soilType
waterDistance
riverFlow
snowAmount
sunExposure
windExposure
footTraffic
```

### 10.3 Règles de blending

- **slope blend** : roche sur pentes fortes ;
- **height blend** : neige en altitude ;
- **humidity blend** : mousse/boue près de l’eau ;
- **curvature blend** : accumulation dans creux ;
- **exposure blend** : poussière sur zones exposées ;
- **biome blend** : transition herbe/sable/tourbe ;
- **flow blend** : sédiments dans lits de rivière ;
- **gameplay blend** : traces de pas, roues, campement.

### 10.4 Height-based material blending

Pour éviter les transitions molles :

```text
weightA = biomeWeightA * heightMaskA
weightB = biomeWeightB * heightMaskB
normalized = weights / sum(weights)
```

Les height maps guident les matériaux : les cailloux restent au-dessus de la boue, la neige remplit les creux, l’eau s’accumule naturellement.

### 10.5 Triplanar mapping

Indispensable pour :

- falaises verticales ;
- grottes ;
- rochers ;
- structures sans UV propres ;
- terrains SDF/meshes procéduraux.

Optimisations :

- triplanar uniquement proche caméra ;
- version simplifiée pour mid/far ;
- poids dérivés de la normale ;
- detail normal séparé.

### 10.6 Macro/micro variation

Chaque matériau terrain a :

- macro color noise ;
- macro roughness variation ;
- micro normal ;
- detail albedo ;
- biome tint ;
- weather overlay ;
- distance fade.

### 10.7 Terrain material recipe

```swift
struct TerrainMaterialRecipe: Codable, Sendable {
    var geologyFamily: GeologyFamily
    var soilFamily: SoilFamily
    var biomeFamily: BiomeFamily
    var layerRules: [TerrainLayerRule]
    var macroVariationSeed: UInt64
    var weatherResponses: WeatherSurfaceResponse
    var runtimeVirtualTexturePolicy: RVTPolicy
}
```

---

## 11. Surface state system

Un rendu moderne doit gérer l’état dynamique des surfaces.

### 11.1 États possibles

- dry ;
- wet ;
- soaked ;
- muddy ;
- dusty ;
- sandy ;
- snowy ;
- icy ;
- frosted ;
- burned ;
- charred ;
- mossy ;
- lichen-covered ;
- blood-stained selon rating ;
- oil-covered ;
- magical-corrupted ;
- radioactive stylisé ;
- ash-covered ;
- pollen-covered ;
- salt-crusted ;
- algae-covered ;
- cracked ;
- eroded ;
- polished ;
- worn ;
- scratched ;
- dented.

### 11.2 Wetness

Effets de surface humide :

- base color plus sombre ;
- roughness plus faible ;
- specular plus fort ;
- normal atténuée par film d’eau ;
- flaques dans creux ;
- reflets SSR localisés ;
- bruit animé pour gouttes ;
- transition temporelle.

```metal
float wet = saturate(surfaceWetness * material.wetnessResponse);
baseColor = mix(baseColor, baseColor * 0.55, wet);
roughness = mix(roughness, min(roughness, 0.08), wet);
normal = normalize(mix(normal, flattenNormal(normal), wet * 0.35));
```

### 11.3 Snow accumulation

Inputs :

- normal.y ;
- altitude ;
- temperature ;
- precipitation ;
- wind exposure ;
- occlusion ;
- surface warmth ;
- slope.

Règles :

- neige sur surfaces horizontales ;
- moins sur pentes raides ;
- plus dans creux ;
- moins sous arbres ou sur matériaux chauds ;
- transition vers glace si compactée/mouillée.

### 11.4 Dust / sand

- accumulation sur surfaces horizontales ;
- dépend du biome ;
- déplacée par vent ;
- augmente roughness ;
- réduit contraste ;
- ajoute micro normal fine.

### 11.5 Moss / lichen

- dépend humidité ;
- dépend exposition solaire ;
- dépend âge de surface ;
- dépend orientation ;
- dépend proximité végétation/eau ;
- plus fort dans biomes forestiers/humides.

---

## 12. Decals et détails dynamiques

### 12.1 Types de decals

- cracks ;
- dirt ;
- mud splashes ;
- water stains ;
- moss patches ;
- scorch marks ;
- bullet impacts selon époque ;
- claw marks ;
- footprints ;
- wheel tracks ;
- blood ;
- oil ;
- graffiti ;
- road markings ;
- runes ;
- magical residues ;
- snow compression ;
- ice cracks ;
- construction seams ;
- metal scratches ;
- paint peeling.

### 12.2 Deferred decals vs mesh decals

- **Deferred decals** : efficaces pour surfaces opaques dans GBuffer.
- **Mesh decals** : propres pour objets spécifiques, moins dépendants du screen-space.
- **RVT decals** : meilleurs pour terrain dynamique persistent.

### 12.3 Recommandation IsoWorld

- terrain : runtime virtual texture decals ;
- props proches : mesh decals ;
- impacts temporaires : screen/deferred decals ;
- traces persistantes : chunk decal layer seedée + event log léger.

---

## 13. Lighting architecture

### 13.1 Choix global

Pour IsoWorld sans ray tracing, utiliser un pipeline hybride :

```text
Depth Prepass optional
GBuffer compact ou Forward+ base pass
Tiled/Clustered light list
Shadow maps
Lighting pass
GTAO
SSR optional
Volumetric fog
Transparent Forward+
Post-process
```

### 13.2 Forward+, Deferred ou hybride ?

#### Forward+

Avantages :

- bon pour MSAA ;
- transparence plus simple ;
- moins de mémoire GBuffer ;
- bon pour Apple tile-based GPUs ;
- compatible matériaux complexes.

Inconvénients :

- shading répété avec overdraw ;
- plus difficile pour decals deferred ;
- beaucoup de variantes si mal structuré.

#### Deferred

Avantages :

- beaucoup de lumières ;
- decals faciles ;
- lighting découplé ;
- debug GBuffer très clair.

Inconvénients :

- GBuffer coûteux en mémoire/bande passante ;
- transparence séparée ;
- MSAA compliqué ;
- moins idéal si beaucoup de matériaux spéciaux.

#### Hybride recommandé

```text
Opaque terrain/props:    compact deferred ou visibility-buffer-lite
Foliage:                 forward+
Water:                   forward special
Transparent:             forward+
Particles:               forward/lit-unlit
Decals terrain:          RVT
Decals objets:           deferred ou mesh decals
```

Pour un premier moteur Swift/Metal : commencer avec **Forward+ propre**, puis ajouter un **GBuffer compact** si les besoins decals/lumières explosent.

---

## 14. Clustered / tiled lighting

### 14.1 Principe

Diviser l’écran ou le frustum en clusters. Chaque cluster contient une liste de lumières affectant les pixels de cette région.

```text
Screen tiles: 16x16 or 32x32
Depth slices: logarithmic
Cluster = tileX, tileY, depthSlice
Light list = compact indices
```

### 14.2 Données lumière

```metal
struct GPULight {
    packed_float3 position;
    float radius;
    packed_float3 color;
    float intensity;
    packed_float3 direction;
    float coneAngle;
    uint type;
    uint shadowIndex;
    uint flags;
    float temperature;
};
```

### 14.3 Types de lumières

- directional sun ;
- moon ;
- point light ;
- spot light ;
- tube light approximée ;
- area light approximée ;
- emissive proxy light ;
- campfire flicker ;
- torch ;
- lantern ;
- neon ;
- magical orb ;
- biome light ;
- cave glow ;
- lava glow ;
- firefly cluster ;
- sci-fi panel ;
- vehicle light.

### 14.4 Budget

Exemple de budgets :

```text
Sun/moon directional:       1–2
Visible dynamic lights:     256–1024 candidates
Per cluster light count:    32–128 max
Shadowed local lights:      4–16 near player
Far emissive lights:        impostor/probe only
```

### 14.5 Culling

- CPU coarse culling par chunk ;
- GPU fine culling par cluster ;
- distance fade ;
- importance score ;
- shadow priority ;
- light merging pour petites lumières lointaines.

---

## 15. Shadows

### 15.1 Directional shadows

Pour soleil/lune : **Cascaded Shadow Maps**.

Paramètres :

- 3 ou 4 cascades ;
- cascade proche haute résolution ;
- stabilisation texel ;
- blend entre cascades ;
- PCF ;
- normal bias ;
- slope bias ;
- contact shadow écran léger ;
- temporal stabilization.

### 15.2 Cascade strategy

```text
Cascade 0: 0–20 m      très détaillée
Cascade 1: 20–80 m     moyenne
Cascade 2: 80–250 m    large
Cascade 3: 250–800 m   optionnelle, très basse fréquence
```

### 15.3 Local shadows

Pour point/spot lights :

- shadow atlas ;
- update partiel ;
- priority score ;
- cache des ombres statiques ;
- lights dynamiques proches seulement ;
- résolution variable ;
- fade shadow distance.

### 15.4 Soft shadows sans RT

Options :

- PCF variable ;
- PCSS approximé ;
- EVSM/VSM pour certaines lumières ;
- capsule shadows pour personnages ;
- contact shadow screen-space ;
- blob shadows stylisées pour petits objets ;
- baked AO/contact dans textures.

### 15.5 Shadow priority

```text
score = lightIntensity * screenSize * playerRelevance * movementFactor * gameplayImportance / cost
```

Exemples :

- torche tenue par joueur : shadow prioritaire ;
- néon lointain : pas d’ombre ;
- feu de camp proche : ombre moyenne ;
- soleil : toujours ;
- lucioles : jamais, contribution emissive/probe.

---

## 16. Global illumination approximée

### 16.1 Objectif

Sans RT, on veut :

- indirect stable ;
- personnages intégrés ;
- caves lisibles ;
- extérieur naturel ;
- transitions intérieur/extérieur ;
- coût contrôlé.

### 16.2 Composants recommandés

```text
IBL sky diffuse/specular
Reflection probes
Irradiance probes / volume probes
Baked chunk lightmaps optional
Screen-space GI very light optional
GTAO + GTSO
Emissive proxy lights
Ambient gradients
```

### 16.3 Irradiance probes par chunk

Pour IsoWorld :

```swift
struct ProbeChunkData {
    var chunkID: ChunkID
    var probeGridOrigin: SIMD3<Float>
    var probeSpacing: Float
    var probeCount: SIMD3<UInt16>
    var irradianceSH: BufferRef
    var visibility: BufferRef?
    var validityMask: BufferRef
}
```

### 16.4 Probe placement

- plus dense près du sol ;
- plus dense dans grottes ;
- plus dense près bâtiments ;
- moins dense dans ciel ouvert ;
- densité selon complexité géométrique ;
- streaming par chunk.

### 16.5 Modes de génération de probes

1. **Analytique rapide** : ciel + soleil + occlusion approximée par terrain.
2. **Bake local chunk** : compute/CPU lors de génération, simplifié.
3. **Offline library** : probes prévalidées pour modules/props.
4. **Runtime update rare** : météo/heure du jour modifie les coefficients.

### 16.6 Lightmaps

Lightmaps utiles pour :

- bâtiments statiques ;
- grottes ;
- donjons ;
- ruines ;
- props architecturaux ;
- villes générées.

Pour terrain outdoor dynamique, préférer probes + AO + IBL.

### 16.7 Temporal lightmaps

À long terme, on peut avoir :

- lightmaps par heure du jour ;
- lightmaps compressées ;
- interpolation jour/nuit ;
- seulement pour structures fixes importantes.

Mais ne pas commencer par là.

---

## 17. Image-Based Lighting

### 17.1 IBL de base

Préparer :

- irradiance diffuse cubemap ou SH ;
- prefiltered specular environment ;
- BRDF integration LUT ;
- exposure contrôlée ;
- sky model.

### 17.2 IBL dynamique jour/nuit

Options :

1. Générer plusieurs cubemaps par temps/heure.
2. Interpoler SH/cubemaps.
3. Utiliser ciel analytique pour diffuse.
4. Reflection probes locales pour spécular.

### 17.3 Reflection probes

Types :

- global sky probe ;
- biome probe ;
- cave probe ;
- indoor probe ;
- water reflection probe ;
- city/street probe ;
- dungeon probe.

### 17.4 Blending probes

```text
probeWeight = inverseDistance * visibility * priority * volumeMembership
```

Probes doivent avoir volumes d’influence : sphere, box, capsule, zone de biome.

---

## 18. Screen-space effects sans RT

### 18.1 GTAO

Utilisation :

- contact terrain/props ;
- racines ;
- rochers ;
- creux de falaise ;
- intérieurs ;
- végétation proche ;
- personnages.

### 18.2 Screen-space reflections

SSR utile pour :

- sol mouillé ;
- flaques ;
- eau calme ;
- métal poli ;
- glace ;
- marbre ;
- surfaces futuristes.

Limites :

- ne reflète que ce qui est à l’écran ;
- artefacts bords écran ;
- instable si mal temporalisé ;
- doit fallback sur reflection probes.

### 18.3 Screen-space shadows / contact shadows

Petites ombres proches :

- pieds/personnages ;
- petits props ;
- herbe ;
- rochers ;
- marches ;
- racines.

À utiliser avec parcimonie.

### 18.4 SSGI léger

Option future : faible résolution + temporal denoise + clamp. Ne pas prioriser avant un PBR/IBL/probes solides.

---

## 19. Atmosphère, ciel, brouillard

### 19.1 Sky model

Sans path tracing, le ciel peut être analytique :

- soleil ;
- lune ;
- étoiles ;
- gradient atmosphérique ;
- horizon haze ;
- couleur par météo ;
- nuages procéduraux.

### 19.2 Volumetric fog

Pour un rendu haute qualité :

- froxel grid basse résolution ;
- injection des lumières principales ;
- temporal accumulation ;
- noise dithering ;
- height fog ;
- biome fog ;
- cave mist ;
- god rays approximés.

### 19.3 Fog par biome

- marais : bas, dense, vert/gris ;
- forêt humide : léger, volumique ;
- désert : poussière chaude ;
- banquise : brume froide ;
- volcan : fumée/cendre ;
- ville futuriste : haze pollué ;
- zone magique : fog coloré.

### 19.4 Intégration lumière/fog

- le soleil colore le fog ;
- les torches illuminent localement ;
- les caves ont fog faible mais visible ;
- les particules météo interagissent visuellement.

---

## 20. Eau sans ray/path tracing

### 20.1 Water surface model

Composants :

- normal maps multi-échelles ;
- flow maps ;
- Fresnel ;
- reflection probe ;
- SSR si disponible ;
- refraction approximée ;
- depth fade ;
- foam ;
- caustics fake ;
- shoreline wetness.

### 20.2 Types d’eau

- flaque ;
- ruisseau ;
- rivière ;
- rapide ;
- cascade ;
- lac ;
- mer calme ;
- mer agitée ;
- marais ;
- eau gelée ;
- eau boueuse ;
- eau tropicale ;
- eau polluée ;
- liquide fantastique.

### 20.3 Rivières

Inputs :

- flow direction ;
- flow speed ;
- depth ;
- turbulence ;
- foam mask ;
- bank wetness ;
- sediment color.

### 20.4 Shoreline

Rendu essentiel :

- wet sand/rock ;
- foam edge ;
- small wave decals ;
- underwater color ;
- transparency depth fade ;
- contact AO.

---

## 21. Végétation et foliage

### 21.1 Foliage material

Spécifique :

- alpha masked ;
- two-sided lighting ;
- subsurface/transmission approximée ;
- wind animation ;
- hue variation ;
- wetness ;
- snow accumulation ;
- distance simplification.

### 21.2 Problèmes

- alpha overdraw ;
- normal trop bruitée ;
- mip alpha qui scintille ;
- ombres coûteuses ;
- LOD popping ;
- temporal shimmer.

### 21.3 Solutions

- alpha-to-coverage si MSAA ;
- dithered LOD ;
- impostors ;
- normal smoothing ;
- cards regroupées ;
- shadow LOD différent ;
- material simplifié à distance ;
- wind LOD.

### 21.4 Foliage lighting

- sun direct ;
- sky diffuse ;
- simple transmission ;
- AO modéré ;
- pas de SSR ;
- probes pour indirect.

---

## 22. Props manufacturés et intérieurs

### 22.1 Props

Les props utilisent `OpaquePBR`, `MaskedPBR`, `ClothPBR`, `GlassApprox`, `EmissivePBR`.

### 22.2 Détails nécessaires

- edge wear ;
- dirt accumulation ;
- dust ;
- scratches ;
- rust ;
- paint peeling ;
- wetness ;
- snow caps ;
- fingerprints pour hero assets ;
- grime autour des joints ;
- AO baked.

### 22.3 Intérieurs

Sans RT, intérieurs difficiles. Recommandé :

- local reflection probes ;
- baked lightmaps pour structures ;
- volumetric probes ;
- ambient gradients ;
- shadowed lights limitées ;
- decals de saleté ;
- fog subtil ;
- luminaires emissive + proxy lights.

---

## 23. Éclairage par époque / univers RPG

Le pipeline doit supporter plusieurs mondes générés.

### 23.1 Monde préhistorique

- soleil fort ;
- torches ;
- feux ;
- matériaux naturels ;
- pas d’éclairage électrique ;
- grottes sombres ;
- pigments organiques.

### 23.2 Monde médiéval

- torches ;
- lanternes ;
- bougies ;
- vitraux approximés ;
- métaux bruts ;
- bois/pierre ;
- intérieurs low-light.

### 23.3 Monde moderne

- lampadaires ;
- néons ;
- phares ;
- écrans ;
- béton/asphalte/verre ;
- pollution lumineuse.

### 23.4 Monde post-apocalyptique

- rouille ;
- poussière ;
- surfaces brûlées ;
- lampes cassées ;
- lumière instable ;
- ciel poussiéreux.

### 23.5 Monde futuriste

- surfaces emissive ;
- matériaux composites ;
- éclairage froid ;
- hologrammes approximés ;
- chrome/ceramic ;
- bloom contrôlé.

### 23.6 Monde fantastique

- cristaux emissive ;
- fog coloré ;
- matériaux magiques ;
- lumières non physiques mais cohérentes ;
- runes ;
- bioluminescence.

---

## 24. Pipeline Metal recommandé

### 24.1 Argument buffers

Utiliser les argument buffers pour regrouper :

- textures ;
- samplers ;
- material parameter buffers ;
- light buffers ;
- probe buffers ;
- page tables ;
- shadow maps.

Avantages :

- moins de binding CPU ;
- compatible GPU-driven ;
- meilleur batching ;
- ressources persistantes.

### 24.2 Sparse textures

Utiliser pour :

- terrain ;
- macro albedo ;
- runtime virtual texture ;
- très grandes maps de biome ;
- lightmaps volumineuses à long terme.

### 24.3 Tile shaders / TBDR

Apple GPUs étant tile-based, exploiter :

- forward+ tile light culling ;
- deferred lighting tile-friendly ;
- réduction bande passante ;
- memoryless attachments quand possible ;
- pass fusion si pertinent.

### 24.4 ICB / GPU-driven

Pour l’avenir :

- culling lumières ;
- culling decals ;
- draw indirect terrain/props ;
- material sorting ;
- batching.

### 24.5 Metal 4

Metal 4 apporte de nouveaux workflows de compilation shader et de nouveaux concepts de core API. Pour IsoWorld, il faut prévoir une adoption incrémentale : garder une couche `RenderBackend` qui masque les différences entre API Metal classique et Metal 4.

### 24.6 Resource lifetime

Créer des managers explicites :

- `TextureManager` ;
- `MaterialManager` ;
- `LightManager` ;
- `ProbeManager` ;
- `ShadowAtlasManager` ;
- `TransientRenderGraphAllocator` ;
- `SparseResidencyManager`.

---

## 25. Render graph

### 25.1 Pourquoi

Un render graph évite :

- ressources temporaires mal gérées ;
- passes dans le mauvais ordre ;
- bande passante excessive ;
- bugs de synchronisation ;
- code renderer illisible.

### 25.2 Passes proposées

```text
FrameSetup
GPUCulling
DepthPrepass optional
ShadowCSM
ShadowLocalAtlas
GBufferOrForwardBase
Decals
GTAO
Lighting
SSR optional
Transparent
Water
VolumetricFog
Sky
PostProcessBloom
Tonemap
ColorGrade
UIComposite
DebugOverlay
```

### 25.3 Ressources principales

```text
Depth
Normals
MotionVectors
MaterialID
BaseColor/Lighting buffer selon pipeline
HDRColor
AO
ShadowMaps
ProbeBuffers
VirtualTexturePageTable
RVT pages
FogVolume
```

---

## 26. Tonemapping, exposure, color grading

### 26.1 HDR obligatoire

Le pipeline doit accumuler en HDR linéaire.

### 26.2 Auto exposure

Modes :

- disabled debug ;
- smooth gameplay ;
- cinematic ;
- cave-adaptive ;
- fixed for screenshots.

### 26.3 Tonemapper

Choisir un tonemapper stable type ACES-inspired ou custom filmic.

### 26.4 Color grading

Dépend de :

- `WorldRenderDNA` ;
- biome ;
- météo ;
- heure ;
- état joueur ;
- zone narrative.

Mais rester subtil. Le matériau doit rester lisible.

---

## 27. Weather rendering

### 27.1 Pluie

- wetness accumulation ;
- roughness down ;
- darkening ;
- puddles ;
- rain streaks ;
- ripples ;
- particle rain ;
- fog/haze ;
- lower contrast ;
- splash decals.

### 27.2 Neige

- accumulation ;
- snow material overlay ;
- compression sous pieds ;
- sparkle subtil ;
- blue shadow tint ;
- fog froid ;
- reduced roughness selon gel.

### 27.3 Vent poussiéreux

- dust layer ;
- fog color ;
- particles ;
- reduced visibility ;
- deposition sur surfaces ;
- erosion visual.

### 27.4 Tempête

- dynamic exposure ;
- lightning flashes ;
- rain intensity ;
- wetness max ;
- wind-driven particles ;
- shadow contrast variable.

### 27.5 Météo fantastique

- pluie de cendres ;
- brume magique ;
- cristaux de givre ;
- pollen lumineux ;
- poussière radioactive stylisée ;
- tempête de sable rouge ;
- pluie noire ;
- neige bleutée ;
- particules bioluminescentes.

---

## 28. Matériaux procéduraux runtime

### 28.1 Où utiliser du procédural runtime ?

Oui pour :

- micro variation ;
- masks météo ;
- terrain macro ;
- triplanar ;
- snow/wetness ;
- biome tint ;
- detail normals ;
- decals dynamiques.

Non pour :

- graphes énormes par pixel ;
- génération complète de toutes les maps en fragment shader ;
- noise trop coûteux partout ;
- matériaux hero sans bake.

### 28.2 Noise library

Prévoir :

- value noise ;
- gradient noise ;
- simplex/perlin si nécessaire ;
- blue noise textures ;
- cellular/worley ;
- erosion masks ;
- crack patterns ;
- stripe/strata ;
- domain warp.

### 28.3 Optimisation

- noise prébaké en petites textures ;
- lookup tables ;
- calcul vertex/compute si possible ;
- partager les masks par chunk ;
- limiter les octaves ;
- version LOD shader.

---

## 29. Variantes de matériaux

### 29.1 Axes de variation

- couleur ;
- roughness ;
- grain ;
- échelle ;
- fissures ;
- humidité ;
- saleté ;
- usure ;
- mousse ;
- vieillissement ;
- métal oxydé ;
- peinture écaillée ;
- snow response ;
- wetness response ;
- emission pattern ;
- biome tint ;
- époque ;
- culture ;
- technologie.

### 29.2 Variation corrélée

Ne pas randomiser indépendamment. Exemple :

```text
worldAge high -> more dirt, moss, cracks, faded colors
wet biome -> more moss, lower dust, higher wetness
industrial era -> more metal, paint, grime, emissive signs
cold climate -> snow response high, ice masks common
volcanic geology -> dark rock, ash dust, low vegetation
```

### 29.3 MaterialVariantSeed

```swift
struct MaterialVariantSeed: Hashable, Sendable {
    var worldSeed: UInt64
    var biomeID: UInt32
    var geologyID: UInt32
    var materialFamilyID: UInt32
    var chunkID: ChunkID
    var localFeatureID: UInt32
}
```

---

## 30. Rules engine pour surfaces

### 30.1 Exemple de règle

```yaml
rule: moss_on_old_wet_rock
when:
  materialFamily: rock
  humidity: > 0.62
  sunExposure: < 0.45
  surfaceAge: > 0.5
  slope: < 0.85
then:
  addLayer: moss
  weight: humidity * (1 - sunExposure) * surfaceAge
  roughnessBoost: 0.15
  colorTint: biome.mossTint
```

### 30.2 Règles météo

```yaml
rule: rain_makes_stone_wet
when:
  precipitation: rain
  exposedToSky: true
  materialFamily: [rock, concrete, metal, wood]
then:
  wetness += rainIntensity * material.wetnessResponse
  roughnessTarget: lower
  puddleCandidate: curvatureConcave
```

### 30.3 Règles biome

```yaml
rule: desert_dust_layer
when:
  biome: desert
  windExposure: > 0.5
  humidity: < 0.25
then:
  dust += windExposure * dryness
  albedoTint: warm_ochre
  roughness += 0.1
```

---

## 31. Lumières procédurales

### 31.1 Sources de lumières générées

- soleil ;
- lune ;
- étoiles ;
- ciel ;
- feu de camp ;
- torches ;
- bougies ;
- lampadaires ;
- maisons ;
- fenêtres ;
- néons ;
- panneaux ;
- écrans ;
- véhicules ;
- machines ;
- cristaux ;
- plantes bioluminescentes ;
- insectes lumineux ;
- lave ;
- champignons lumineux ;
- portails ;
- artefacts ;
- magie ;
- éclairs ;
- explosions ;
- particules emissives.

### 31.2 Light recipes

```swift
struct LightRecipe: Codable, Sendable {
    var family: LightFamily
    var colorTemperatureRange: ClosedRange<Float>
    var intensityRange: ClosedRange<Float>
    var radiusRange: ClosedRange<Float>
    var flickerProfile: FlickerProfile?
    var shadowPolicy: ShadowPolicy
    var biomeCompatibility: [BiomeTag]
    var eraCompatibility: [EraTag]
}
```

### 31.3 Flicker

Pour feu/torche :

- noise temporel ;
- intensité ;
- couleur ;
- radius ;
- shadow jitter faible ;
- particles synchronisées.

### 31.4 Lumières emissive

Un matériau emissive peut générer une proxy light :

```text
emissiveArea > threshold -> create approximate local light
small/far emissive -> bloom only
large emissive panel -> area light approx
```

---

## 32. LOD matériaux/lumières

### 32.1 Material LOD

```text
LOD0: full PBR + detail normal + weather + decals
LOD1: PBR + packed maps + simple weather
LOD2: no detail normal, simplified blending
LOD3: baked color/roughness, no dynamic layers
LOD4: impostor/material atlas
```

### 32.2 Terrain LOD

- proche : multi-layer height blend ;
- mid : fewer layers ;
- far : macro texture ;
- very far : color/normal clipmap ;
- background : atmospheric color.

### 32.3 Light LOD

- proche : shadowed + full BRDF ;
- mid : unshadowed ;
- far : merged/clustered contribution ;
- very far : emissive only/bloom ;
- invisible : culled.

### 32.4 Shadow LOD

- near high res ;
- mid lower res ;
- far cascade stable ;
- small objects excluded far ;
- foliage shadows simplified.

---

## 33. Performance targets M1

Ces budgets sont indicatifs et doivent être mesurés.

```text
Frame target:                 16.6 ms à 60 fps
Surface base pass:             2–5 ms
Lighting:                      1–3 ms
Shadows:                       1–4 ms selon scène
GTAO:                          0.5–1.5 ms
Fog:                           0.5–1.5 ms
Post process:                  1–2 ms
Texture upload budget/frame:   <1–2 ms CPU/GPU visible
CPU renderer submission:       minimal via batching/argument buffers
```

### 33.1 Ce qui coûte cher

- trop de texture samples ;
- trop de layers terrain ;
- triplanar partout ;
- alpha foliage overdraw ;
- ombres locales multiples ;
- SSR haute résolution ;
- GBuffer trop large ;
- decals non maîtrisés ;
- shader permutations ;
- mauvais mip bias ;
- streaming synchrone.

### 33.2 Optimisations prioritaires

- depth prepass optionnelle pour terrain/foliage ;
- material sorting ;
- texture arrays/argument buffers ;
- clustered lights ;
- shadow priority ;
- AO half-res + temporal ;
- fog low-res ;
- material LOD ;
- virtual texture fallback ;
- render graph transient resources.

---

## 34. Debug views indispensables

Créer très tôt :

### 34.1 Matériaux

- base color ;
- roughness ;
- metallic ;
- normal ;
- AO ;
- height ;
- material ID ;
- texture mip ;
- texture residency ;
- texel density ;
- layer weights ;
- wetness ;
- snow ;
- dust ;
- moss ;
- decal count.

### 34.2 Lumières

- light clusters ;
- light count per cluster ;
- shadowed lights ;
- shadow cascade splits ;
- shadow map atlas ;
- probe influence ;
- irradiance SH ;
- reflection probe ;
- AO ;
- SSR hits/misses ;
- fog density ;
- exposure.

### 34.3 Performance

- GPU timings per pass ;
- CPU submission time ;
- texture memory ;
- transient memory ;
- sparse page count ;
- draw count ;
- pipeline switches ;
- material switches ;
- overdraw ;
- alpha overdraw.

---

## 35. Data assets recommandés

### 35.1 Material family

```yaml
id: rock_basalt_dark
family: rock
model: OpaquePBR
physicalSizeMeters: [2.0, 2.0]
baseTextureSet: basalt_dark_01
responses:
  wetness: 0.9
  snow: 0.7
  dust: 0.4
  moss: 0.6
rules:
  - moss_on_old_wet_rock
  - rain_makes_stone_wet
lod:
  detailNormalFadeDistance: 25
  triplanarMaxDistance: 60
```

### 35.2 Biome material palette

```yaml
biome: temperate_forest
terrainLayers:
  - forest_humus
  - moss_wet
  - grass_temperate
  - rock_granite_mossy
  - mud_dark
surfaceModifiers:
  humidityBias: 0.25
  mossBias: 0.35
  dustBias: -0.2
lighting:
  skyTint: cool_green
  fogColor: humid_gray_green
```

### 35.3 Lighting palette

```yaml
era: medieval
lights:
  - torch_warm
  - candle_small
  - campfire_large
  - moon_cool
emissiveMaterials:
  - ember
  - rune_low
shadowPolicy:
  maxLocalShadowedLights: 6
```

---

## 36. Gestion des shaders et permutations

### 36.1 Danger

Un moteur moderne peut mourir sous les permutations :

```text
terrain + wetness + snow + decals + SSR + triplanar + foliage + clearcoat + transmission + ...
```

### 36.2 Solution

- peu de pipelines ;
- feature flags runtime ;
- specialization constants si disponible/utile ;
- material quality tiers ;
- shader library claire ;
- compilation async ;
- cache disque ;
- Metal 4 compilation API à étudier pour contrôler compilation.

### 36.3 Familles de shaders

```text
terrain_layered_pbr
opaque_pbr
masked_foliage_pbr
water_surface
decal_pbr
particle_lit
particle_unlit
sky_atmosphere
volumetric_fog
postprocess
```

---

## 37. Compression et formats

### 37.1 Objectif

Réduire :

- mémoire GPU ;
- bande passante ;
- temps de chargement ;
- taille disque.

### 37.2 Recommandations

- ASTC si disponible et performant ;
- BCn selon profil macOS/Metal support ;
- R8/RG8 pour masks ;
- R16 pour height si nécessaire ;
- normal maps en deux canaux ;
- mipmaps toujours ;
- compression différente pour UI/HDR/cubemaps.

### 37.3 Ne pas compresser n’importe comment

- normal maps : éviter artefacts ;
- roughness : banding visible ;
- masks : contrôler canal par canal ;
- height : précision selon parallax/blending ;
- HDR env maps : format adapté.

---

## 38. Color management

### 38.1 Règles

- toutes les lumières en linéaire ;
- albedo calibré ;
- pas de lighting dans base color ;
- values réalistes ;
- exposure stable ;
- white point défini ;
- debug false-color.

### 38.2 Validation albedo

Créer une vue qui signale :

- albedo trop noir ;
- albedo trop blanc ;
- couleurs saturées non physiques ;
- roughness aberrante ;
- metallic non binaire sur matériaux diélectriques.

---

## 39. Outils internes

### 39.1 Material viewer

Un viewer standalone :

- sphere/cube/plane/terrain patch ;
- HDRI ;
- lumière directionnelle ;
- wetness slider ;
- snow slider ;
- dust slider ;
- biome slider ;
- mip view ;
- LOD view ;
- shader cost.

### 39.2 Lighting sandbox

- lumières multiples ;
- cluster debug ;
- shadow atlas debug ;
- probe debug ;
- fog debug ;
- exposure test ;
- day/night cycle.

### 39.3 Chunk visualizer

- matériaux par chunk ;
- pages texture résidentes ;
- probes chunk ;
- light influence ;
- terrain layer weights ;
- weather state.

---

## 40. Intégration avec systèmes IsoWorld

### 40.1 Terrain generation

Le terrain fournit :

- height ;
- normals ;
- slope ;
- curvature ;
- geology ;
- moisture ;
- biome weights ;
- hydrology ;
- erosion masks.

Le renderer transforme ces données en matériaux.

### 40.2 Biomes

Les biomes fournissent :

- palettes terrain ;
- tints ;
- fog ;
- humidity ;
- vegetation material families ;
- water style ;
- snow/dust/moss rules.

### 40.3 Props

Les props fournissent :

- material slots ;
- procedural masks ;
- wear maps ;
- dirt accumulation anchors ;
- material LOD ;
- emissive metadata.

### 40.4 Animation/physics

Les interactions joueur/terrain peuvent modifier :

- traces de pas ;
- boue déplacée ;
- neige tassée ;
- poussière ;
- flaques ;
- decals temporaires.

### 40.5 Météo

La météo modifie :

- surface state ;
- fog ;
- sky ;
- lights ;
- exposure ;
- particles ;
- water surface.

### 40.6 RPG

L’époque RPG modifie :

- matériaux disponibles ;
- éclairages ;
- architecture ;
- propreté/usure ;
- technologie ;
- emissive style ;
- color grading.

---

## 41. Roadmap d’implémentation

### Phase 1 — PBR solide

- material model `OpaquePBR` ;
- texture sets baseColor/normal/ORM ;
- IBL sky simple ;
- one directional light ;
- tone mapping ;
- debug views baseColor/roughness/normal.

### Phase 2 — Terrain layered

- terrain layer descriptors ;
- slope/height/biome blending ;
- triplanar pour falaises ;
- macro/micro variation ;
- matériau neige/boue/herbe/roche.

### Phase 3 — Forward+ lights

- light buffer ;
- tile/cluster culling ;
- point/spot lights ;
- debug clusters ;
- priority system.

### Phase 4 — Shadows

- cascaded shadow maps ;
- shadow atlas local ;
- PCF ;
- shadow priority ;
- debug cascade.

### Phase 5 — Surface states

- wetness ;
- snow ;
- dust ;
- moss ;
- weather integration ;
- material response curves.

### Phase 6 — Probes

- sky SH ;
- reflection probes ;
- chunk irradiance probes ;
- probe blending ;
- cave/indoor support.

### Phase 7 — Virtual textures

- chunk texture streaming ;
- sparse texture prototype ;
- terrain virtual texture ;
- RVT-like terrain decals.

### Phase 8 — Atmosphere/fog/water

- sky model ;
- volumetric fog low-res ;
- water shader ;
- SSR optional ;
- shoreline effects.

### Phase 9 — Tooling production

- material viewer ;
- lighting sandbox ;
- texture residency debugger ;
- validation albedo ;
- performance HUD integration.

---

## 42. Architecture Swift proposée

```swift
public final class SurfaceSystem {
    public func resolveMaterial(
        surface: SurfaceDescriptor,
        world: WorldRenderContext,
        chunk: ChunkContext
    ) -> IsoMaterialRuntime
}

public final class TextureStreamingSystem {
    public func update(camera: CameraState, visibleChunks: [ChunkID])
    public func prepareFrame(device: MTLDevice, commandBuffer: MTLCommandBuffer)
}

public final class LightingSystem {
    public func collectLights(world: WorldState, visibleChunks: [ChunkID])
    public func encodeClusterBuild(commandBuffer: MTLCommandBuffer)
    public func bindLightingResources(_ encoder: MTLRenderCommandEncoder)
}

public final class ProbeSystem {
    public func streamProbeChunks(around player: SIMD3<Float>)
    public func sampleIrradiance(at position: SIMD3<Float>) -> SphericalHarmonics3
}

public final class WeatherSurfaceSystem {
    public func updateSurfaceStates(deltaTime: Float, weather: WeatherState)
    public func encodeSurfaceStateMaps(commandBuffer: MTLCommandBuffer)
}
```

---

## 43. Architecture GPU proposée

### 43.1 Buffers

```text
Material table
Material params buffer
Texture descriptor table
Light buffer
Cluster light index buffer
Probe SH buffer
Shadow matrices
Virtual texture page table
Surface state maps
Biome parameter buffer
```

### 43.2 Argument buffer

```metal
struct FrameResources {
    constant CameraParams& camera;
    device MaterialParams* materials;
    texture2d_array<float> baseColorArray;
    texture2d_array<float> normalArray;
    texture2d_array<float> ormArray;
    device GPULight* lights;
    device uint* clusterLightIndices;
    texture2d<float> shadowAtlas;
    texturecube<float> skySpecular;
    texturecube<float> skyDiffuse;
    sampler linearSampler;
    sampler anisotropicSampler;
};
```

### 43.3 Shader terrain simplifié

```metal
FragmentOut terrainFragment(TerrainIn in [[stage_in]],
                            constant FrameResources& frame [[buffer(0)]]) {
    TerrainSurface s = evaluateTerrainLayers(in);
    applyWeather(s, in.worldPos, frame);
    PBRResult lit = shadePBR(s, frame);
    return compose(lit);
}
```

---

## 44. Qualité visuelle : checklist

### 44.1 Matériaux

- albedo crédible ;
- roughness variée ;
- normals non excessives ;
- AO subtil ;
- détails macro/micro ;
- pas de tiling visible ;
- transitions propres ;
- decals bien intégrés.

### 44.2 Lumière

- soleil stable ;
- ombres lisibles ;
- indirect présent ;
- intérieurs pas plats ;
- nuit jouable ;
- fog cohérent ;
- lumières locales priorisées ;
- exposure agréable.

### 44.3 Monde procédural

- les biomes ont une signature visuelle ;
- les transitions ne coupent pas ;
- la météo change les surfaces ;
- les chunks ne poppent pas ;
- les matériaux seedés restent cohérents.

---

## 45. Risques techniques

### 45.1 Shader trop gros

Solution : material LOD, variantes limitées, graph compilation.

### 45.2 Virtual texturing trop tôt

Solution : commencer par streaming mip classique, puis ajouter sparse/VT quand les besoins sont clairs.

### 45.3 Trop de lights shadowed

Solution : shadow priority, unshadowed far lights, emissive proxies.

### 45.4 Terrain trop coûteux

Solution : réduire layers selon distance, macro texture far, triplanar proche seulement.

### 45.5 Surfaces dynamiques instables

Solution : temporal smoothing, surface state maps à résolution contrôlée, event logs compacts.

### 45.6 Art direction incohérente

Solution : `WorldRenderDNA` + palettes + validation physique.

---

## 46. Décisions recommandées pour IsoWorld v1

### 46.1 À faire maintenant

- PBR metallic/roughness propre ;
- terrain layered avec slope/height/biome ;
- normal/ORM packing ;
- IBL simple ;
- directional light + CSM ;
- wetness/snow/dust hooks ;
- debug views ;
- material descriptors en JSON/YAML/Swift Codable ;
- texture streaming simple.

### 46.2 À faire ensuite

- Forward+ clustered lighting ;
- local shadow atlas ;
- GTAO ;
- reflection probes ;
- chunk irradiance probes ;
- triplanar optimized ;
- material viewer.

### 46.3 À faire plus tard

- sparse virtual textures ;
- runtime virtual terrain texture ;
- volumetric fog avancé ;
- SSR ;
- temporal GI approximée ;
- MaterialX import ;
- OpenPBR-inspired advanced materials ;
- neural/material synthesis tooling offline.

---

## 47. Système cible final

À terme, IsoWorld devrait avoir :

```text
WorldRenderDNA
BiomeMaterialPalettes
MaterialGraphCompiler
RuntimeMaterialTable
TextureStreaming + Sparse Pages
TerrainLayeredPBR
SurfaceStateMaps
Forward+/Clustered Lights
CSM + Shadow Atlas
IBL + Reflection Probes
Chunk Irradiance Probes
GTAO/GTSO
Water/Fog/Sky
PostProcess HDR
Debug Tools
```

Ce système permettrait :

- monde procédural déterministe ;
- rendu haut de gamme sans RT ;
- terrains riches ;
- props variés ;
- météo lisible ;
- biomes crédibles ;
- époques RPG distinctes ;
- coût runtime maîtrisé ;
- évolution future vers ray tracing/path tracing si besoin.

---

## 48. Longue liste de systèmes texture/lumière à implémenter

### 48.1 Texture/material systems

- Material graph authoring ;
- Material graph compiler ;
- Material runtime table ;
- Texture set registry ;
- Texture compression pipeline ;
- Mip generation pipeline ;
- Texel density validator ;
- Albedo validator ;
- Roughness validator ;
- Normal map validator ;
- ORM packer ;
- Height map baker ;
- Detail normal system ;
- Macro variation system ;
- Biome tint system ;
- Triplanar projection ;
- Terrain material layer stack ;
- Height-based blending ;
- Slope-based blending ;
- Curvature-based accumulation ;
- Weather masks ;
- Wetness overlay ;
- Snow overlay ;
- Dust overlay ;
- Moss overlay ;
- Lichen overlay ;
- Mud overlay ;
- Ice overlay ;
- Ash overlay ;
- Rust system ;
- Paint wear system ;
- Dirt accumulation system ;
- Edge wear system ;
- Procedural cracks ;
- Procedural mineral veins ;
- Footprint decals ;
- Wheel track decals ;
- Terrain RVT decals ;
- Mesh decals ;
- Deferred decals ;
- Material LOD ;
- Texture streaming ;
- Texture residency feedback ;
- Sparse texture pages ;
- Runtime virtual textures ;
- Texture arrays ;
- Sampler library ;
- Material instance variants ;
- Seeded material mutation ;
- Material biome compatibility ;
- Material era compatibility ;
- Material gameplay tags ;
- Material sound/physics link ;
- Material VFX spawn link.

### 48.2 Lighting systems

- Directional sun ;
- Directional moon ;
- Sky irradiance ;
- IBL prefilter ;
- BRDF LUT ;
- Reflection probes ;
- Probe blending volumes ;
- Chunk irradiance probes ;
- Volumetric lightmaps/probes ;
- Forward+ light culling ;
- Clustered lights ;
- Light priority ;
- Light LOD ;
- Local light shadow atlas ;
- Cascaded shadow maps ;
- Stable cascade snapping ;
- PCF shadows ;
- PCSS approximation ;
- Contact shadows ;
- Capsule shadows ;
- Emissive proxy lights ;
- Area light approximation ;
- Tube light approximation ;
- Flicker system ;
- Day/night lighting ;
- Weather lighting ;
- Cave lighting ;
- Interior lighting ;
- Biome ambient gradients ;
- Fog lighting ;
- Volumetric fog ;
- God ray approximation ;
- GTAO ;
- GTSO/specular occlusion ;
- SSR ;
- SSGI optional ;
- Exposure ;
- Tonemapping ;
- Bloom ;
- Color grading ;
- Debug heatmaps.

---

## 49. Conclusion

Le point 9 est un pilier central pour IsoWorld. Les systèmes terrain, props, biomes, météo, RPG et animation ne produiront un monde crédible que si les surfaces et lumières réagissent de manière cohérente.

La recommandation est de construire un pipeline par couches :

1. **PBR propre et validé**.
2. **Matériaux procéduraux compilés, pas improvisés en shader géant**.
3. **Terrain layered et triplanar pour verticalité**.
4. **Surface states dynamiques** : humide, neige, boue, poussière, mousse.
5. **Forward+/clustered lighting** pour beaucoup de lumières sans coût explosif.
6. **CSM + shadow atlas** pour ombres efficaces.
7. **IBL + probes + AO** pour compenser l’absence de ray tracing.
8. **Virtual/sparse textures plus tard**, quand le pipeline classique atteint ses limites.
9. **Debug tooling dès le début**, sinon le rendu deviendra impossible à maîtriser.

Le système final doit permettre qu’un même rocher, une même route, une même forêt ou un même bâtiment puisse changer radicalement selon :

- le seed ;
- le biome ;
- la météo ;
- la saison ;
- l’altitude ;
- l’humidité ;
- l’époque RPG ;
- l’âge du monde ;
- l’activité du joueur ;
- les règles narratives du monde.

C’est cette combinaison qui donnera à IsoWorld une identité visuelle forte : un monde procédural qui ne se contente pas de générer de la géométrie, mais qui génère des **surfaces vivantes** et une **lumière systémique**.

---

## 50. Bibliographie et ressources

### Metal / Apple

- [Apple Metal](https://developer.apple.com/metal/)
- [Apple Metal Sample Code](https://developer.apple.com/metal/sample-code/)
- [Improving CPU performance by using argument buffers](https://developer.apple.com/documentation/metal/improving-cpu-performance-by-using-argument-buffers)
- [Reading and writing to sparse textures](https://developer.apple.com/documentation/metal/reading-and-writing-to-sparse-textures)
- [Rendering a scene with Forward Plus lighting using tile shaders](https://developer.apple.com/documentation/Metal/rendering-a-scene-with-forward-plus-lighting-using-tile-shaders)
- [Transform your geometry with Metal mesh shaders](https://developer.apple.com/videos/play/wwdc2022/10162/)
- [Using the Metal 4 compilation API](https://developer.apple.com/documentation/metal/using-the-metal-4-compilation-api)
- [Understanding the Metal 4 core API](https://developer.apple.com/documentation/Metal/understanding-the-metal-4-core-api)

### PBR / material models

- [Physically Based Rendering in Filament](https://google.github.io/filament/Filament.md.html)
- [Moving Frostbite to Physically Based Rendering](https://seblagarde.wordpress.com/2015/07/14/siggraph-2014-moving-frostbite-to-physically-based-rendering/)
- [Frostbite PBR course notes](https://seblagarde.files.wordpress.com/2015/07/course_notes_moving_frostbite_to_pbr_v32.pdf)
- [OpenPBR Surface](https://academysoftwarefoundation.github.io/OpenPBR/)
- [glTF 2.0 Specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
- [UsdPreviewSurface Specification](https://openusd.org/release/spec_usdpreviewsurface.html)
- [MaterialX](https://materialx.org/)
- [MaterialX Specification](https://github.com/AcademySoftwareFoundation/MaterialX/blob/main/documents/Specification/MaterialX.Specification.md)

### Procedural materials / datasets

- [Adobe Substance 3D Designer User Guide](https://experienceleague.adobe.com/en/docs/substance-3d-designer/using/home)
- [Adobe PBR Guide Part 1](https://www.adobe.com/learn/substance-3d-designer/web/the-pbr-guide-part-1)
- [Adobe PBR Guide Part 2](https://www.adobe.com/learn/substance-3d-designer/web/the-pbr-guide-part-2)
- [MatSynth: A Modern PBR Materials Dataset](https://arxiv.org/abs/2401.06056)
- [TexPro: Text-guided PBR Texturing with Procedural Material Modeling](https://arxiv.org/abs/2410.15891)

### Virtual texturing / terrain surfaces

- [Unreal Streaming Virtual Texturing](https://dev.epicgames.com/documentation/unreal-engine/streaming-virtual-texturing-in-unreal-engine)
- [Unreal Runtime Virtual Texturing](https://dev.epicgames.com/documentation/unreal-engine/runtime-virtual-texturing-in-unreal-engine)
- [GPU-Driven Rendering Pipelines, SIGGRAPH 2015](https://advances.realtimerendering.com/s2015/aaltonenhaar_siggraph2015_combined_final_footer_220dpi.pdf)

### Lighting / GI / AO

- [Unreal Volumetric Lightmaps](https://dev.epicgames.com/documentation/unreal-engine/volumetric-lightmaps-in-unreal-engine)
- [Unreal Global Illumination](https://dev.epicgames.com/documentation/unreal-engine/global-illumination-in-unreal-engine)
- [Unity Adaptive Probe Volumes](https://docs.unity3d.com/Packages/com.unity.render-pipelines.high-definition%4017.0/manual/probevolumes-concept.html)
- [Practical Real-Time Strategies for Accurate Indirect Occlusion](https://research.activision.com/publications/archives/practical-real-time-strategies-for-accurate-indirect-occlusion)
- [GTAO paper PDF](https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf)
- [XeGTAO](https://github.com/GameTechDev/XeGTAO)
- [GPU Gems 3 — High-Quality Ambient Occlusion](https://developer.nvidia.com/gpugems/gpugems3/part-ii-light-and-shadows/chapter-12-high-quality-ambient-occlusion)
- [Scaling Probe-Based Real-Time Dynamic Global Illumination for Production](https://arxiv.org/abs/2009.10796)
