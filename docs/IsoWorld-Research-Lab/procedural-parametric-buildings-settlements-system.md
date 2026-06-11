# Nouveau Step — Système de bâtiments, structures, villages, villes, camps et usines procéduraux/paramétriques

**Projet : IsoWorld**  
**Document dédié uniquement au système de bâtiments et structures procédurales**  
**Objectif : concevoir une architecture moderne, déterministe, versatile, haute qualité, intégrée naturellement au terrain et à la verticalité.**

---

## 0. Résumé exécutif

Le système de bâtiments d’IsoWorld ne doit pas être un simple générateur de maisons posées sur un terrain aplati. Il doit devenir une couche complète de génération architecturale et urbaine, capable de produire :

- des bâtiments individuels procéduraux ;
- des structures visitables ou non visitables ;
- des ruines, camps, villages, villes, zones industrielles, usines, ports, bases, forteresses, stations, réseaux souterrains ;
- des architectures qui s’adaptent au relief, aux falaises, aux pentes, aux rivières, aux grottes, aux biomes, aux époques, aux cultures et aux règles RPG du monde ;
- des villes qui émergent d’une hiérarchie claire : **site → réseau → parcelles → bâtiments → modules → détails → gameplay** ;
- un rendu performant par instancing, HLOD, clusters, impostors, virtual/sparse textures et données runtime compactes.

La recommandation principale est de créer un système nommé ici :

> **ISAS — IsoWorld Settlement & Architecture System**

ISAS doit être déterministe par seed, data-driven, authorable, testable et optimisé pour Swift/Metal sur Apple Silicon.  
Le système doit combiner plusieurs approches modernes :

1. **Shape grammars / CGA-like rules** pour les façades, volumes, toitures et bâtiments.
2. **Graphes procéduraux type PCG** pour les points, parcelles, contraintes, sous-graphes et règles d’environnement.
3. **Générateurs Houdini-like / HDA-like** pour transformer des volumes simples en bâtiments détaillés.
4. **WFC / constraint solving** pour certains assemblages modulaires, surtout intérieurs, villages compacts, donjons, usines et structures répétitives.
5. **Simulation légère / agent-based planning** pour les routes, fonctions urbaines, croissance de villages et zones d’activité.
6. **ECS/data-oriented runtime** pour afficher et simuler beaucoup de structures sans coût CPU/GPU excessif.
7. **Adaptation au terrain multi-stratégies** : fondations, pilotis, terrasses, murs de soutènement, escaliers, ponts, passerelles, tunnels, structures suspendues, façades creusées dans la roche, bâtiments à flanc de falaise.

---

## 1. Références modernes et enseignements utiles

### 1.1 CityEngine / CGA / shape grammars

CityEngine est une référence historique pour la modélisation procédurale urbaine. Son principe : appliquer des règles CGA à des formes 2D pour générer des modèles 3D. Les règles peuvent extruder, découper, appliquer des textures, générer des façades et enrichir des formes simples jusqu’à obtenir des bâtiments détaillés.

**Enseignement pour IsoWorld :**

- Un bâtiment doit pouvoir partir d’une empreinte 2D ou d’un volume simple.
- Les règles doivent être incrémentales, inspectables et paramétrables.
- Le système doit séparer :
  - `Footprint`
  - `Massing`
  - `FloorSplit`
  - `FacadeSplit`
  - `RoofRule`
  - `AttachmentRule`
  - `MaterialRule`
  - `GameplayRule`

Dans IsoWorld, on ne doit pas copier CGA tel quel, mais créer une grammaire plus adaptée au jeu temps réel et au monde généré par chunks.

### 1.2 Houdini Labs Building Generator

Houdini Labs Building Generator transforme des volumes de blockout simples en bâtiments détaillés via modules. Il découpe les volumes en étages, identifie murs, coins, corniches, régions de façade, puis remplace ces régions par des modules haute résolution.

**Enseignement pour IsoWorld :**

- Le workflow idéal : générer d’abord un **proxy bas niveau** puis l’enrichir.
- Les bâtiments doivent être composés de modules nommés :
  - murs ;
  - fenêtres ;
  - coins convexes/concaves ;
  - portes ;
  - corniches ;
  - balcons ;
  - toitures ;
  - supports ;
  - détails.
- Les artistes ou outils futurs doivent pouvoir fournir des bibliothèques de modules, mais les proportions, répétitions, variantes, salissures et adaptations restent procédurales.
- Les modules doivent être instanciés autant que possible pour réduire le coût GPU.

### 1.3 Unreal PCG Framework et City Sample

Unreal PCG montre l’importance des graphes procéduraux extensibles pour générer des bâtiments, biomes et mondes complets. Le City Sample montre une chaîne Houdini → données urbaines → Unreal, avec génération de ville, routes, zones, trafic, IA et audio.

**Enseignement pour IsoWorld :**

- La ville ne doit pas être seulement géométrique. Elle doit produire des données :
  - routes ;
  - zones ;
  - intersections ;
  - bâtiments ;
  - points d’entrée ;
  - navmesh ;
  - spawn points ;
  - audio zones ;
  - traffic lanes ;
  - gameplay markers ;
  - occlusion cells ;
  - LOD/HLOD groups.
- Le système de bâtiments doit sortir plusieurs représentations :
  - rendu proche ;
  - rendu lointain ;
  - collision ;
  - navigation ;
  - interaction ;
  - simulation ;
  - debug.

### 1.4 WFC, constraint solving et assemblage modulaire

Wave Function Collapse fonctionne bien quand il existe une bibliothèque de tuiles/modules et des règles d’adjacence. Il est particulièrement utile pour :

- intérieurs modulaires ;
- villages serrés ;
- quartiers à style fort ;
- couloirs ;
- usines ;
- donjons ;
- réseaux souterrains ;
- containers ;
- câbles ;
- conduites ;
- ruines composées ;
- pièces mécaniques.

**Limite :** WFC pur devient lourd et fragile à grande échelle.  
**Approche recommandée :** utiliser WFC localement, jamais comme unique générateur global.

### 1.5 Agent-based city generation et LUTI

Des travaux récents sur la génération de villes utilisent des agents et des modèles land-use/transport pour obtenir des zones plus plausibles : résidentiel, commerce, industrie, loisirs, routes, accessibilité.

**Enseignement pour IsoWorld :**

- Une ville plausible doit être gouvernée par des besoins :
  - accès à l’eau ;
  - sécurité ;
  - énergie ;
  - ressources ;
  - commerce ;
  - culte ;
  - production ;
  - stockage ;
  - défense ;
  - transport ;
  - habitat ;
  - prestige.
- Les routes et les bâtiments ne doivent pas être placés indépendamment.
- Un village agricole, un camp de mineurs, une ville portuaire, une cité verticale ou une base futuriste n’ont pas la même logique d’organisation.

### 1.6 Metal et rendu moderne

Apple propose des samples Metal modernes utilisant indirect command buffers, sparse textures, variable rate rasterization, culling GPU, tile/deferred lighting, ambient occlusion, volumetric fog, cascaded shadow maps, argument buffers et rendu de terrain dynamique.

**Enseignement pour IsoWorld :**

- Les structures doivent être rendues par lots massifs :
  - instancing ;
  - argument buffers ;
  - indirect command buffers ;
  - GPU culling ;
  - HLOD ;
  - texture arrays/atlases ;
  - sparse/virtual textures.
- Le système de génération doit produire des données directement compatibles renderer :
  - `InstanceBuffer`
  - `MaterialID`
  - `ClusterID`
  - `HLODGroupID`
  - `OccluderProxy`
  - `CollisionProxy`
  - `NavProxy`

---

## 2. Objectifs de design pour IsoWorld

### 2.1 Objectifs fondamentaux

ISAS doit permettre de générer, avec une seed donnée :

- un bâtiment isolé ;
- une ferme ;
- un camp ;
- un village ;
- une ville ;
- une mégastructure ;
- une usine ;
- une base militaire ;
- un port ;
- une ruine ;
- un quartier souterrain ;
- un complexe industriel ;
- une cité verticale ;
- un réseau de ponts et passerelles ;
- une colonie futuriste ;
- une ville abandonnée ;
- un sanctuaire ;
- une infrastructure technique ;
- un réseau de tunnels ;
- un ensemble d’habitations à flanc de falaise.

Le système doit fonctionner sur un terrain non plat. Il doit respecter la topologie au lieu de l’effacer.

### 2.2 Contraintes IsoWorld

- Monde déterministe par seed.
- Chunks générés autour du joueur.
- Swift/Metal sur MacBook Pro M1.
- Pas de coût CPU massif à chaque frame.
- Structures visibles loin, mais détails seulement proches.
- Besoin d’intégration avec :
  - terrain ;
  - biomes ;
  - props procéduraux ;
  - météo ;
  - audio ;
  - RPG rules ;
  - nav/collision ;
  - UI/debug.
- Structures parfois visitables, parfois seulement décoratives.
- Verticalité forte : falaises, pentes, escaliers, cordes, passerelles, ponts, terrasses.

### 2.3 Principe central

> IsoWorld doit générer des structures comme si elles avaient été construites par des entités qui comprenaient le terrain, les matériaux disponibles, les dangers, l’époque, la culture, les ressources et les usages.

Cela implique des règles d’intention, pas seulement des règles géométriques.

---

## 3. Architecture proposée : ISAS

### 3.1 Vue d’ensemble

```text
WorldSeed
  ↓
WorldArchitectureDNA
  ↓
SettlementIntentGraph
  ↓
SiteSelectionSystem
  ↓
TerrainIntegrationAnalyzer
  ↓
AccessNetworkGenerator
  ↓
PlotAndDistrictGenerator
  ↓
BuildingMassingGenerator
  ↓
TerrainAdaptiveStructureSolver
  ↓
Facade/Roof/Interior/Attachment Generators
  ↓
Material/Weathering/Detail Generators
  ↓
RuntimeRepresentations
  ├─ Render instances
  ├─ HLOD clusters
  ├─ Collision proxies
  ├─ Nav links
  ├─ Occlusion cells
  ├─ Audio zones
  ├─ Gameplay markers
  └─ Debug layers
```

### 3.2 Les grandes couches

#### Couche 0 — WorldArchitectureDNA

Détermine les grandes lois architecturales du monde.

Exemples de paramètres :

```swift
struct WorldArchitectureDNA {
    let seed: UInt64
    let era: EraProfile
    let techLevel: TechLevel
    let dominantMaterials: [MaterialFamily]
    let settlementDensity: Float
    let verticalityBias: Float
    let ruinBias: Float
    let industrialization: Float
    let nomadicBias: Float
    let defensiveBias: Float
    let sacredArchitectureBias: Float
    let roadComplexity: Float
    let undergroundBias: Float
    let biomeAdaptationStrength: Float
    let proceduralStyleFamilies: [ArchitectureStyleFamily]
}
```

Cette couche fait le lien avec le système RPG déterministe : une seed peut générer un monde sans villes, un monde de campements nomades, un monde industriel, un monde post-technologique, une civilisation souterraine, etc.

#### Couche 1 — SettlementIntentGraph

Avant de générer une ville, on génère une intention.

Exemples :

- `FishingVillage`
- `MiningCamp`
- `CliffMonastery`
- `RiverTradeTown`
- `MountainFortress`
- `IndustrialFactoryComplex`
- `NomadicSeasonalCamp`
- `AbandonedTechRuin`
- `AgriculturalHamlet`
- `MilitaryForwardBase`
- `ReligiousPilgrimageHub`
- `DesertOasisMarket`
- `FrozenResearchOutpost`
- `SkyBridgeSettlement`
- `UndergroundRefuge`
- `VolcanicForgeCity`

Chaque intention définit :

- population approximative ;
- fonctions nécessaires ;
- dépendances ;
- besoins d’accès ;
- préférence de terrain ;
- niveau de verticalité ;
- degré de visitabilité ;
- style architectural ;
- risques environnementaux ;
- ressources locales ;
- densité de props ;
- sons/FX associés ;
- niveau de simulation.

#### Couche 2 — SiteSelectionSystem

Le système choisit ou valide des sites possibles selon des cartes dérivées du terrain :

- hauteur ;
- pente ;
- courbure ;
- rugosité ;
- proximité eau douce ;
- proximité littoral ;
- proximité ressources ;
- exposition au soleil ;
- exposition au vent ;
- risque avalanche ;
- risque inondation ;
- risque glissement ;
- distance aux routes existantes ;
- visibilité stratégique ;
- proximité biomes ;
- présence de falaise exploitable ;
- présence de cavernes ;
- distance à autres settlements ;
- valeur défensive ;
- valeur commerciale ;
- valeur sacrée/mythique.

Score simplifié :

```text
siteScore =
    waterAccess * needWater
  + resourceAccess * needResource
  + slopeCompatibility
  + biomeCompatibility
  + defenseValue * defensiveBias
  + tradeValue * tradeBias
  + verticalFeatureValue * verticalityBias
  - floodRisk * floodAversion
  - avalancheRisk * mountainAversion
  - generationCostPenalty
```

#### Couche 3 — TerrainIntegrationAnalyzer

Analyse très fine du terrain autour du site.

Sorties :

```swift
struct TerrainSupportMap {
    let slope: Field2D
    let curvature: Field2D
    let roughness: Field2D
    let normal: Field2D<Vector3>
    let height: Field2D
    let material: Field2D<GroundMaterialID>
    let waterDistance: Field2D
    let cliffFaces: [VerticalSurfacePatch]
    let caveEntrances: [CaveAnchor]
    let stableTerraces: [TerraceCandidate]
    let bridgeAnchors: [BridgeAnchor]
    let retainingWallLines: [Spline]
}
```

Cette couche est essentielle pour éviter le “village posé sur un carré plat”.

#### Couche 4 — AccessNetworkGenerator

Génère :

- chemins ;
- routes ;
- ponts ;
- ruelles ;
- escaliers ;
- rampes ;
- passerelles ;
- tunnels ;
- échelles ;
- cordes ;
- ascenseurs primitifs ou futuristes ;
- funiculaires ;
- tyroliennes ;
- quais ;
- rails ;
- conduites.

Les chemins doivent suivre des **least-cost paths** :

```text
pathCost =
    distance
  + slopePenalty
  + waterCrossingPenalty
  + cliffPenalty
  + vegetationDensityPenalty
  + constructionCost
  - existingPathBonus
  - scenicOrSacredBonus
```

Pour terrain très pentu :

- route en lacets ;
- escaliers ;
- passerelles ;
- tunnel ;
- pont suspendu ;
- ascenseur vertical ;
- plateforme intermédiaire ;
- corde ou ladder ;
- bâtiment-pont.

#### Couche 5 — PlotAndDistrictGenerator

Génère les parcelles, quartiers et zones fonctionnelles.

Types de zones :

- résidentiel ;
- marché ;
- stockage ;
- agriculture ;
- élevage ;
- port ;
- industrie ;
- énergie ;
- religieux ;
- militaire ;
- administratif ;
- artisanat ;
- savoir/éducation ;
- ruines ;
- bidonville ;
- prestige ;
- souterrain ;
- vertical ;
- danger/interdit.

Les parcelles ne sont pas nécessairement planes. Une parcelle peut être :

- plate ;
- inclinée ;
- en terrasses ;
- fragmentée ;
- suspendue ;
- attachée à une falaise ;
- traversée par un ruisseau ;
- partiellement sur pilotis ;
- moitié grotte, moitié extérieur ;
- multi-niveaux.

#### Couche 6 — BuildingMassingGenerator

Génère les volumes de base.

Entrées :

- footprint ;
- fonction ;
- style ;
- époque ;
- matériaux ;
- pente ;
- orientation ;
- densité urbaine ;
- contraintes de vue ;
- contraintes d’accès ;
- niveau de visitabilité.

Sorties :

- masses ;
- étages ;
- toiture ;
- noyaux verticaux ;
- points d’entrée ;
- volumes secondaires ;
- volumes techniques ;
- volumes intérieurs ;
- supports.

#### Couche 7 — TerrainAdaptiveStructureSolver

C’est une des couches les plus importantes du système.

Elle décide comment une structure se pose sur le relief :

1. **Foundation cut léger**  
   Micro-ajustement local, limité, pas de flatten massif.

2. **Stepped foundation**  
   Fondations en marches pour pente modérée.

3. **Terrace embedding**  
   Création de terrasses naturelles avec murs de soutènement.

4. **Stilts / pilotis**  
   Habitations sur pieux pour marais, pente, littoral, lac, banquise.

5. **Rock anchors**  
   Ancrage dans falaise ou paroi rocheuse.

6. **Cantilever**  
   Structure en porte-à-faux.

7. **Suspended structure**  
   Plateformes suspendues, ponts, cabanes accrochées.

8. **Cave carved structure**  
   Façade construite devant une cavité ou bâtiment creusé.

9. **Bridge-building**  
   Bâtiment qui traverse un ravin, une route, un canal.

10. **Floating / amphibious**  
    Pontons, villages flottants, structures sur barges.

11. **Buried / partially buried**  
    Habitations semi-enterrées, bunkers, caves, igloos.

12. **Retaining wall system**  
    Murs de soutènement générés automatiquement.

13. **Slope-following modular structure**  
    Structure segmentée suivant la pente.

14. **Vertical stack settlement**  
    Architecture empilée sur falaise, avec escaliers/échelles/passerelles.

#### Couche 8 — Facade, Roof, Interior, Detail Generators

Cette couche transforme les volumes en bâtiments crédibles.

Sous-systèmes :

- `FacadeGrammar`
- `RoofGrammar`
- `DoorWindowSolver`
- `BalconyGenerator`
- `SupportGenerator`
- `InteriorLayoutGenerator`
- `StairGenerator`
- `DecorationScatter`
- `DamageWeatheringGenerator`
- `MaterialVariationGenerator`
- `LightingSocketGenerator`
- `AudioEmitterSocketGenerator`
- `GameplaySocketGenerator`

#### Couche 9 — RuntimeRepresentationBuilder

Produit des représentations différentes selon usage :

```text
GeneratedBuilding
  ├─ RenderLOD0
  ├─ RenderLOD1
  ├─ RenderLOD2
  ├─ HLODProxy
  ├─ Impostor
  ├─ CollisionSimple
  ├─ CollisionDetailed
  ├─ NavMeshSurface
  ├─ NavLinks
  ├─ InteriorStreamingCells
  ├─ AudioOcclusionProxy
  ├─ OcclusionProxy
  ├─ GameplaySockets
  └─ DebugInfo
```

---

## 4. Hiérarchie de génération recommandée

Il faut éviter de générer une ville directement depuis le bruit.  
La hiérarchie doit être explicite :

```text
World
  └── Region
      └── SettlementCluster
          └── Settlement
              ├── District
              │   ├── Block / Terrace / Platform
              │   │   ├── Plot
              │   │   │   ├── Building
              │   │   │   │   ├── Mass
              │   │   │   │   ├── Floor
              │   │   │   │   ├── Room
              │   │   │   │   ├── FacadeCell
              │   │   │   │   ├── RoofPart
              │   │   │   │   ├── Attachment
              │   │   │   │   └── Detail
              │   │   │   └── Yard / Props / Vegetation
              │   │   └── Street Segment
              │   └── Public Space
              └── Infrastructure Network
```

Cette hiérarchie rend le système :

- contrôlable ;
- debugable ;
- streamable ;
- compatible chunks ;
- compatible LOD ;
- compatible gameplay ;
- extensible.

---

## 5. Génération d’un bâtiment individuel

### 5.1 Pipeline bâtiment

```text
BuildingIntent
  ↓
Footprint
  ↓
Massing
  ↓
Terrain support solution
  ↓
Structural core
  ↓
Floor split
  ↓
Facade grammar
  ↓
Roof grammar
  ↓
Interior graph
  ↓
Attachment generation
  ↓
Materials
  ↓
Weathering / aging
  ↓
Collision / nav / render data
```

### 5.2 BuildingIntent

Exemples :

```swift
enum BuildingFunction {
    case house
    case hut
    case farm
    case inn
    case shop
    case workshop
    case warehouse
    case factory
    case temple
    case tower
    case barracks
    case bunker
    case lab
    case powerStation
    case dockHouse
    case greenhouse
    case ruin
}
```

Le `BuildingIntent` contient :

- fonction ;
- capacité ;
- importance ;
- budget visuel ;
- visitabilité ;
- style ;
- époque ;
- matériaux ;
- niveau de richesse ;
- état d’usure ;
- niveau de danger ;
- nombre d’entrées ;
- exigences de terrain ;
- exigences de réseau.

### 5.3 Footprint

Types d’empreintes :

- rectangle ;
- L ;
- U ;
- cour intérieure ;
- cercle ;
- polygone irrégulier ;
- radial ;
- croix ;
- anneau ;
- organique ;
- spline ;
- multi-polygon ;
- fracturé ;
- cliff-adapted ;
- cave-mouth ;
- bridge-span ;
- platform cluster.

### 5.4 Massing

Le massing définit le volume général :

- extrudé simple ;
- étage par étage ;
- volumes empilés ;
- volumes décalés ;
- tour ;
- dôme ;
- hangar ;
- nef ;
- serre ;
- bunker semi-enterré ;
- tour modulaire ;
- empilement vertical ;
- structure en arche ;
- structure suspendue ;
- structure annulaire ;
- mégastructure segmentée.

### 5.5 Règles de façade

Chaque façade est une grille ou une séquence adaptative :

```text
Facade
  ├─ GroundBand
  ├─ MainFloors
  ├─ SpecialFloor
  ├─ TopBand
  ├─ Corners
  ├─ Entrances
  ├─ Windows
  ├─ Balconies
  ├─ Damage
  └─ Decals
```

Paramètres :

- largeur de travée ;
- hauteur d’étage ;
- rythme des fenêtres ;
- densité d’ouvertures ;
- profondeur des encadrements ;
- type de corniche ;
- balcon oui/non ;
- style de garde-corps ;
- stores/volets ;
- câbles ;
- tuyaux ;
- panneaux ;
- végétation murale ;
- salissure ;
- fissures ;
- patchs de réparation.

### 5.6 Toitures

Types de toitures générables :

- toit plat ;
- toit terrasse ;
- toit à deux pentes ;
- toit à quatre pentes ;
- toit mansardé ;
- toit en appentis ;
- toit conique ;
- toit en dôme ;
- toit en tuiles ;
- toit en chaume ;
- toit métallique ;
- toit végétalisé ;
- toit solaire ;
- toit industriel à sheds ;
- toiture enneigée ;
- toiture effondrée ;
- toiture de fortune ;
- toit technique avec antennes ;
- toit sci-fi à panneaux ;
- toit de bunker camouflé ;
- toit organique/biomimétique.

### 5.7 Intérieurs

Niveaux de visitabilité :

1. **Non visitable**
   - façade uniquement ;
   - collision simple ;
   - fenêtres opaques ou fake interior.

2. **Semi-visitable**
   - entrée, hall, pièce principale ;
   - reste représenté par volumes fermés.

3. **Partiellement visitable**
   - quelques pièces utiles ;
   - portes verrouillées ou décoratives ;
   - étage simplifié.

4. **Totalement visitable**
   - room graph complet ;
   - escaliers ;
   - props ;
   - lighting ;
   - nav/collision.

5. **Instance intérieure**
   - extérieur dans le monde ;
   - intérieur streamé/instancié à l’entrée.

6. **Hybrid nested chunks**
   - intérieur chunké comme le monde ;
   - utilisé pour mégastructures, donjons, usines.

Générateurs d’intérieurs :

- BSP simple ;
- room graph ;
- corridor graph ;
- WFC local ;
- grammar by function ;
- storylet rooms ;
- prefab paramétrique ;
- mix room-templates + randomization.

---

## 6. Adaptation au terrain et à la verticalité

### 6.1 Règle absolue

> On ne fait pas un rectangle plat sous chaque ville.

Le terrain doit rester vivant. Les structures s’adaptent au terrain, et le terrain peut être légèrement modifié seulement quand c’est plausible.

### 6.2 Types d’adaptation

#### 6.2.1 Pente légère

- fondations ajustées ;
- socle semi-enterré ;
- accès par petites marches ;
- drainage naturel ;
- façade aval plus haute.

#### 6.2.2 Pente moyenne

- bâtiment en demi-niveaux ;
- terrasses ;
- murs de soutènement ;
- escalier extérieur ;
- cour inclinée ;
- passerelle d’accès.

#### 6.2.3 Pente forte

- volumes séparés ;
- plateformes ;
- pilotis ;
- escaliers en lacets ;
- ancrage rocheux ;
- stockage sous bâtiment ;
- murs de soutènement imposants.

#### 6.2.4 Falaise

- bâtiment accroché à la paroi ;
- monastère vertical ;
- mine ;
- escalier taillé ;
- corde ;
- ascenseur primitif ;
- passerelle suspendue ;
- pont de corde ;
- habitats troglodytes ;
- belvédères ;
- défenses naturelles.

#### 6.2.5 Ravin

- pont habité ;
- maisons sur piliers ;
- passerelles ;
- moulins ;
- aqueduc ;
- funiculaire ;
- quartiers séparés reliés par ponts.

#### 6.2.6 Rivière / marais

- pilotis ;
- quais ;
- plateformes flottantes ;
- pontons ;
- maisons amphibies ;
- digues ;
- canaux ;
- moulins à eau ;
- maisons de pêcheurs.

#### 6.2.7 Banquise / neige

- fondations isolées ;
- igloos ;
- modules semi-enterrés ;
- tunnels de neige ;
- structures compactes ;
- protection vent ;
- murs anti-congères.

#### 6.2.8 Désert

- patios ;
- ruelles étroites ;
- murs épais ;
- ombre ;
- citernes ;
- tours à vent ;
- fondations anti-sable ;
- structures semi-enterrées.

#### 6.2.9 Volcanique

- plateformes sur roche dure ;
- canaux de lave évités ou exploités ;
- ponts thermiques ;
- forges ;
- structures en basalte ;
- fumées ;
- murs épais.

#### 6.2.10 Souterrain / grotte

- façades sur entrée ;
- chambres creusées ;
- piliers naturels ;
- passerelles internes ;
- éclairage faible ;
- humidité ;
- acoustique spécifique ;
- ventilation.

### 6.3 Génération d’accès verticaux

Types :

- marches naturelles ;
- escaliers droits ;
- escaliers en colimaçon ;
- escaliers taillés dans roche ;
- escaliers extérieurs ;
- rampes ;
- passerelles ;
- échelles ;
- cordes ;
- chaînes ;
- ponts suspendus ;
- ascenseurs ;
- monte-charge ;
- rails inclinés ;
- funiculaires ;
- tyroliennes ;
- plateformes mécaniques ;
- tunnels ;
- cheminées verticales ;
- puits ;
- conduites grimpables.

Chaque accès doit produire :

- mesh ;
- collision ;
- nav link ;
- gameplay marker ;
- animation hint ;
- audio material ;
- danger rating.

---

## 7. Génération de villages, villes et settlements

### 7.1 Pipeline settlement

```text
SettlementIntent
  ↓
Site candidates
  ↓
Site scoring
  ↓
Core anchor selection
  ↓
Main access paths
  ↓
Functional zones
  ↓
District graph
  ↓
Plot subdivision
  ↓
Building intents
  ↓
Building generation
  ↓
Street furniture / props
  ↓
Nav / collision / audio / gameplay
  ↓
LOD / HLOD / streaming
```

### 7.2 SettlementIntent examples

```swift
struct SettlementIntent {
    let type: SettlementType
    let populationScale: Float
    let functionWeights: FunctionWeights
    let resourceDrivers: [ResourceDriver]
    let era: EraProfile
    let style: ArchitectureStyleFamily
    let defenseNeed: Float
    let tradeNeed: Float
    let religiousNeed: Float
    let industrialNeed: Float
    let verticalityNeed: Float
    let visitabilityProfile: VisitabilityProfile
}
```

### 7.3 Croissance naturelle

Approche recommandée :

1. Placer le noyau :
   - source d’eau ;
   - croisement ;
   - ressource ;
   - port ;
   - pont ;
   - sanctuaire ;
   - mine ;
   - forteresse.

2. Générer les accès primaires :
   - route vers eau ;
   - route vers ressources ;
   - route vers commerce ;
   - route défensive ;
   - route verticale.

3. Placer les fonctions indispensables :
   - habitations ;
   - stockage ;
   - production ;
   - marché ;
   - lieu social ;
   - défense ;
   - énergie.

4. Étendre par anneaux ou par contraintes :
   - ancien noyau dense ;
   - extensions ;
   - zones pauvres ;
   - zones riches ;
   - industrie en aval/extérieur ;
   - agriculture autour ;
   - port sur eau ;
   - fort en hauteur.

5. Vieillir :
   - réparations ;
   - ruines ;
   - extensions illégales ;
   - murs cassés ;
   - routes redessinées ;
   - bâtiments abandonnés ;
   - végétation invasive.

---

## 8. Longue liste de structures générables

Cette section doit servir de base de données conceptuelle. Chaque entrée pourra devenir un `StructureRecipe`.

### 8.1 Habitations primitives et naturelles

- abri sous roche ;
- hutte de branches ;
- hutte de feuilles ;
- hutte de boue ;
- cabane en rondins ;
- cabane sur pilotis ;
- cabane de chasseur ;
- cabane de pêcheur ;
- cabane de berger ;
- cabane de trappeur ;
- tente simple ;
- tente nomade ;
- tente cérémonielle ;
- yourte ;
- tipi ;
- igloo ;
- maison semi-enterrée ;
- maison troglodyte ;
- maison en terre crue ;
- maison en adobe ;
- maison de roseaux ;
- maison flottante primitive ;
- abri de survie ;
- abri de naufragé ;
- campement temporaire ;
- cercle de tentes ;
- camp saisonnier.

### 8.2 Habitations rurales

- ferme isolée ;
- ferme à cour ;
- grange ;
- étable ;
- bergerie ;
- porcherie ;
- poulailler ;
- remise ;
- hangar agricole ;
- séchoir à foin ;
- silo ;
- moulin à vent ;
- moulin à eau ;
- cabane de verger ;
- maison de vigneron ;
- cave à vin ;
- pressoir ;
- serre ;
- jardin clos ;
- puits couvert ;
- citerne ;
- four à pain ;
- fumoir ;
- fromagerie ;
- lavoir ;
- petite chapelle rurale ;
- enclos ;
- palissade agricole ;
- ruche géante ;
- aqueduc rural ;
- terrasse agricole habitée.

### 8.3 Villages

- hameau de montagne ;
- village de vallée ;
- village côtier ;
- village lacustre ;
- village sur pilotis ;
- village de pêcheurs ;
- village minier ;
- village forestier ;
- village agricole ;
- village fortifié ;
- village troglodyte ;
- village de falaise ;
- village nomade temporaire ;
- village abandonné ;
- village brûlé ;
- village reconstruit ;
- village autour d’un arbre géant ;
- village autour d’une source ;
- village autour d’un sanctuaire ;
- village sur pont ;
- village en terrasses ;
- village de marais ;
- village sous la neige ;
- village désertique ;
- village de caravanes ;
- village vertical suspendu ;
- village souterrain.

### 8.4 Maisons urbaines

- maison de ville étroite ;
- maison mitoyenne ;
- maison à étage ;
- maison à colombages ;
- maison de pierre ;
- maison de brique ;
- maison en pisé ;
- maison à patio ;
- maison marchande ;
- maison-atelier ;
- immeuble bas ;
- immeuble haussmannien-like ;
- immeuble dense ;
- immeuble modulaire ;
- immeuble délabré ;
- immeuble post-apocalyptique ;
- immeuble suspendu ;
- immeuble à passerelles ;
- immeuble sur dalle ;
- immeuble futuriste ;
- mégabloc résidentiel ;
- habitat capsule ;
- habitat vertical organique ;
- habitat biomimétique ;
- résidence fortifiée ;
- maison riche ;
- maison pauvre ;
- maison squattée ;
- maison abandonnée ;
- maison inondée.

### 8.5 Commerces

- échoppe ;
- marché couvert ;
- étal de rue ;
- auberge ;
- taverne ;
- hôtel ;
- relais ;
- boutique d’artisan ;
- forge ;
- boulangerie ;
- boucherie ;
- poissonnerie ;
- herboristerie ;
- pharmacie ;
- librairie ;
- atelier de réparation ;
- magasin général ;
- boutique de luxe ;
- bazar ;
- caravansérail ;
- comptoir commercial ;
- entrepôt marchand ;
- halle ;
- banque ;
- bureau de poste ;
- gare marchande ;
- station-service ;
- centre commercial ;
- galerie couverte ;
- kiosque ;
- marché noir ;
- boutique futuriste automatisée.

### 8.6 Artisanat et production légère

- forge ;
- fonderie artisanale ;
- poterie ;
- verrerie ;
- scierie ;
- tannerie ;
- menuiserie ;
- atelier textile ;
- atelier de cordage ;
- atelier de filets ;
- atelier de bijoux ;
- atelier mécanique ;
- brasserie ;
- distillerie ;
- fumoir ;
- imprimerie ;
- atelier d’armes ;
- atelier d’armures ;
- laboratoire alchimique ;
- atelier électronique ;
- atelier robotique ;
- fablab ;
- atelier de drones ;
- atelier de véhicules ;
- station de recharge.

### 8.7 Industrie lourde

- usine ;
- complexe industriel ;
- centrale thermique ;
- centrale hydroélectrique ;
- centrale solaire ;
- centrale éolienne ;
- centrale géothermique ;
- réacteur futuriste ;
- raffinerie ;
- aciérie ;
- fonderie lourde ;
- usine chimique ;
- usine textile ;
- usine alimentaire ;
- usine robotisée ;
- usine abandonnée ;
- usine partiellement effondrée ;
- usine sur falaise ;
- usine souterraine ;
- usine côtière ;
- pipeline station ;
- station de pompage ;
- bassin de décantation ;
- tour de refroidissement ;
- cheminée industrielle ;
- convoyeur ;
- grue ;
- entrepôt logistique ;
- dépôt ferroviaire ;
- hangar de maintenance ;
- chantier naval ;
- carrière ;
- mine à ciel ouvert ;
- mine souterraine ;
- complexe minier vertical.

### 8.8 Infrastructures de transport

- sentier ;
- route de terre ;
- route pavée ;
- route en bois ;
- route sur pilotis ;
- route de montagne ;
- route en lacets ;
- rue étroite ;
- boulevard ;
- avenue ;
- pont de pierre ;
- pont de bois ;
- pont suspendu ;
- pont habité ;
- pont ferroviaire ;
- pont futuriste ;
- passerelle ;
- escalier public ;
- rampe ;
- tunnel routier ;
- tunnel piéton ;
- tunnel ferroviaire ;
- tunnel minier ;
- gare ;
- station de métro ;
- quai ;
- port ;
- marina ;
- canal ;
- écluse ;
- aqueduc ;
- funiculaire ;
- téléphérique ;
- ascenseur urbain ;
- station de drones ;
- piste d’atterrissage ;
- spatioport ;
- anneau de transport ;
- hyperloop-like ;
- voie suspendue.

### 8.9 Eau, ports et littoral

- cabane de pêche ;
- port de pêche ;
- port marchand ;
- port militaire ;
- phare ;
- jetée ;
- quai ;
- ponton ;
- cale sèche ;
- chantier naval ;
- criée ;
- entrepôt côtier ;
- digue ;
- barrage ;
- écluse ;
- moulin à marée ;
- village flottant ;
- maison bateau ;
- plateforme offshore ;
- station de recherche marine ;
- ferme aquacole ;
- canal urbain ;
- pont canal ;
- station de pompage ;
- réservoir ;
- château d’eau ;
- bassin rituel ;
- bains publics ;
- égouts ;
- citerne souterraine ;
- fontaine ;
- station de purification ;
- usine de dessalement.

### 8.10 Militaire et défense

- palissade ;
- mur d’enceinte ;
- porte fortifiée ;
- tour de garde ;
- donjon ;
- fort ;
- château ;
- citadelle ;
- bastion ;
- caserne ;
- arsenal ;
- armurerie ;
- poste avancé ;
- bunker ;
- tranchée ;
- blockhaus ;
- rempart ;
- mur anti-crue défensif ;
- tour radar ;
- base militaire ;
- base souterraine ;
- base de montagne ;
- base côtière ;
- station anti-aérienne ;
- bunker nucléaire ;
- hangar militaire ;
- champ de mines visuel ;
- checkpoint ;
- prison ;
- camp fortifié ;
- mur de quarantaine ;
- tour automatisée ;
- bouclier énergétique ;
- forteresse volante ancrée ;
- citadelle de falaise.

### 8.11 Religieux, sacré, culturel

- autel ;
- sanctuaire ;
- chapelle ;
- église ;
- cathédrale ;
- temple ;
- monastère ;
- monastère de falaise ;
- mosquée-like fictive ;
- pagode-like fictive ;
- ziggourat ;
- pyramide ;
- cercle de pierres ;
- menhir ;
- dolmen ;
- tombe ;
- mausolée ;
- cimetière ;
- crypte ;
- catacombes ;
- bibliothèque sacrée ;
- observatoire ;
- oracle ;
- fontaine sacrée ;
- arbre sacré aménagé ;
- pont rituel ;
- escalier de pèlerinage ;
- cloître ;
- amphithéâtre ;
- théâtre ;
- musée ;
- académie ;
- école ;
- université ;
- archive ;
- salle des fêtes ;
- maison de guilde ;
- tribunal.

### 8.12 Administration et pouvoir

- mairie ;
- palais ;
- palais fortifié ;
- résidence du chef ;
- conseil tribal ;
- tribunal ;
- prison ;
- caserne civile ;
- bureau de douane ;
- poste de garde ;
- tour de signal ;
- ambassade ;
- archives ;
- bâtiment fiscal ;
- banque centrale ;
- ministère futuriste ;
- centre de contrôle ;
- data center administratif ;
- salle de commandement ;
- observatoire de surveillance ;
- centre de gestion météo ;
- poste de communication ;
- antenne relais.

### 8.13 Structures verticales et falaises

- escalier de falaise ;
- village accroché ;
- passerelle suspendue ;
- pont de corde ;
- ascenseur vertical ;
- treuil ;
- monte-charge ;
- plateforme d’observation ;
- cabane de paroi ;
- sanctuaire de falaise ;
- mine verticale ;
- puits ;
- tour ancrée ;
- cascade aménagée ;
- aqueduc vertical ;
- funiculaire ;
- habitat troglodyte ;
- balcon rocheux ;
- mur d’escalade aménagé ;
- route en corniche ;
- fort de falaise ;
- monastère suspendu ;
- usine hydro verticale ;
- colonie de ravin ;
- station scientifique sur paroi ;
- village en terrasses abruptes.

### 8.14 Souterrain, mines, cavernes

- mine primitive ;
- mine industrielle ;
- galerie ;
- puits de mine ;
- salle creusée ;
- bunker ;
- cave ;
- cave viticole ;
- catacombes ;
- égouts ;
- métro abandonné ;
- ville souterraine ;
- refuge ;
- laboratoire secret ;
- base enfouie ;
- crypte ;
- temple souterrain ;
- réseau de tunnels ;
- grotte aménagée ;
- ferme souterraine ;
- champignonnière ;
- réservoir souterrain ;
- prison souterraine ;
- marché souterrain ;
- gare souterraine ;
- complexe minier automatisé.

### 8.15 Camps et structures temporaires

- camp de chasseurs ;
- camp militaire ;
- camp de réfugiés ;
- camp de mineurs ;
- camp scientifique ;
- camp archéologique ;
- camp nomade ;
- camp de caravanes ;
- camp de bandits ;
- camp de pèlerins ;
- camp de bûcherons ;
- camp de pêche ;
- camp polaire ;
- camp désertique ;
- camp sur plage ;
- camp dans ruines ;
- camp suspendu dans arbres ;
- camp sur falaise ;
- camp de siège ;
- camp post-apocalyptique ;
- camp modulaire futuriste ;
- camp robotique.

### 8.16 Ruines et structures abandonnées

- maison effondrée ;
- village abandonné ;
- ville fantôme ;
- château ruiné ;
- temple ruiné ;
- usine abandonnée ;
- centrale abandonnée ;
- bunker ouvert ;
- navire échoué aménagé ;
- station orbitale écrasée ;
- tour cassée ;
- pont effondré ;
- route envahie ;
- quartier inondé ;
- ville ensablée ;
- village enseveli sous neige ;
- cité engloutie partielle ;
- ruine envahie par forêt ;
- ruine cristallisée ;
- ruine brûlée ;
- ruine toxique ;
- ruine radioactive fictive ;
- ruine technologique ;
- ruine cyclopéenne ;
- mégastructure morte.

### 8.17 Futuriste / science-fiction

- habitat capsule ;
- mégabloc ;
- tour modulaire ;
- spatioport ;
- station de drones ;
- hub de transport ;
- data center ;
- station énergétique ;
- dôme habitable ;
- serre géodésique ;
- laboratoire ;
- centre de cryogénie ;
- complexe orbital au sol ;
- ascenseur spatial ancré ;
- antenne géante ;
- ville sous dôme ;
- ville suspendue ;
- ville verticale ;
- fabrique robotique ;
- usine d’IA ;
- hangar de méchas ;
- station de terraformation ;
- base lunaire-like ;
- colonie martienne-like ;
- habitat sous-marin ;
- ville flottante high-tech ;
- bunker de survie ;
- citadelle énergétique ;
- prison automatisée ;
- archive numérique ;
- monument holographique.

### 8.18 Fantasy / mythique / étrange

Même si IsoWorld n’est pas nécessairement fantasy, le système RPG peut générer des mondes avec règles mythiques.

- tour de mage ;
- arbre-ville ;
- maison champignon ;
- village suspendu dans racines ;
- sanctuaire cristallin ;
- forge volcanique sacrée ;
- pont vivant ;
- temple flottant ;
- escalier impossible ;
- ville dans coquillage géant ;
- ruine cyclopéenne ;
- porte monumentale ;
- cercle rituel ;
- autel météoritique ;
- marché nomade mystique ;
- bibliothèque infinie stylisée ;
- forteresse d’obsidienne ;
- cité de glace ;
- cité sur dos de créature fossilisée ;
- village autour d’un cratère ;
- mine de cristaux ;
- tombeau labyrinthique ;
- palais organique ;
- prison dimensionnelle stylisée.

### 8.19 Structures de gameplay

- safe house ;
- checkpoint ;
- zone de craft ;
- forge spéciale ;
- atelier d’amélioration ;
- auberge ;
- hub de quête ;
- donjon ;
- arène ;
- tour d’observation ;
- puzzle building ;
- bâtiment escaladable ;
- bâtiment destructible partiel ;
- bâtiment avec intérieur secret ;
- passage caché ;
- cave secrète ;
- porte verrouillée ;
- ascenseur à réparer ;
- générateur à réactiver ;
- pont à abaisser ;
- barrage à ouvrir ;
- porte de ville ;
- camp ennemi ;
- base alliée ;
- marché dynamique ;
- poste de faction ;
- sanctuaire de sauvegarde ;
- lieu mythique ;
- structure liée à compétence.

---

## 9. Règles de génération et variantes

### 9.1 Axes de variation

Chaque structure peut varier selon :

- seed globale ;
- seed région ;
- seed settlement ;
- seed parcelle ;
- biome ;
- climat ;
- humidité ;
- altitude ;
- pente ;
- exposition au vent ;
- proximité eau ;
- ressource locale ;
- époque ;
- niveau technologique ;
- culture ;
- richesse ;
- densité ;
- fonction ;
- état politique ;
- niveau de danger ;
- âge ;
- maintenance ;
- guerre passée ;
- catastrophe ;
- ruine ;
- occupation actuelle ;
- faction ;
- objectif RPG ;
- style de monde ;
- niveau de magie/tech ;
- niveau d’industrialisation.

### 9.2 Exemple de Rule Stack

```text
BaseRecipe: MountainHouse
  + BiomeRule: Alpine
  + TerrainRule: SlopeMedium
  + CultureRule: StoneAndWood
  + EraRule: LowTech
  + WeatherRule: HeavySnow
  + EconomyRule: Poor
  + AgeRule: OldButMaintained
  + GameplayRule: ClimbableRoof
  = Maison alpine pauvre, robuste, en pierre/bois, toit pentu enneigé, accès par escalier latéral, stockage sous le plancher.
```

### 9.3 Rule categories

#### Site rules

- ne pas construire dans zone inondable sauf structure adaptée ;
- éviter pente trop forte sauf architecture verticale ;
- port uniquement sur eau navigable ;
- mine proche ressource ;
- forteresse sur hauteur stratégique ;
- marché proche route ;
- temple proche point sacré ;
- usine proche eau/énergie/transport ;
- ferme proche sol fertile ;
- village de falaise nécessite vertical surfaces.

#### Structural rules

- chaque bâtiment doit avoir au moins un accès ;
- chaque niveau visitable doit être relié ;
- chaque pont doit avoir deux ancrages valides ;
- chaque passerelle doit respecter une portée max ;
- chaque mur de soutènement doit avoir hauteur plausible ;
- chaque toiture doit évacuer eau/neige selon climat ;
- chaque bâtiment lourd ne doit pas reposer sur sol instable sans fondations spéciales.

#### Style rules

- matériaux locaux favorisés ;
- richesse augmente ornements ;
- pauvreté augmente réparations et modules hétérogènes ;
- climat froid favorise compacité et petites ouvertures ;
- climat chaud favorise patios/ombres/ventilation ;
- zone industrielle favorise répétition, tuyaux, hangars ;
- zone sacrée favorise axialité, monuments, hauteur symbolique ;
- ruines favorisent cassures, végétation, instabilité.

#### Gameplay rules

- structures importantes doivent être lisibles ;
- entrées principales visibles ;
- escalade possible seulement sur surfaces marquées ;
- chemin critique doit éviter génération impossible ;
- secrets possibles mais validés ;
- combat zones avec cover ;
- villages avec hubs sociaux ;
- vertical routes doivent générer nav links ;
- visitabilité choisie selon budget et importance.

---

## 10. Intégration naturelle dans l’environnement

### 10.1 Matériaux locaux

Le système doit choisir les matériaux selon biome et ressources :

- bois clair ;
- bois sombre ;
- bois humide ;
- pierre calcaire ;
- granit ;
- basalte ;
- grès ;
- argile ;
- terre crue ;
- brique ;
- métal rouillé ;
- métal propre ;
- béton ;
- verre ;
- fibre végétale ;
- chaume ;
- glace ;
- os/biomatériaux stylisés ;
- composites futuristes ;
- panneaux solaires ;
- textile ;
- cuir ;
- céramique.

### 10.2 Weathering

Chaque structure reçoit :

- salissures en bas de murs ;
- traces d’eau ;
- mousse ;
- neige accumulée ;
- sable accumulé ;
- poussière ;
- rouille ;
- fissures ;
- peinture écaillée ;
- réparations ;
- tags ;
- végétation invasive ;
- dégâts structurels ;
- variation couleur ;
- usure sur marches ;
- traces de fumée ;
- humidité.

Ces effets ne doivent pas forcément ajouter beaucoup de géométrie. Ils peuvent être générés par :

- vertex colors ;
- masks procéduraux ;
- decals ;
- material layers ;
- texture arrays ;
- trim sheets ;
- world-space noise ;
- curvature/ambient occlusion approximée ;
- height/slope masks.

### 10.3 Blending structure/terrain

À l’intersection bâtiment/terrain :

- gravats ;
- herbe déplacée ;
- boue ;
- neige tassée ;
- pierres de fondation ;
- murs bas ;
- marches ;
- drains ;
- racines ;
- planches ;
- échafaudage ;
- déchets ;
- végétation adaptée ;
- traces de passage.

Cela évite l’effet “objet posé”.

---

## 11. Structures visitables vs non visitables

### 11.1 Pourquoi différencier

Tout rendre visitable serait trop coûteux.  
Il faut classer les structures.

### 11.2 Classes

#### Class A — Vista only

Visible de loin, non interactive.

- HLOD/impostor ;
- aucune collision détaillée ;
- pas d’intérieur.

#### Class B — Exterior gameplay

Bâtiment solide avec collisions extérieures.

- portes fake ;
- fenêtres fake ;
- props autour ;
- peut servir de cover ;
- toit parfois accessible.

#### Class C — Partial interior

Intérieur limité.

- boutique ;
- maison importante ;
- poste de garde ;
- petite grotte ;
- atelier.

#### Class D — Full interior

Intérieur complet.

- donjons ;
- hubs ;
- base ;
- usine mission ;
- temple ;
- grande maison de quête.

#### Class E — Nested procedural space

Structure qui contient un espace procédural séparé.

- mine ;
- bunker ;
- ville souterraine ;
- mégastructure ;
- usine immense ;
- ruine labyrinthique.

### 11.3 Règle de budget

```text
visitabilityBudget =
    importanceToQuest
  + proximityToPlayerHub
  + uniqueness
  + gameplayPotential
  - performanceCost
```

---

## 12. Performance CPU/GPU

### 12.1 Génération

La génération doit être :

- asynchrone ;
- chunk-aware ;
- stable par seed ;
- incrémentale ;
- cacheable ;
- annulable ;
- priorisée par distance au joueur ;
- décomposable en jobs.

### 12.2 Runtime data compact

Ne pas garder des objets Swift lourds pour chaque fenêtre.  
Transformer les résultats en buffers compacts :

```swift
struct StructureInstanceGPU {
    var transform: simd_float4x4
    var meshID: UInt32
    var materialID: UInt32
    var variationID: UInt32
    var flags: UInt32
}
```

### 12.3 Rendu

Techniques recommandées :

- instancing massif ;
- mesh/module reuse ;
- texture arrays ;
- trim sheets ;
- material atlases ;
- argument buffers ;
- indirect command buffers ;
- GPU frustum culling ;
- occlusion culling ;
- HLOD par îlot/quartier ;
- impostors pour skyline ;
- material LOD ;
- decal LOD ;
- shadow LOD ;
- collision LOD.

### 12.4 HLOD urbain

Niveaux :

```text
LOD0: modules détaillés, portes/fenêtres/props
LOD1: façade fusionnée, moins de détails
LOD2: bâtiment mesh simplifié
LOD3: bloc/quartier fusionné
LOD4: skyline/impostor
```

Pour les villes :

- HLOD par bâtiment proche ;
- HLOD par bloc moyen ;
- HLOD par quartier lointain ;
- skyline procédurale très loin.

### 12.5 Collision

Niveaux :

- no collision ;
- bounding box ;
- convex hull ;
- staircase/ramp proxies ;
- detailed exterior ;
- interior collision ;
- gameplay-specific collision.

### 12.6 Navigation

- navmesh local pour zones visitables ;
- nav links pour escaliers, échelles, cordes, ponts ;
- route graph pour PNJ ;
- building entrance graph ;
- settlement graph ;
- abstract nav pour simulation lointaine.

---

## 13. Data model recommandé

### 13.1 StructureRecipe

```swift
struct StructureRecipe {
    let id: StructureRecipeID
    let category: StructureCategory
    let function: StructureFunction
    let allowedBiomes: [BiomeID]
    let allowedEras: [EraID]
    let terrainRequirements: TerrainRequirements
    let footprintGenerator: FootprintGeneratorID
    let massingGenerator: MassingGeneratorID
    let supportStrategies: [SupportStrategy]
    let facadeGrammar: GrammarID?
    let roofGrammar: GrammarID?
    let interiorGenerator: InteriorGeneratorID?
    let materialRules: [MaterialRule]
    let detailRules: [DetailRule]
    let gameplaySockets: [GameplaySocketRule]
    let lodProfile: LODProfileID
}
```

### 13.2 SettlementRecipe

```swift
struct SettlementRecipe {
    let id: SettlementRecipeID
    let type: SettlementType
    let siteRules: [SiteRule]
    let districtRules: [DistrictRule]
    let networkRules: [NetworkRule]
    let plotRules: [PlotRule]
    let buildingDistribution: [WeightedStructureRecipe]
    let publicSpaceRules: [PublicSpaceRule]
    let infrastructureRules: [InfrastructureRule]
    let verticalityProfile: VerticalityProfile
    let visitabilityProfile: VisitabilityProfile
}
```

### 13.3 Plot

```swift
struct Plot {
    let id: UInt64
    let polygon: [Vector2]
    let terrainPatchID: UInt64
    let slopeClass: SlopeClass
    let accessEdges: [EdgeID]
    let districtID: DistrictID
    let function: PlotFunction
    let maxHeight: Float
    let buildableScore: Float
}
```

### 13.4 TerrainSupportSolution

```swift
enum TerrainSupportSolution {
    case flatFoundation
    case steppedFoundation
    case terrace
    case stilts
    case retainingWalls
    case rockAnchors
    case cantilever
    case suspended
    case carvedIntoRock
    case floating
    case partiallyBuried
    case bridgeSpan
}
```

---

## 14. Algorithmes recommandés par couche

### 14.1 Site selection

- sampling déterministe sur chunks/regions ;
- scoring multi-champs ;
- Poisson disk pour éviter settlements trop proches ;
- contraintes dépendant du monde RPG ;
- validation hydrologie/pente/biome.

### 14.2 Roads and access

- A* / Dijkstra sur grille coarse ;
- coût pente/eau/roche/forêt ;
- splines simplifiées ;
- switchbacks sur forte pente ;
- ponts si crossing plus rentable que détour ;
- tunnels si montagne trop coûteuse ;
- stairs/ladders si court chemin vertical.

### 14.3 Plot subdivision

- découpe le long des routes ;
- Voronoi contraint ;
- recursive subdivision ;
- parcelles en terrasses ;
- parcelles verticales sur falaise ;
- parcelles organiques pour villages anciens ;
- parcelles régulières pour villes planifiées.

### 14.4 Building massing

- extrusion paramétrique ;
- volumes empilés ;
- grammaire de formes ;
- contraintes de hauteur ;
- orientation soleil/vent/vue ;
- silhouette contrôlée ;
- variation par richesse/fonction/style.

### 14.5 Façades

- split grammar ;
- module replacement ;
- trim sheets ;
- random streams par étage/travée ;
- règles contextuelles pour corners/entrances/balconies ;
- génération damage/weathering.

### 14.6 Interiors

- room graph ;
- WFC local ;
- templates paramétriques ;
- corridors selon fonction ;
- doors/windows consistency ;
- gameplay validation.

### 14.7 City growth

- growth rings ;
- agent-based lightweight ;
- land-use constraints ;
- transport accessibility ;
- historical layers ;
- decay/repair pass.

---

## 15. Styles architecturaux générables

Chaque style est une collection de règles, pas juste des textures.

### 15.1 Primitive / tribal

- matériaux locaux bruts ;
- asymétrie ;
- formes organiques ;
- structures basses ;
- stockage visible ;
- feu central ;
- peu d’angles droits.

### 15.2 Rural traditionnel

- bois/pierre ;
- toitures pentues ;
- cour ;
- annexes agricoles ;
- murs bas ;
- chemins irréguliers.

### 15.3 Médiéval / fortifié

- rues étroites ;
- murs épais ;
- tours ;
- portes ;
- places ;
- quartiers autour château/temple ;
- bois/pierre ;
- pont-levis possible.

### 15.4 Méditerranéen / chaud

- murs clairs ;
- patios ;
- terrasses ;
- ruelles ombragées ;
- citernes ;
- peu d’ouvertures directes ;
- toits plats.

### 15.5 Alpin / froid

- pierre + bois ;
- toits pentus ;
- fondations fortes ;
- balcons ;
- stockage sous toit ;
- murs de soutènement ;
- neige.

### 15.6 Industriel

- briques ;
- métal ;
- grandes fenêtres ;
- cheminées ;
- hangars ;
- tuyaux ;
- grilles ;
- convoyeurs ;
- rails ;
- silos.

### 15.7 Moderne

- béton ;
- verre ;
- grilles régulières ;
- modules techniques ;
- parkings ;
- routes larges ;
- réseaux visibles/invisibles ;
- skyline.

### 15.8 Post-apocalyptique

- réemploi ;
- tôles ;
- barricades ;
- échafaudages ;
- réparations ;
- panneaux improvisés ;
- végétation invasive ;
- danger.

### 15.9 Futuriste

- modules répétables ;
- surfaces lisses ;
- panneaux ;
- éclairages intégrés ;
- hubs ;
- tours verticales ;
- passerelles ;
- dômes ;
- structures suspendues.

### 15.10 Biomimétique / organique

- formes courbes ;
- intégration végétale ;
- matériaux composites ;
- ouvertures irrégulières ;
- croissance paramétrique ;
- fusion terrain/bâtiment.

### 15.11 Souterrain

- volumes creusés ;
- piliers ;
- ventilation ;
- éclairage indirect ;
- humidité ;
- tunnels ;
- portes lourdes ;
- contraintes de roche.

---

## 16. Exemples de mondes générés par seed

### Seed A — Monde de falaises habitées

- peu de plaines ;
- villages accrochés ;
- escaliers de falaise ;
- ponts suspendus ;
- monastères verticaux ;
- mines ;
- funiculaires primitifs ;
- maisons sur plateformes ;
- forte importance de l’escalade.

### Seed B — Monde industriel humide

- villes près rivières ;
- usines ;
- canaux ;
- ponts métalliques ;
- entrepôts ;
- quartiers ouvriers ;
- rouille ;
- pluie ;
- égouts ;
- centrales hydrauliques.

### Seed C — Monde post-technologique désertique

- ruines high-tech ensablées ;
- camps nomades ;
- bazars d’oasis ;
- dômes cassés ;
- panneaux solaires ;
- tunnels de refroidissement ;
- villes semi-enterrées.

### Seed D — Monde agricole pacifique

- hameaux ;
- fermes ;
- moulins ;
- marchés ;
- petites chapelles ;
- routes de terre ;
- ponts en pierre ;
- granges ;
- champs en terrasses.

### Seed E — Monde souterrain

- surface hostile ;
- entrées de grottes ;
- villes-cavernes ;
- mines ;
- puits ;
- ascenseurs ;
- fermes de champignons ;
- temples profonds ;
- éclairage rare.

### Seed F — Monde futuriste vertical

- tours ;
- passerelles ;
- ascenseurs ;
- rails suspendus ;
- habitats capsules ;
- data centers ;
- stations énergétiques ;
- dômes ;
- quartiers en couches.

---

## 17. Validation et debug

### 17.1 Validation automatique

Chaque structure générée doit passer des tests :

- accès valide ;
- collision non absurde ;
- pas de bâtiment flottant non voulu ;
- fondations plausibles ;
- route connectée si nécessaire ;
- nav links générés ;
- pente acceptable ;
- matériaux compatibles biome ;
- budget GPU respecté ;
- pas de chevauchement majeur ;
- intérieur connecté ;
- entrées non bloquées ;
- ponts avec ancrages valides ;
- escaliers avec pente/hauteur valides.

### 17.2 Debug views

Indispensables :

- site score heatmap ;
- slope map ;
- buildability map ;
- road cost map ;
- district map ;
- plot IDs ;
- support strategy overlay ;
- foundation depth overlay ;
- access graph ;
- nav links ;
- HLOD groups ;
- collision proxies ;
- room graph ;
- facade grammar cells ;
- material masks ;
- seed streams ;
- validation errors.

---

## 18. Pipeline authoring

### 18.1 Data-first

Créer des fichiers de recettes :

```text
Data/Architecture/
  Styles/
  Materials/
  BuildingRecipes/
  SettlementRecipes/
  FacadeGrammars/
  RoofGrammars/
  InteriorRules/
  SupportStrategies/
  LODProfiles/
```

Format possible :

- JSON au début ;
- puis YAML/TOML/custom DSL ;
- plus tard éditeur visuel.

### 18.2 Modules artistiques

Même avec du procédural, il faut une bibliothèque de modules :

- fenêtres ;
- portes ;
- murs ;
- coins ;
- corniches ;
- toits ;
- balcons ;
- supports ;
- piliers ;
- tuyaux ;
- rails ;
- escaliers ;
- passerelles ;
- props urbains.

Chaque module doit avoir metadata :

- dimensions ;
- sockets ;
- style tags ;
- material slots ;
- LODs ;
- collision ;
- snap rules ;
- biome compatibility ;
- era compatibility.

### 18.3 Génération pure vs module-driven

Recommandation :

- **bâtiments organiques/naturels** : plus de génération pure/SDF/mesh procédural ;
- **bâtiments urbains** : module-driven + grammar ;
- **intérieurs** : WFC local + room graph ;
- **mégastructures** : graph + modules + HLOD ;
- **ruines** : générateur damage + modules cassés + debris.

---

## 19. Roadmap d’implémentation

### Phase 1 — Fondations

- `StructureRecipe`
- `SettlementRecipe`
- `BuildingIntent`
- `FootprintGenerator`
- `MassingGenerator`
- quelques maisons simples ;
- adaptation pente légère ;
- rendu instancié simple.

### Phase 2 — Terrain-aware

- `TerrainSupportMap`
- support strategies :
  - stepped foundation ;
  - stilts ;
  - retaining walls ;
- routes simples ;
- parcelles en pente ;
- debug overlays.

### Phase 3 — Villages

- site selection ;
- hameau/village ;
- routes/chemins ;
- maisons, granges, puits, marché ;
- matériaux biome ;
- props contextuels.

### Phase 4 — Façades procédurales

- facade split grammar ;
- fenêtres/portes/corners ;
- roof grammar ;
- weathering ;
- trim sheets ;
- instancing.

### Phase 5 — Verticalité

- falaises ;
- escaliers ;
- passerelles ;
- cordes ;
- bâtiments accrochés ;
- villages en terrasses ;
- nav links.

### Phase 6 — Structures industrielles et camps

- usines ;
- mines ;
- camps ;
- entrepôts ;
- tuyaux ;
- convoyeurs ;
- rails ;
- logique fonctionnelle.

### Phase 7 — Visitabilité

- partial interiors ;
- room graph ;
- WFC local ;
- collision intérieure ;
- streaming intérieur.

### Phase 8 — Villes et HLOD

- districts ;
- blocks ;
- HLOD par bâtiment/bloc/quartier ;
- traffic/crowd hooks ;
- skyline ;
- occlusion.

### Phase 9 — Tooling

- éditeur de recettes ;
- viewer de bâtiment ;
- seed explorer ;
- validation report ;
- visual graph editor minimal.

---

## 20. Design minimal Swift possible

### 20.1 Interfaces

```swift
protocol StructureGenerator {
    func generate(context: StructureGenerationContext) -> GeneratedStructure
}

protocol SettlementGenerator {
    func generate(context: SettlementGenerationContext) -> GeneratedSettlement
}

protocol TerrainSupportSolver {
    func solve(
        footprint: Footprint,
        terrain: TerrainSupportMap,
        recipe: StructureRecipe
    ) -> TerrainSupportSolutionResult
}
```

### 20.2 Context

```swift
struct StructureGenerationContext {
    let worldSeed: UInt64
    let regionSeed: UInt64
    let localSeed: UInt64
    let biome: BiomeID
    let terrain: TerrainSupportMap
    let architectureDNA: WorldArchitectureDNA
    let recipe: StructureRecipe
    let lodTarget: LODTarget
}
```

### 20.3 Generated output

```swift
struct GeneratedStructure {
    let id: UInt64
    let bounds: AABB
    let renderInstances: [RenderInstance]
    let generatedMeshes: [GeneratedMesh]
    let collision: CollisionRepresentation
    let navLinks: [NavLink]
    let gameplaySockets: [GameplaySocket]
    let audioZones: [AudioZone]
    let debug: StructureDebugInfo
}
```

---

## 21. Recommandation finale

Le système de bâtiments d’IsoWorld doit être conçu comme un **écosystème de génération architecturale**, pas comme un générateur de maisons.

La bonne architecture est :

1. **WorldArchitectureDNA** pour les lois globales.
2. **SettlementIntentGraph** pour décider pourquoi une structure existe.
3. **SiteSelectionSystem** pour choisir des lieux plausibles.
4. **TerrainIntegrationAnalyzer** pour comprendre le relief.
5. **AccessNetworkGenerator** pour chemins, escaliers, ponts et verticalité.
6. **PlotAndDistrictGenerator** pour organiser l’espace.
7. **BuildingMassingGenerator** pour créer les volumes.
8. **TerrainAdaptiveStructureSolver** pour éviter le flattening artificiel.
9. **Facade/Roof/Interior Generators** pour la qualité visuelle.
10. **RuntimeRepresentationBuilder** pour performance, LOD, collision et gameplay.

La règle clé :

> Terrain, architecture et gameplay doivent être générés ensemble. Une ville IsoWorld ne doit pas être posée sur le monde ; elle doit sembler avoir poussé, été construite, réparée, abandonnée ou transformée par le monde.

---

## 22. Sources et références

- Epic Games — Procedural Content Generation Framework.  
  https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-framework-in-unreal-engine

- Epic Games — City Sample Quick Start: generating a city and freeway using Houdini.  
  https://dev.epicgames.com/documentation/unreal-engine/city-sample-quick-start-for-generating-a-city-and-freeway-using-houdini

- SideFX — Labs Building Generator 4.0.  
  https://www.sidefx.com/docs/houdini/nodes/sop/labs--building_generator-4.0.html

- Esri — CityEngine rule-based modeling and CGA.  
  https://doc.arcgis.com/en/cityengine/latest/tutorials/essentials-rule-based-modeling.htm

- Müller et al. — Procedural Modeling of Buildings, SIGGRAPH 2006.  
  https://peterwonka.net/Publications/pdfs/2006.SG.Mueller.ProceduralModelingOfBuildings.final.pdf

- Apple — Metal Sample Code, Modern Rendering with Metal, terrain with argument buffers, ICB, sparse textures.  
  https://developer.apple.com/metal/sample-code/

- Martin Evans — Tensor-field road generation overview.  
  https://martindevans.me/game-development/2015/12/11/Procedural-Generation-For-Dummies-Roads/

- Yuhe Nie et al. — Nested Wave Function Collapse for large-scale content generation.  
  https://arxiv.org/abs/2308.07307

- Luiz Fernando Silva Eugênio dos Santos et al. — Agent-based procedural city generation with land-use and transport interaction.  
  https://arxiv.org/abs/2211.01959

- Thomas Lechner et al. — Procedural city modeling with agent-based developmental behavior.  
  https://arxiv.org/abs/2507.18899

- Unity — Megacity / ECS large-scale streaming and rendering reference.  
  https://github.com/Unity-Technologies/Megacity-2019

- Unreal Engine — City Sample project and Mass spawners for crowds, intersections, traffic, parked vehicles.  
  https://dev.epicgames.com/documentation/unreal-engine/city-sample-project-unreal-engine-demonstration
