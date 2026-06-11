# IsoWorld — Système intelligent de biomes, sous-biomes et transitions naturelles

**Sujet couvert uniquement : point 7 — Mettre en place un système intelligent, drivé par des règles, pour gérer naturellement la transition entre les biomes, augmenter fortement le nombre de biomes possibles, organiser des biomes globaux + sous-biomes, et construire un système moderne / versatile / dynamique.**

**Contexte projet :** IsoWorld est un moteur procédural custom en Swift/Metal, pensé pour un monde déterministe par seed, généré dynamiquement par chunks autour du joueur, avec terrain vertical, rendu temps réel, assets procéduraux/paramétriques, props, météo, cycle jour/nuit, RPG systémique et évolution du monde selon les règles du seed.

---

## 0. Résumé exécutif

Le système de biomes d'IsoWorld ne doit pas être une simple table `temperature + humidity -> biome`. Pour obtenir un monde radicalement varié, déterministe, lisible, cohérent et capable de produire des transitions naturelles, il faut concevoir le biome comme une **écorégion procédurale multi-couche**.

Un biome IsoWorld doit être défini par :

1. **Un contexte planétaire / régional** : latitude simulée, altitude, continentalité, distance à l'océan, proximité d'eau douce, exposition au vent, saisonnalité, tectonique, activité volcanique, niveau technologique/RPG, corruption/magie/sci-fi éventuelle.
2. **Une niche écologique** : température, humidité, précipitations, évapotranspiration, ensoleillement, sol, salinité, nutriments, couverture végétale, biodiversité.
3. **Une signature de terrain** : plaines, plateaux, montagnes, falaises, canyons, dunes, fjords, marais, littoraux, grottes, glaciers, karst, delta, etc.
4. **Une palette de matériaux** : sol, roche, mousse, sable, boue, neige, glace, vase, humus, végétation, algues, sel, cendres, poussière, revêtement urbain, matériaux manufacturés.
5. **Un catalogue de features** : arbres, herbes, rochers, props, micro-reliefs, faune, eau, routes, ruines, objets, effets atmosphériques.
6. **Des règles de transition** : écotones, zones mixtes, gradients, couloirs de rivière, fronts de neige, bordures d'altitude, lisières, marécages, dunes stabilisées, colonisation végétale.
7. **Des règles de gameplay** : lisibilité, dangers, ressources, navigation, escalade, visibilité, sons, traces, météo, rencontres, quêtes, factions, densité de props.

La proposition centrale :

> IsoWorld doit utiliser un **Biome Graph déterministe**, alimenté par un **Climate Field** continu et un **Rule Engine** déclaratif. Chaque position du monde ne reçoit pas “un biome”, mais un **mélange pondéré de biomes et de sous-biomes**, plus une couche de “transition biome” explicite. Ce mélange pilote le terrain, les matériaux, les props, la faune, la météo locale, le son, les FX, le gameplay et les opportunités RPG.

La bonne architecture est donc :

```text
World Seed
  -> World DNA
  -> Macro Climate Simulation
  -> Geo/Hydro Fields
  -> Biome Candidate Selection
  -> Biome Weight Blending
  -> Ecotone / Transition Resolver
  -> Sub-Biome Resolver
  -> Material / Prop / Fauna / Gameplay Layers
  -> Chunk Snapshot Renderer + Collision + Navigation
```

---

## 1. Recherche et patterns modernes pertinents

### 1.1. Ce qu'on retient des classifications écologiques réelles

Les classifications réelles de biomes et d'écorégions ne sont pas seulement fondées sur la température et la pluie. Elles combinent climat, végétation, sols, géologie, hydrologie, relief, faune, histoire biogéographique et dynamiques écologiques.

Références importantes :

- **TEOW / Terrestrial Ecoregions of the World** : 867 écorégions classées en 14 grands types d'habitats. Point clé pour IsoWorld : une écorégion représente un assemblage de communautés naturelles, d'espèces, de dynamiques et de conditions environnementales. Les frontières ne sont généralement pas abruptes ; elles sont transitionnelles et contiennent des habitats minoritaires.  
  Source : FAO / WWF TEOW — https://www.fao.org/land-water/land/land-governance/land-resources-planning-toolbox/category/details/en/c/1036295/

- **EPA Ecoregions** : les écorégions sont déduites de mosaïques de composants biotiques et abiotiques : géologie, formes de terrain, sols, végétation, climat, hydrologie, usage du sol, faune. Point clé : IsoWorld doit structurer ses biomes en niveaux hiérarchiques et ne pas confondre biome, terrain, sol et végétation.  
  Source : US EPA Ecoregions — https://www.epa.gov/eco-research/ecoregions

- **Whittaker Biome Model** : classification de grands biomes via température annuelle moyenne et précipitations annuelles. Point clé : utile comme première carte macro, insuffisant pour un open world détaillé.  
  Source pédagogique : https://serc.carleton.edu/eslabs/weather/4a.html

- **Holdridge Life Zones** : système fondé sur biotempérature, précipitations et ratio d'évapotranspiration potentielle. Point clé : introduire l'aridité réelle plutôt qu'une humidité arbitraire.  
  Source : USDA / Lugo et al. — https://research.fs.usda.gov/treesearch/30306

### 1.2. Ce qu'on retient des jeux / moteurs

- **Minecraft modern world generation** : le monde utilise des variables climatiques et géologiques comme hauteur, température, humidité, érosion, weirdness/variation, et les biomes pilotent features, mobs, précipitation, couleurs atmosphériques. Point clé : les biomes sont un système de sélection de contenu régional, pas seulement une texture de terrain.  
  Source : Microsoft Minecraft World Generation — https://learn.microsoft.com/en-us/minecraft/creator/documents/world-generation

- **Unreal PCG Biome Core** : exemple de pipeline par graphes, tables d'attributs, sous-graphes récursifs, feedback loops, génération hiérarchique runtime. Point clé : IsoWorld doit adopter des recettes déclaratives et composables, pas des `if/else` dispersés.  
  Source : Epic PCG Biome Core — https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-pcg-biome-core-and-sample-plugins-in-unreal-engine

- **Far Cry 5 Procedural World Generation** : Ubisoft a conçu des outils procéduraux pour générer biomes, texturer terrain, créer réseaux d'eau douce, falaises, etc., tout en permettant la retouche artistique. Point clé : combiner génération auto + override local + outils de debug/preview.  
  Source : GDC Vault — https://www.gdcvault.com/play/1025557/Procedural-World-Generation-of-Far

- **Ghost Recon Wildlands terrain tools** : un open world immense avec montagnes, forêts, déserts et salars, soutenu par un toolchain dédié terrain/rendu. Point clé : les biomes doivent être pensés avec le terrain, les matériaux et la densité de props.  
  Source : GDC Vault — https://www.gdcvault.com/play/1024029/-ghost-recon-wildlands-terrain

- **AutoBiomes** : pipeline de génération multi-biome combinant techniques de terrain procédural, DEMs et simulation climatique simplifiée, plus placement d'assets. Point clé : le réalisme vient d'une pipeline multi-couche, pas d'une seule noise map.  
  Source : Fischer et al., The Visual Computer — https://link.springer.com/article/10.1007/s00371-020-01920-7

### 1.3. Conclusion de recherche

Pour IsoWorld, il faut éviter trois erreurs classiques :

1. **Biome = couleur de sol** : trop pauvre. Le biome doit piloter terrain, matériaux, props, météo, faune, sons, gameplay.
2. **Biome = nearest noise value** : trop discontinu. Il faut des poids, gradients et écotones explicites.
3. **Biome = hard-coded enum** : trop rigide. Il faut des définitions data-driven, graph-based et paramétriques.

---

## 2. Objectifs du système IsoWorld BiomeSystem

### 2.1. Objectifs fonctionnels

Le système doit permettre :

- Générer des biomes déterministes à partir d'un seed global.
- Changer radicalement l'identité du monde quand le seed change.
- Avoir des biomes globaux et des sous-biomes très nombreux.
- Mélanger naturellement les biomes sans couture visible.
- Générer des transitions crédibles : lisières, savanes, taïgas, marécages, piémonts, dunes, deltas, fronts neigeux, zones brûlées, etc.
- Piloter terrain, matériaux, végétation, props, faune, météo, sons, FX et gameplay.
- Supporter un monde chunké autour du joueur.
- Garder une génération légère au runtime, en pré-computant ou cachant ce qui est coûteux.
- Permettre des biomes réalistes, stylisés, fantastiques, post-apo, aliens ou technologiques.
- Permettre un système RPG où le seed peut modifier les règles écologiques : monde sans ennemis, monde hostile, monde toxique, époque moderne, monde futuriste, monde magique, monde corrompu, planète morte, planète luxuriante, etc.

### 2.2. Objectifs de qualité visuelle

Le système doit produire :

- Des gradients naturels de couleurs et de densité.
- Des transitions progressives de matériaux : herbe -> terre sèche -> sable, neige -> herbe gelée -> roche nue, mousse -> humus -> boue, etc.
- Des écotones riches plutôt que des frontières plates.
- Une cohérence terrain-biome : pas de jungle aride en haut d'une crête froide sauf règle spéciale.
- Des sous-biomes lisibles : clairière, lisière, marais, plateau, ravin, ripisylve, etc.
- Une variation locale forte sans casser la cohérence macro.
- Des “landmarks écologiques” : arbre géant, oasis, glacier suspendu, geyser field, forêt morte, champ de cristaux, récif, mangrove, etc.

### 2.3. Objectifs techniques

- Data-driven via fichiers `BiomeDefinition`, `SubBiomeDefinition`, `TransitionRule`, `BiomePalette`.
- Déterministe : même seed + même coordonnées => même résultat.
- Chunk-safe : aucun seam entre chunks.
- Multi-échelle : macro 10–100 km, méso 500 m–5 km, micro 1–100 m.
- Compatible Swift/Metal : calcul CPU pour décisions haut niveau, GPU/compute pour cartes de poids, splat maps, scattering de props.
- Debuggable : vues de climate fields, biome IDs, poids, transitions, densités, règles gagnantes.
- Extensible : ajout d'un biome sans recompilation du moteur.

---

## 3. Modèle conceptuel : biome, sous-biome, écotone, micro-habitat

### 3.1. Définitions

#### Biome global

Un **biome global** est une grande famille écologique ou environnementale : forêt tempérée, désert, toundra, océan, montagne alpine, zone urbaine, biome alien, etc.

Il définit :

- conditions climatiques dominantes ;
- palette de terrain ;
- familles de végétation ;
- matériaux de sol ;
- météo typique ;
- faune ;
- type de ressources ;
- ambiance visuelle et sonore.

#### Sous-biome

Un **sous-biome** est une variation locale ou régionale d'un biome global.

Exemples :

- Forêt tempérée -> hêtraie humide, pinède sèche, clairière fleurie, forêt ancienne, lisière, ravin moussu.
- Désert -> dunes mobiles, reg, erg, oasis, playa sèche, canyon rouge, désert de sel.
- Montagne -> piémont, forêt subalpine, alpage, moraine, glacier, arête rocheuse, falaise alpine.

#### Écotone / biome de transition

Un **écotone** est une zone de transition entre deux biomes.

Exemples :

- Forêt -> prairie : lisière, bocage, clairière, savane arborée.
- Désert -> steppe : semi-désert, scrubland, steppe sèche.
- Montagne -> forêt : piémont, forêt montagnarde, ravins humides.
- Eau douce -> terre : ripisylve, berge boueuse, marais, roseaux.
- Toundra -> taïga : forêt clairsemée boréale.

Dans IsoWorld, un écotone n'est pas un effet secondaire : c'est une **entité procédurale explicite** avec ses propres matériaux, props, sons, règles de navigation et densité.

#### Micro-habitat

Un **micro-habitat** est une zone locale dérivée de la géométrie ou des conditions :

- pied de falaise humide ;
- sommet exposé au vent ;
- creux d'eau temporaire ;
- zone d'ombre permanente ;
- sous-bois dense ;
- talus sec ;
- berge inondable ;
- cavité froide ;
- zone de lichens sur roche ;
- souche morte colonisée par champignons.

Les micro-habitats enrichissent énormément le monde à faible coût.

---

## 4. Architecture proposée : BiomeSystem

### 4.1. Vue d'ensemble

```text
BiomeSystem
├── WorldBiomeDNA
├── ClimateFieldProvider
├── GeoHydroFieldProvider
├── BiomeRegistry
├── BiomeSelector
├── BiomeWeightSolver
├── EcotoneResolver
├── SubBiomeResolver
├── BiomeMaterialResolver
├── BiomePropResolver
├── BiomeFaunaResolver
├── BiomeWeatherResolver
├── GameplayBiomeResolver
├── ChunkBiomeCache
└── DebugBiomeVisualizer
```

### 4.2. WorldBiomeDNA

Le `WorldBiomeDNA` est généré depuis le seed global. Il influence l'identité globale du monde.

Exemples de paramètres :

```swift
struct WorldBiomeDNA: Codable, Hashable {
    let seed: UInt64
    let globalTemperatureBias: Float       // -1 froid, +1 chaud
    let globalHumidityBias: Float          // -1 sec, +1 humide
    let oceanCoverage: Float               // 0..1
    let mountainFrequency: Float           // densité montagnes
    let riverDensity: Float                // densité hydrologie
    let biomeDiversity: Float              // variété globale
    let transitionSoftness: Float          // écotones larges ou abrupts
    let ecologicalStability: Float         // monde stable vs chaotique
    let seasonalityStrength: Float         // saisons faibles/fortes
    let anomalyRate: Float                 // biomes rares/anormaux
    let corruptionRate: Float              // option RPG/fantasy
    let technologyFootprint: Float         // nature vierge vs traces humaines
    let alienness: Float                   // réalisme terrestre vs planète étrange
}
```

Ce DNA doit être stable pour un seed donné, mais très différent d'un seed à l'autre. C'est lui qui permet d'avoir un monde “terre réaliste”, “désertique”, “marécageux”, “froid”, “post-apo”, “alien”, “forêt infinie”, etc.

### 4.3. ClimateFieldProvider

Produit des champs continus :

```swift
struct ClimateSample {
    let temperature: Float          // -1..1
    let humidity: Float             // 0..1
    let precipitation: Float        // 0..1
    let aridity: Float              // 0..1
    let windExposure: Float         // 0..1
    let sunlight: Float             // 0..1
    let seasonality: Float          // 0..1
    let frostRisk: Float            // 0..1
    let stormFrequency: Float       // 0..1
}
```

Les champs sont calculés à partir de :

- latitude procédurale ;
- altitude ;
- distance à la mer ;
- rain shadow derrière montagnes ;
- distance aux rivières/lacs ;
- orientation des pentes ;
- bruit climatique basse fréquence ;
- anomalies du seed ;
- météo moyenne régionale.

### 4.4. GeoHydroFieldProvider

Produit les champs géologiques/hydrologiques :

```swift
struct GeoHydroSample {
    let elevation: Float
    let slope: Float
    let curvature: Float
    let ruggedness: Float
    let erosion: Float
    let soilDepth: Float
    let rockExposure: Float
    let drainage: Float
    let waterDistance: Float
    let groundwater: Float
    let floodRisk: Float
    let salinity: Float
    let volcanicActivity: Float
    let karstPotential: Float
    let glacialInfluence: Float
}
```

### 4.5. BiomeDefinition

Un biome doit être une recette déclarative.

```swift
struct BiomeDefinition: Codable, Hashable {
    let id: String
    let displayName: String
    let globalFamily: String
    let rarity: Float
    let climateEnvelope: ClimateEnvelope
    let terrainEnvelope: TerrainEnvelope
    let soilEnvelope: SoilEnvelope
    let hydrologyEnvelope: HydrologyEnvelope
    let adjacencyRules: [BiomeAdjacencyRule]
    let subBiomes: [String]
    let materialPalette: BiomeMaterialPalette
    let propPalette: BiomePropPalette
    let faunaPalette: BiomeFaunaPalette
    let weatherProfile: BiomeWeatherProfile
    let gameplayProfile: BiomeGameplayProfile
    let transitionProfile: BiomeTransitionProfile
}
```

### 4.6. ClimateEnvelope

```swift
struct ClimateEnvelope: Codable, Hashable {
    let temperatureRange: ClosedRange<Float>
    let humidityRange: ClosedRange<Float>
    let precipitationRange: ClosedRange<Float>
    let aridityRange: ClosedRange<Float>
    let frostRiskRange: ClosedRange<Float>
    let seasonalityRange: ClosedRange<Float>
    let preferredLatitudeBands: [ClosedRange<Float>]
    let fuzzyFalloff: Float
}
```

Principe : un biome n'est pas valide/invalide brutalement. Il possède une courbe d'affinité.

```text
affinity = climateMatch * terrainMatch * soilMatch * hydroMatch * rarityBias * worldDNABias
```

### 4.7. SubBiomeDefinition

```swift
struct SubBiomeDefinition: Codable, Hashable {
    let id: String
    let parentBiome: String
    let role: SubBiomeRole
    let localConditions: LocalConditionSet
    let rarity: Float
    let patchScaleMeters: ClosedRange<Float>
    let edgeSoftnessMeters: ClosedRange<Float>
    let materialOverrides: [MaterialRule]
    let propOverrides: [PropRule]
    let faunaOverrides: [FaunaRule]
    let gameplayOverrides: [GameplayRule]
}

enum SubBiomeRole: String, Codable {
    case core
    case edge
    case wetland
    case dryPatch
    case highAltitude
    case lowAltitude
    case riverCorridor
    case lakeShore
    case coast
    case cliff
    case caveMouth
    case burned
    case corrupted
    case ancient
    case humanModified
    case rareLandmark
}
```

---

## 5. Sélection des biomes : modèle multi-champs

### 5.1. Les champs principaux

Pour chaque position monde `(x, z)` et éventuellement altitude `y`, IsoWorld calcule :

| Champ | Rôle |
|---|---|
| `temperature` | base climatique, neige/glace, types de végétation |
| `humidity` | densité végétation, marais, sécheresse |
| `precipitation` | pluie/neige, rivières, biomasse |
| `aridity` | désertification, sols nus, poussière |
| `continentality` | distance mer / influence océanique |
| `elevation` | altitude, étagement vertical |
| `slope` | falaises, végétation rare, roche apparente |
| `ruggedness` | montagnes, badlands, chaos rocheux |
| `erosion` | plaines lisses vs ravinées |
| `soilDepth` | capacité végétale |
| `drainage` | eau stagnante vs sol drainant |
| `waterDistance` | ripisylve, marais, oasis |
| `salinity` | désert de sel, mangrove, littoral |
| `windExposure` | arbres tordus, absence de grands arbres |
| `sunlight` | forêt dense vs sous-bois humide |
| `disturbance` | feu, glissement, crue, activité humaine |
| `anomaly` | biome rare, magique, alien, corrompu |

### 5.2. Sélection par affinité pondérée

Chaque biome calcule son score :

```swift
func biomeAffinity(
    biome: BiomeDefinition,
    climate: ClimateSample,
    geo: GeoHydroSample,
    dna: WorldBiomeDNA
) -> Float {
    let c = biome.climateEnvelope.match(climate)
    let t = biome.terrainEnvelope.match(geo)
    let s = biome.soilEnvelope.match(geo)
    let h = biome.hydrologyEnvelope.match(geo)
    let d = dnaModifier(biome, dna)
    return c * t * s * h * d * biome.rarity
}
```

Puis on garde les N meilleurs biomes et on normalise :

```swift
struct BiomeBlend {
    let primary: String
    let secondary: String?
    let weights: [(biomeID: String, weight: Float)]
    let transitionID: String?
    let confidence: Float
}
```

### 5.3. Pourquoi garder plusieurs poids ?

Parce que tout doit pouvoir se mélanger :

- terrain : morphing doux des reliefs ;
- matériaux : splat map multi-biome ;
- végétation : densité progressive ;
- météo : brouillard plus humide près du marais ;
- props : rochers désertiques qui disparaissent progressivement ;
- sons : insectes + vent + oiseaux selon mélange ;
- gameplay : friction, visibilité, ressources.

---

## 6. Transitions naturelles : le système d'écotones

### 6.1. Principe

Une transition naturelle n'est pas un simple blend linéaire. Elle doit produire des contenus nouveaux.

Exemple forêt -> prairie :

- moins de grands arbres ;
- plus d'arbustes ;
- herbes plus hautes ;
- fleurs ;
- chemins animaux ;
- branches mortes ;
- lumière plus chaude ;
- densité de faune plus forte ;
- matériau sol mélangé humus/herbe.

### 6.2. TransitionRule

```swift
struct TransitionRule: Codable, Hashable {
    let id: String
    let fromBiome: String
    let toBiome: String
    let transitionBiome: String
    let minWidthMeters: Float
    let maxWidthMeters: Float
    let requiredConditions: [RuleCondition]
    let forbiddenConditions: [RuleCondition]
    let materialBlendCurve: CurveID
    let propBlendCurve: CurveID
    let terrainBlendMode: TerrainBlendMode
    let priority: Int
}
```

### 6.3. Types de transitions à gérer

| Transition | Écotone proposé |
|---|---|
| forêt -> prairie | lisière, bocage, clairière |
| forêt humide -> marais | forêt marécageuse, tourbière boisée |
| forêt -> montagne | piémont forestier, forêt subalpine |
| forêt -> désert | savane arborée, scrubland sec |
| prairie -> désert | steppe sèche, semi-désert |
| prairie -> marais | prairie humide, roseaux, tourbière |
| montagne -> neige | étage alpin, moraine, névé |
| montagne -> désert | montagne aride, canyon, pierrier |
| rivière -> forêt | ripisylve, berge humide |
| rivière -> désert | oasis linéaire, oued, palmeraie |
| lac -> forêt | berge moussue, roselière |
| mer -> terre | plage, dune, falaise côtière, mangrove |
| volcan -> forêt | sol cendreux colonisé, forêt pionnière |
| corruption -> nature | zone contaminée progressive |
| urbain -> sauvage | friche, ruines végétalisées |

### 6.4. Width resolver

La largeur de transition dépend de :

- différence climatique entre les biomes ;
- pente ;
- proximité de l'eau ;
- érosion ;
- stabilité du monde ;
- `WorldBiomeDNA.transitionSoftness` ;
- perturbations : feu, inondation, civilisation.

```text
transitionWidth = baseWidth
                * biomePairCompatibility
                * slopeFactor
                * hydrologyFactor
                * worldDNASoftness
                * localNoise
```

### 6.5. Transition par Voronoi + noise warping

Pour éviter les frontières rectilignes :

1. Générer des cellules macro d'écorégions via Worley/Voronoi bruité.
2. Déformer les frontières par noise basse fréquence.
3. Appliquer la sélection climatique dans chaque cellule.
4. Calculer la distance à la frontière.
5. Créer une bande d'écotone dont la largeur varie.
6. Injecter des features spécifiques à l'écotone.

### 6.6. Transition par champs continus

Alternative plus organique :

- tous les biomes ont un score d'affinité ;
- on utilise les deux ou trois scores les plus hauts ;
- si `primaryWeight < threshold`, on est dans une transition ;
- le type de transition dépend de la paire dominante.

Ce modèle est très adapté à IsoWorld car il évite les seams entre chunks.

---

## 7. Hiérarchie de biomes proposée

La hiérarchie recommandée :

```text
BiomeDomain
  -> GlobalBiomeFamily
    -> Biome
      -> SubBiome
        -> MicroHabitat
```

### 7.1. Domaines globaux

1. Domaines tropicaux
2. Domaines tempérés
3. Domaines boréaux
4. Domaines polaires
5. Domaines arides
6. Domaines montagnards
7. Domaines aquatiques eau douce
8. Domaines côtiers et marins
9. Domaines souterrains
10. Domaines volcaniques / géothermiques
11. Domaines anthropisés / manufacturés
12. Domaines post-catastrophe
13. Domaines fantastiques / corrompus
14. Domaines alien / sci-fi

Ces domaines ne sont pas mutuellement exclusifs. Un biome peut être `montagnard + aride + volcanique`, ou `tempéré + côtier + anthropisé`.

---

## 8. Liste ultra longue de biomes et sous-biomes

Cette liste doit servir de base pour des data assets. Elle est volontairement très large. On peut commencer avec un sous-ensemble, puis activer progressivement des familles.

### 8.1. Forêts tropicales et subtropicales humides

#### Biome : rainforest_lowland

Conditions : très chaud, très humide, basse altitude, fortes précipitations, sol profond, faible saisonnalité.

Sous-biomes :

- forêt tropicale dense basse altitude ;
- forêt primaire à canopée fermée ;
- forêt secondaire plus claire ;
- clairière tropicale ;
- forêt de lianes ;
- forêt à fougères géantes ;
- forêt à arbres contreforts ;
- forêt inondable saisonnière ;
- forêt de varzea ;
- forêt de terre ferme ;
- ravin tropical humide ;
- sous-bois très sombre ;
- zone de chablis ;
- corridor de rivière tropicale ;
- cascade jungle ;
- forêt de mousses chaude ;
- jungle de bambous ;
- jungle de palmiers ;
- forêt à orchidées ;
- forêt toxique/empoisonnée variante RPG.

Règles :

- densité végétale très élevée ;
- visibilité courte ;
- sol humide, humus épais ;
- props : racines, lianes, troncs tombés, plantes larges ;
- faune très dense ;
- transitions vers savane via forêt claire / mosaïque arborée ;
- transitions vers montagne via forêt nuageuse.

#### Biome : cloud_forest_tropical

Conditions : chaud à tempéré, altitude moyenne, humidité constante, brouillard élevé.

Sous-biomes :

- forêt nuageuse de crête ;
- forêt moussue ;
- ravin brumeux ;
- falaise végétalisée ;
- forêt à épiphytes ;
- plateau humide ;
- cascade froide tropicale ;
- lisière de nuages ;
- forêt de broméliacées ;
- micro-forêt suspendue.

Règles :

- fort brouillard local ;
- beaucoup de mousse sur roches ;
- végétation sur surfaces verticales ;
- humidité même en pente ;
- transitions vers alpage tropical ou rainforest.

### 8.2. Forêts tropicales sèches et savanes

#### Biome : tropical_dry_forest

Sous-biomes :

- forêt sèche caducifoliée ;
- forêt claire à acacias ;
- forêt épineuse ;
- bosquet sec ;
- ravin plus humide ;
- lit de rivière saisonnier ;
- forêt de baobabs ;
- forêt de palmiers secs ;
- zone brûlée saisonnière ;
- forêt sèche rocheuse.

Règles :

- végétation saisonnière ;
- feuilles plus rares en saison sèche ;
- herbes sèches inflammables ;
- transitions vers savane ou semi-désert.

#### Biome : savanna

Sous-biomes :

- savane arborée ;
- savane herbeuse ouverte ;
- savane sèche ;
- savane humide ;
- savane à termitières ;
- savane rocheuse ;
- savane inondable ;
- savane brûlée ;
- savane de palmiers ;
- savane à hautes herbes ;
- savane à acacias ;
- prairie tropicale ;
- lisière forêt-savane ;
- savane de plateau ;
- savane de vallée.

Règles :

- arbres dispersés selon humidité ;
- herbes hautes saisonnières ;
- feu comme perturbation naturelle ;
- densité de grands animaux potentielle ;
- transition vers désert par scrubland.

### 8.3. Forêts tempérées

#### Biome : temperate_broadleaf_forest

Sous-biomes :

- hêtraie ;
- chênaie ;
- érablière ;
- forêt mixte ;
- forêt ancienne ;
- jeune forêt secondaire ;
- clairière fleurie ;
- lisière bocagère ;
- ravin moussu ;
- sous-bois à fougères ;
- forêt de vallée ;
- forêt de colline ;
- forêt humide de pente nord ;
- forêt sèche de pente sud ;
- forêt à champignons ;
- forêt automnale ;
- forêt enneigée saisonnière ;
- forêt de bouleaux pionniers ;
- forêt de frênes près rivière ;
- forêt de chênes tordus par vent.

Règles :

- forte saisonnalité visuelle ;
- sol humifère ;
- sous-bois variable selon lumière ;
- feuilles mortes ;
- transitions naturelles vers prairie, marais, montagne, taïga.

#### Biome : temperate_conifer_forest

Sous-biomes :

- pinède sèche ;
- pinède sableuse ;
- sapinière humide ;
- forêt de cèdres ;
- forêt sombre de conifères ;
- plantation régulière ;
- forêt de montagne basse ;
- forêt de crête ventée ;
- ravin à conifères ;
- forêt brûlée ;
- forêt post-incendie jeune ;
- forêt de lichens ;
- forêt enneigée ;
- clairière de conifères ;
- talus d'aiguilles.

Règles :

- sol acide ;
- tapis d'aiguilles ;
- faible sous-bois dans zones sombres ;
- props : pommes de pin, branches mortes, souches.

#### Biome : temperate_rainforest

Sous-biomes :

- forêt pluviale tempérée ;
- forêt de séquoias ;
- forêt de grands cèdres ;
- ravin humide permanent ;
- forêt moussue ;
- forêt côtière brumeuse ;
- forêt de fougères ;
- forêt ancienne à troncs géants ;
- forêt de cascades ;
- lisière océanique humide ;
- forêt de vallée encaissée ;
- forêt de bois mort massif.

Règles :

- pluie/brouillard fréquents ;
- mousse partout ;
- troncs gigantesques ;
- props morts très nombreux ;
- transition vers côte rocheuse ou montagne humide.

### 8.4. Prairies, steppes et landes

#### Biome : temperate_grassland

Sous-biomes :

- prairie courte ;
- prairie haute ;
- meadow fleurie ;
- prairie humide ;
- prairie sèche ;
- steppe tempérée ;
- prairie de collines ;
- prairie de vallée ;
- prairie à rochers ;
- prairie pâturée ;
- prairie sauvage ;
- prairie brûlée ;
- prairie avec bosquets ;
- prairie de crête ;
- prairie venteuse ;
- prairie à herbes argentées.

Règles :

- arbres rares sauf bosquets/lisières ;
- visibilité longue ;
- vent fort visible dans herbes ;
- transitions vers forêt via lisière/bocage.

#### Biome : heathland_moorland

Sous-biomes :

- lande à bruyères ;
- lande rocheuse ;
- lande humide ;
- lande sèche ;
- tourbière haute ;
- plateau venteux ;
- lande côtière ;
- lande de montagne ;
- lande brumeuse ;
- lande à genêts ;
- lande brûlée ;
- lande à fougères.

Règles :

- sols acides/pauvres ;
- arbustes bas ;
- brouillard/vent ;
- peu de grands arbres.

### 8.5. Biomes boréaux

#### Biome : taiga

Sous-biomes :

- taïga dense ;
- taïga clairsemée ;
- taïga enneigée ;
- taïga humide ;
- taïga marécageuse ;
- forêt boréale mixte ;
- pinède boréale sèche ;
- pessière noire ;
- forêt de mélèzes ;
- taïga de vallée ;
- taïga de plateau ;
- taïga brûlée ;
- taïga post-feu ;
- taïga de lichens ;
- lisière taïga-toundra ;
- rive boréale.

Règles :

- températures froides ;
- neige saisonnière/persistante ;
- sols acides ;
- tourbières fréquentes ;
- transitions vers toundra via forêt clairsemée.

#### Biome : boreal_wetland

Sous-biomes :

- muskeg ;
- tourbière boréale ;
- marais froid ;
- lac boréal peu profond ;
- forêt noyée ;
- étang à sphaignes ;
- berge de castor ;
- delta froid ;
- plaine inondable boréale ;
- forêt humide de mélèzes.

Règles :

- sol saturé ;
- déplacement ralenti ;
- moustiques/sons ;
- brume froide ;
- beaucoup d'eau peu profonde.

### 8.6. Toundra et polaire

#### Biome : tundra

Sous-biomes :

- toundra arbustive ;
- toundra de mousses ;
- toundra de lichens ;
- toundra rocheuse ;
- toundra humide ;
- toundra polygonale ;
- toundra côtière ;
- toundra de plateau ;
- toundra alpine ;
- toundra balayée par le vent ;
- toundra à mares de fonte ;
- toundra gelée permanente ;
- toundra en floraison courte ;
- toundra sombre post-dégel.

Règles :

- arbres absents ou nains ;
- sol gelé ;
- micro-reliefs ;
- neige légère ou plaques ;
- transition vers taïga via krummholz/forêt basse.

#### Biome : polar_desert

Sous-biomes :

- désert polaire sec ;
- plateau de glace ;
- banquise ;
- moraine froide ;
- vallée sèche froide ;
- champ de neige ;
- glace bleue ;
- sastrugi ;
- côte glacée ;
- falaise de glace ;
- iceberg échoué ;
- crevasses ;
- grotte de glace.

Règles :

- très peu de végétation ;
- forte réflexion lumineuse ;
- vents violents ;
- gameplay : glissade, froid, visibilité tempête.

### 8.7. Déserts et milieux arides

#### Biome : hot_sandy_desert

Sous-biomes :

- erg de dunes mobiles ;
- dunes étoilées ;
- dunes barkhanes ;
- mer de sable ;
- interdunes humides rares ;
- oasis ;
- palmeraie ;
- plateau sableux ;
- désert rouge ;
- désert blanc ;
- désert noir volcanique ;
- dune côtière chaude ;
- champ de yardangs ;
- désert de poussière ;
- désert de verre/fusion variante sci-fi.

Règles :

- humidité très basse ;
- végétation rare concentrée autour eau ;
- sable mobile ;
- fortes variations jour/nuit ;
- visibilité et mirages.

#### Biome : rocky_desert

Sous-biomes :

- reg caillouteux ;
- hamada rocheuse ;
- badlands ;
- mesa desert ;
- canyon aride ;
- arches naturelles ;
- plateau fissuré ;
- ravines sèches ;
- désert de graviers ;
- désert de basaltes ;
- désert à cheminées de fée ;
- désert à buttes ;
- désert de sel en bordure ;
- lit d'oued.

Règles :

- roche apparente ;
- végétation très éparse ;
- forte érosion ;
- matériaux rouges/ocres/gris.

#### Biome : cold_desert

Sous-biomes :

- steppe froide aride ;
- désert de gravier froid ;
- désert de sel froid ;
- plateau semi-aride ;
- bassin endoréique ;
- dune froide ;
- désert haut-altitude ;
- reg glacé ;
- désert venteux ;
- scrub froid.

Règles :

- faible pluie mais températures basses ;
- arbustes bas ;
- neige rare ;
- transition vers toundra ou steppe.

### 8.8. Montagnes et haute altitude

#### Biome : mountain_temperate

Sous-biomes :

- piémont forestier ;
- colline montagnarde ;
- vallée alpine ;
- forêt montagnarde ;
- forêt subalpine ;
- alpage ;
- prairie alpine ;
- moraine ;
- pierrier ;
- falaise calcaire ;
- crête venteuse ;
- ravin froid ;
- cascade alpine ;
- lac de montagne ;
- glacier suspendu ;
- névé ;
- couloir d'avalanche ;
- arête rocheuse ;
- plateau haut ;
- col enneigé.

Règles :

- étagement vertical fort ;
- neige selon altitude/exposition ;
- végétation diminue avec altitude ;
- props : roches, pins tordus, herbes alpines ;
- transitions par altitude plutôt que distance horizontale.

#### Biome : mountain_arid

Sous-biomes :

- montagne désertique ;
- canyon de montagne ;
- ravin sec ;
- mesa élevée ;
- plateau rocheux ;
- pierrier chaud ;
- oasis de montagne ;
- falaise rouge ;
- vallée encaissée ;
- montagne salée ;
- crête nue ;
- faille tectonique.

Règles :

- pluie faible ;
- ombre de pluie ;
- végétation concentrée dans ravins ;
- matériaux pierre/sable.

#### Biome : mountain_tropical

Sous-biomes :

- forêt de montagne tropicale ;
- cloud forest ;
- ravin de fougères ;
- pente humide ;
- crête moussue ;
- alpage tropical ;
- páramo ;
- vallée brumeuse ;
- falaise végétale ;
- cascade haute.

Règles :

- altitude refroidit climat ;
- forte humidité sur versants au vent ;
- végétation verticale possible.

### 8.9. Eau douce : rivières, lacs, marais

#### Biome : river_corridor

Sous-biomes :

- ruisseau de montagne ;
- torrent ;
- rivière claire ;
- rivière lente ;
- rivière boueuse ;
- méandre ;
- bras mort ;
- berge érodée ;
- berge sableuse ;
- berge caillouteuse ;
- ripisylve tempérée ;
- ripisylve tropicale ;
- galerie forestière désertique ;
- cascade ;
- rapide ;
- delta intérieur ;
- île fluviale ;
- gué ;
- plage de galets ;
- ravin humide.

Règles :

- corridors qui traversent d'autres biomes ;
- humidité locale augmente ;
- props spécifiques : roseaux, galets, troncs flottés ;
- gameplay : traversée, glissade, nage, pêche.

#### Biome : lake

Sous-biomes :

- lac profond ;
- lac peu profond ;
- lac alpin ;
- lac forestier ;
- lac boréal ;
- lac salé ;
- lac de cratère ;
- lac glaciaire ;
- lac dystrophique sombre ;
- lac tropical ;
- lac de barrage naturel ;
- rive rocheuse ;
- rive sableuse ;
- roselière ;
- îlot lacustre ;
- marécage de bord de lac ;
- plage de vase ;
- lac gelé.

Règles :

- biome local imbriqué ;
- effet sur brouillard, faune, végétation ;
- transitions selon pente et matériaux.

#### Biome : wetland

Sous-biomes :

- marais ;
- marécage boisé ;
- tourbière ;
- fen alcalin ;
- bog acide ;
- roselière ;
- mangrove d'eau douce rare ;
- prairie humide ;
- forêt inondée ;
- bayou ;
- delta marécageux ;
- rizière sauvage ;
- mare temporaire ;
- trou d'eau ;
- zone de castors ;
- marais toxique RPG ;
- marais lumineux bioluminescent.

Règles :

- sol saturé ;
- brouillard ;
- déplacement plus lent ;
- sons d'insectes/amphibiens ;
- danger d'enlisement possible.

### 8.10. Littoraux et océans

#### Biome : coast_temperate

Sous-biomes :

- plage sableuse ;
- plage de galets ;
- dune côtière ;
- falaise côtière ;
- estran rocheux ;
- marais salant ;
- lagune ;
- estuaire ;
- forêt côtière ;
- lande côtière ;
- côte brumeuse ;
- côte tempétueuse ;
- îlot rocheux ;
- arche marine ;
- grotte marine.

Règles :

- salinité ;
- vent ;
- végétation basse/tolérante au sel ;
- props : bois flotté, algues, coquillages.

#### Biome : coast_tropical

Sous-biomes :

- plage tropicale ;
- lagon ;
- mangrove ;
- récif corallien proche ;
- île de sable ;
- cocoteraie ;
- estuaire tropical ;
- forêt littorale ;
- plage de corail ;
- côte volcanique tropicale ;
- banc de sable ;
- marécage salin chaud.

Règles :

- eau claire/chaude ;
- végétation de palmiers/mangroves ;
- transition mer-terre très riche.

#### Biome : ocean

Sous-biomes :

- océan peu profond ;
- océan profond ;
- plateau continental ;
- kelp forest ;
- récif corallien ;
- herbiers marins ;
- fosse océanique ;
- mont sous-marin ;
- champ hydrothermal ;
- banquise marine ;
- mer froide ;
- mer chaude ;
- mer tropicale turquoise ;
- mer sombre tempétueuse ;
- mer toxique RPG ;
- océan alien bioluminescent.

Règles :

- profondeur pilote lumière, faune, matériaux ;
- transitions par bathymétrie ;
- météo et vagues liées aux vents.

### 8.11. Souterrain, grottes, karst

#### Biome : cave_system

Sous-biomes :

- grotte calcaire ;
- grotte de basalte ;
- grotte de glace ;
- grotte humide ;
- grotte sèche ;
- rivière souterraine ;
- lac souterrain ;
- gouffre ;
- doline ;
- réseau karstique ;
- cathédrale souterraine ;
- grotte de cristaux ;
- caverne de champignons ;
- grotte de racines ;
- tunnel de lave ;
- mine abandonnée ;
- grotte toxique ;
- grotte bioluminescente ;
- cavité chaude géothermale ;
- caverne alien.

Règles :

- biome 3D dépendant volume/SDF ;
- obscurité ;
- humidité ;
- props minéraux ;
- faune spécifique ;
- transitions par entrées/cavités.

### 8.12. Volcanique et géothermique

#### Biome : volcanic

Sous-biomes :

- champ de lave récente ;
- coulée refroidie ;
- cendres volcaniques ;
- cône volcanique ;
- caldeira ;
- fumerolles ;
- geysers ;
- sources chaudes ;
- sol soufré ;
- forêt pionnière sur lave ;
- désert noir ;
- tunnel de lave ;
- lac acide ;
- plage de sable noir ;
- volcan enneigé ;
- cratère actif ;
- champ d'obsidienne.

Règles :

- forte signature matériau ;
- chaleur locale ;
- végétation rare puis pionnière ;
- gameplay danger chaleur/gaz/lave.

### 8.13. Biomes anthropisés / civilisation

#### Biome : rural

Sous-biomes :

- champs cultivés ;
- verger ;
- vignoble ;
- bocage ;
- prairie pâturée ;
- ferme isolée ;
- chemin rural ;
- fossés ;
- haies ;
- moulin ;
- grange ;
- village agricole ;
- rizière ;
- terrasse agricole ;
- canal d'irrigation ;
- champ abandonné ;
- friche agricole.

Règles :

- géométrie plus régulière ;
- props manufacturés ;
- transitions vers nature via friche/haies.

#### Biome : urban_light

Sous-biomes :

- village ;
- bourg ;
- quartier résidentiel ;
- ruelle ;
- parc urbain ;
- jardin ;
- zone pavillonnaire ;
- place ;
- marché ;
- cimetière ;
- route bordée d'arbres ;
- chantier ;
- zone portuaire légère ;
- friche urbaine.

Règles :

- support époque/tech du seed ;
- routes et bâtiments déterministes ;
- biomes naturels modifiés.

#### Biome : industrial

Sous-biomes :

- usine ;
- entrepôts ;
- raffinerie ;
- mine à ciel ouvert ;
- carrière ;
- décharge ;
- voie ferrée ;
- pipeline ;
- centrale électrique ;
- zone portuaire ;
- chantier naval ;
- zone toxique ;
- ville abandonnée ;
- robotized facility sci-fi ;
- arcologie future.

Règles :

- sols pollués ;
- props métal/béton ;
- végétation réduite ou friche ;
- dangers et ressources spécifiques.

### 8.14. Post-catastrophe / ruines / monde transformé

#### Biome : post_apocalyptic

Sous-biomes :

- forêt reconquise ;
- ville envahie par végétation ;
- désert urbain ;
- zone radioactive ;
- marais toxique ;
- cratère d'impact ;
- ruines sèches ;
- ruines inondées ;
- métro effondré ;
- autoroute envahie ;
- bunker abandonné ;
- champ de carcasses ;
- forêt mutée ;
- poussière permanente ;
- zone de tempête électromagnétique ;
- zone sans vie.

Règles :

- couplage fort RPG ;
- anomalies ;
- ressources rares ;
- props narratifs procéduraux.

### 8.15. Fantastique / magique / corrompu

#### Biome : enchanted_forest

Sous-biomes :

- forêt lumineuse ;
- clairière sacrée ;
- arbres géants ;
- champignons géants ;
- ruisseau magique ;
- brume enchantée ;
- pierres runiques ;
- fleurs luminescentes ;
- forêt temporelle ;
- forêt miroir ;
- forêt de lucioles ;
- bosquet ancien ;
- racines vivantes ;
- sanctuaire naturel.

Règles :

- anomalies positives ;
- lumière non réaliste contrôlée ;
- effets particules ;
- gameplay pouvoirs/ressources.

#### Biome : corrupted_land

Sous-biomes :

- forêt morte ;
- marais noir ;
- sol craquelé ;
- cristaux sombres ;
- racines corrompues ;
- brouillard toxique ;
- rivière noire ;
- village maudit ;
- cratère de corruption ;
- champ d'ossements ;
- fungal blight ;
- zone rouge pulsante ;
- biome cauchemar ;
- zone sans ombre ;
- pluie noire.

Règles :

- propagation par fronts ;
- transitions avec nature très importantes ;
- règles RPG : ennemis, malédictions, purification.

### 8.16. Alien / sci-fi

#### Biome : alien_crystal

Sous-biomes :

- champ de cristaux ;
- forêt de cristaux ;
- grotte prismatique ;
- dunes de verre ;
- canyon cristallin ;
- lac minéral ;
- récif cristallin ;
- colonnes hexagonales ;
- plaine réfléchissante ;
- cristaux flottants ;
- poussière luminescente ;
- biome fractal.

Règles :

- matériaux non terrestres ;
- propagation par anomalies ;
- gameplay : énergie, réflexion, dangers.

#### Biome : alien_bioluminescent

Sous-biomes :

- forêt bioluminescente ;
- marais lumineux ;
- champignonnière géante ;
- prairie phosphorescente ;
- rivière luminescente ;
- grotte organique ;
- récif aérien ;
- jungle alien ;
- plaine de spores ;
- zone respirante ;
- plantes sensibles ;
- biome nocturne permanent.

Règles :

- contraste jour/nuit ;
- FX légers mais nombreux ;
- faune/props interactifs.

#### Biome : techno_organic

Sous-biomes :

- forêt de câbles ;
- ruines cybernétiques ;
- sol nanite ;
- métal vivant ;
- jardin artificiel ;
- biome terraformé ;
- serre géante ;
- désert de panneaux solaires ;
- colonie abandonnée ;
- usine organique ;
- matrice urbaine envahie ;
- circuit canyon.

Règles :

- dépend du niveau technologique du seed ;
- peut remplacer tout biome naturel selon scénario.

---

## 9. Règles de variantes

### 9.1. Variantes par seed global

Le seed doit pouvoir modifier :

- palette globale de couleurs ;
- fréquence des biomes rares ;
- quantité d'eau ;
- intensité des montagnes ;
- humidité globale ;
- niveau de corruption/anomalie ;
- époque technologique ;
- densité de civilisation ;
- biodiversité ;
- agressivité de la météo ;
- largeur des transitions ;
- distribution de ressources.

Exemple :

```text
Seed A : monde tempéré humide, beaucoup de forêts, marais, lacs, ruines anciennes.
Seed B : monde chaud aride, oasis rares, canyons, villes minières, tempêtes de sable.
Seed C : monde froid, taïga, toundra, glaciers, grottes de glace, faible civilisation.
Seed D : planète alien, biomes cristallins, marais luminescents, météo électrique.
```

### 9.2. Variantes par biome

Chaque biome peut avoir des variantes paramétriques :

```swift
struct BiomeVariantProfile: Codable, Hashable {
    let vegetationDensityBias: Float
    let treeHeightBias: Float
    let rockinessBias: Float
    let waterPresenceBias: Float
    let colorHueShift: Float
    let saturationBias: Float
    let propDecayBias: Float
    let faunaDensityBias: Float
    let hazardBias: Float
    let rarityMultiplier: Float
}
```

### 9.3. Variantes par micro-climat

Un même biome change localement :

- versant nord : plus humide/froid ;
- versant sud : plus sec/chaud ;
- vallée : brouillard, humidité ;
- crête : vent, peu d'arbres ;
- pied de falaise : mousse, humidité ;
- proche rivière : ripisylve ;
- sol peu profond : prairie/lande ;
- sol profond : forêt.

### 9.4. Variantes saisonnières

Chaque biome définit :

- couleurs par saison ;
- densité feuilles ;
- neige accumulée ;
- floraison ;
- niveau d'eau ;
- boue ;
- feuillages morts ;
- faune active ;
- sons ;
- météo probable.

La saison ne doit pas changer le biome, mais changer son **état**.

```swift
struct BiomeSeasonalState {
    let leafAmount: Float
    let flowerAmount: Float
    let snowCoverage: Float
    let mudAmount: Float
    let waterLevel: Float
    let fireRisk: Float
    let animalActivity: Float
}
```

---

## 10. Règles de génération détaillées

### 10.1. Règle : altitude

```text
if elevation high and temperature low -> alpine / snow / glacier
if elevation high and humidity high -> cloud forest / alpine meadow
if elevation high and aridity high -> arid mountain / cold desert
```

L'altitude modifie la température :

```text
temperatureAdjusted = baseTemperature - elevation * lapseRate
```

Mais on doit aussi moduler avec exposition, vent, humidité et latitude simulée.

### 10.2. Règle : distance à l'eau

```text
if waterDistance < 10m -> bank micro-habitat
if waterDistance < 50m and humidity high -> riparian sub-biome
if arid and waterDistance < 100m -> oasis corridor
if low slope + high groundwater -> wetland
```

### 10.3. Règle : pente

```text
if slope > cliffThreshold -> cliff sub-biome
if slope > steepThreshold and soilDepth low -> rock exposure
if slope moderate and humidity high -> mossy slope
if slope low and drainage poor -> marsh/prairie humide
```

### 10.4. Règle : sol

| Sol | Biomes favorisés |
|---|---|
| sableux | pinède sèche, dune, plage, désert |
| argileux | marais, prairie humide, forêt humide |
| humifère | forêt tempérée, rainforest |
| rocheux | montagne, désert rocheux, lande |
| salin | marais salant, désert de sel, mangrove |
| cendreux | volcanique, forêt pionnière |
| tourbeux | tourbière, taïga humide |
| artificiel | urbain, route, industriel |

### 10.5. Règle : rain shadow

Une montagne doit pouvoir créer :

- versant au vent : forêt humide / cloud forest ;
- crête : alpage / roche / neige ;
- versant sous le vent : steppe / désert froid / savane sèche.

Implémentation simplifiée :

```text
orographicRain = dot(windDirection, terrainGradient) * elevationFactor
rainShadow = accumulatedMountainBarrierAlongWind
precipitation = basePrecipitation + orographicRain - rainShadow
```

### 10.6. Règle : perturbation écologique

Perturbations possibles :

- feu ;
- crue ;
- avalanche ;
- glissement de terrain ;
- tempête ;
- sécheresse ;
- activité humaine ;
- pollution ;
- magie/corruption ;
- invasion biologique ;
- chute de météorite ;
- guerre/ruine.

Elles créent des sous-biomes temporaires ou permanents : forêt brûlée, prairie post-feu, ruines végétalisées, marais toxique, cratère, etc.

---

## 11. Gestion des matériaux et rendu

### 11.1. BiomeMaterialPalette

Chaque biome définit :

- base albedo/hue ;
- roughness ;
- normal strength ;
- micro-detail ;
- wetness response ;
- snow response ;
- mud response ;
- debris layer ;
- vegetation tint ;
- water tint ;
- fog tint ;
- sky influence.

```swift
struct BiomeMaterialPalette: Codable, Hashable {
    let groundMaterials: [WeightedMaterial]
    let rockMaterials: [WeightedMaterial]
    let vegetationTints: [ColorGradientStop]
    let waterTint: SIMD3<Float>
    let fogTint: SIMD3<Float>
    let snowCompatibility: Float
    let wetnessCompatibility: Float
    let dustCompatibility: Float
}
```

### 11.2. Blending matériaux

Le renderer ne doit pas recevoir un seul biome mais une **BiomeSplatMap**.

```text
R channel : biome/material A weight
G channel : biome/material B weight
B channel : biome/material C weight
A channel : transition/micro-detail mask
```

Pour plus de biomes, utiliser :

- texture arrays ;
- virtual textures ;
- indirection table par chunk ;
- top-k material IDs + weights ;
- compute pass pour générer la carte de poids.

### 11.3. Règles visuelles de transition

Exemples :

- forêt -> prairie : humus se dilue vers herbe claire ;
- désert -> steppe : sable + touffes + cailloux ;
- montagne -> neige : roche nue + plaques de neige dans creux ;
- marais -> forêt : boue + eau + racines + mousse ;
- côte -> forêt : sable -> dune végétalisée -> lisière salée ;
- corruption -> forêt : veines sombres + végétation malade + particules faibles.

---

## 12. Règles de props, végétation et faune

Le BiomeSystem ne génère pas lui-même tous les props ; il fournit des **contraintes et poids** aux systèmes de props/faune.

### 12.1. Prop density fields

Chaque biome produit :

- treeDensity ;
- shrubDensity ;
- grassDensity ;
- rockDensity ;
- deadWoodDensity ;
- flowerDensity ;
- waterPlantDensity ;
- humanPropDensity ;
- rareLandmarkDensity ;
- climbableDensity ;
- resourceDensity.

### 12.2. Exemple de règle props

```text
Biome: temperate_broadleaf_forest
if slope < 20° and soilDepth > 0.5 and sunlight < 0.6:
    spawn ferns, moss, dead leaves
if distanceToWater < 30m:
    increase alder/willow, mud, roots
if edgeWeight > 0.4:
    increase shrubs, flowers, small trees
```

### 12.3. Faune

La faune dépend de :

- biome dominant ;
- transition biome ;
- saison ;
- heure ;
- densité végétale ;
- distance à l'eau ;
- présence humaine ;
- niveau d'hostilité RPG ;
- bruit du joueur ;
- météo.

Exemple :

```text
wolf habitat = taiga/forest + distanceToWater moderate + low civilization + cold/temperate + preyDensity high
frog habitat = wetland/riparian + humidity high + night/rain + low salinity
```

---

## 13. Biome Graph : compatibilités et transitions

### 13.1. Pourquoi un graphe ?

Sans graphe, on peut obtenir des transitions absurdes : glacier directement contre mangrove, jungle collée à désert polaire, océan profond sur falaise intérieure.

Le graphe définit :

- compatibilité directe ;
- transition obligatoire ;
- incompatibilité sauf anomalie ;
- largeur min/max ;
- priorité ;
- biome intermédiaire.

### 13.2. Exemple

```json
{
  "from": "hot_sandy_desert",
  "to": "temperate_broadleaf_forest",
  "compatibility": 0.1,
  "requiresIntermediate": ["semi_arid_steppe", "savanna", "scrubland"],
  "defaultTransition": "dry_forest_edge",
  "minWidthMeters": 800,
  "maxWidthMeters": 3000
}
```

### 13.3. Types d'adjacence

```swift
enum BiomeAdjacencyType: String, Codable {
    case natural
    case rare
    case requiresEcotone
    case requiresAltitudeBand
    case requiresWaterCorridor
    case requiresAnomaly
    case forbidden
}
```

### 13.4. Transition matrix simplifiée

| De / Vers | Forêt | Prairie | Désert | Montagne | Marais | Côte | Urbain | Corruption |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Forêt | naturel | lisière | savane/scrub | piémont | forêt humide | forêt côtière | friche | forêt malade |
| Prairie | lisière | naturel | steppe sèche | alpage | prairie humide | dune herbeuse | champs | prairie corrompue |
| Désert | scrub | steppe | naturel | montagne aride | oasis | plage aride | mine/route | désert noir |
| Montagne | subalpin | alpage | canyon | naturel | ravin humide | falaise côtière | village col | crête maudite |
| Marais | forêt marécageuse | prairie humide | oasis rare | tourbière alpine | naturel | mangrove/salant | canal | marais toxique |
| Côte | forêt côtière | dune | plage aride | fjord | estuaire | naturel | port | côte morte |
| Urbain | friche | champs | mine | village alpin | canal | port | naturel | ruine |
| Corruption | forêt malade | prairie noire | désert noir | crête maudite | marais toxique | côte morte | ruine | naturel |

---

## 14. Dynamic Biome State : biomes vivants

Un biome n'est pas figé. Il a un état dynamique mais déterministe/reproductible.

### 14.1. États possibles

- normal ;
- humide ;
- sec ;
- en feu ;
- brûlé ;
- inondé ;
- gelé ;
- enneigé ;
- en floraison ;
- en sécheresse ;
- pollué ;
- corrompu ;
- purifié ;
- colonisé ;
- abandonné ;
- exploité ;
- en régénération.

### 14.2. State resolver

```swift
struct BiomeRuntimeState {
    let wetness: Float
    let snow: Float
    let drought: Float
    let burn: Float
    let flood: Float
    let corruption: Float
    let humanImpact: Float
    let regeneration: Float
}
```

### 14.3. Déterminisme temporel

Pour garder le déterminisme :

- événements majeurs tirés depuis seed + région ;
- temps mondial discret (`worldDay`, `seasonIndex`) ;
- état sauvegardé uniquement si le joueur modifie le monde ;
- sinon état recalculable.

---

## 15. Intégration avec les chunks IsoWorld

### 15.1. Ce qu'un chunk doit stocker

```swift
struct ChunkBiomeData {
    let chunkCoord: ChunkCoord
    let biomeWeightsTextureHandle: TextureHandle
    let dominantBiomeGrid: [BiomeID]
    let subBiomeGrid: [SubBiomeID]
    let transitionGrid: [TransitionID?]
    let materialPaletteIndices: [UInt16]
    let propDensityFields: PropDensityFields
    let faunaHabitatFields: FaunaHabitatFields
    let gameplaySurfaceFields: GameplaySurfaceFields
}
```

### 15.2. Résolution multi-résolution

- Macro biome grid : 256 m à 1 km par sample.
- Meso biome grid : 16 m à 64 m par sample.
- Micro habitat grid : 1 m à 4 m par sample pour collision/material gameplay.
- Material splat : résolution dépendante du terrain/chunk.

### 15.3. Seamless chunks

Pour éviter seams :

- toujours sampler les champs en coordonnées monde absolues ;
- jamais générer des noises avec origine locale du chunk ;
- prévoir une marge `borderPadding` pour transitions ;
- générer les features avec ownership déterministe : une feature appartient au chunk contenant son anchor point, mais peut déborder ;
- cache des voisins pour props volumineux.

---

## 16. Debug tools indispensables

### 16.1. Overlays

- Dominant biome map.
- Top 3 biome weights.
- Climate temperature.
- Humidity.
- Precipitation.
- Aridity.
- Continentality.
- Elevation.
- Slope.
- Soil depth.
- Water distance.
- Transition width.
- Ecotone ID.
- Sub-biome ID.
- Prop density maps.
- Fauna habitat maps.
- Material IDs.
- Rule winner / rejected rules.

### 16.2. Inspecteur de position

À la position du curseur/joueur :

```text
Biome primary: temperate_broadleaf_forest 0.62
Biome secondary: wetland 0.24
Transition: forest_to_wetland_edge
SubBiome: ravin_moussu
Temperature: 0.43
Humidity: 0.82
WaterDistance: 18m
Slope: 12°
SoilDepth: 0.74
Prop rules active: moss + ferns + roots + deadwood
Fauna habitat: frogs 0.6, deer 0.3, insects 0.8
Gameplay surface: wet_mud / medium friction / footprint yes
```

### 16.3. Seed explorer

Outil pour tester :

- distribution des biomes par seed ;
- nombre de transitions ;
- rareté des biomes ;
- pourcentage océan/terre ;
- histogrammes température/humidité ;
- recherche de seed avec contraintes : “monde froid + beaucoup de montagnes + peu d'océans”.

---

## 17. Performance et budget runtime

### 17.1. Règle fondamentale

Ne pas simuler une écologie complète runtime. Simuler seulement les champs nécessaires à la cohérence visuelle/gameplay.

### 17.2. Ce qui peut être CPU

- sélection macro/meso des biomes ;
- règles de biome ;
- graph adjacency ;
- génération de tables par chunk ;
- décisions de sous-biomes ;
- debug.

### 17.3. Ce qui peut être GPU/Metal compute

- génération de splat maps ;
- masks de matériaux ;
- density fields pour props ;
- blending visuel ;
- cartes de bruit haute résolution ;
- scattering massif de végétation ;
- pré-culling instance indirect.

### 17.4. Caching

Caches recommandés :

- `ClimateTileCache` à basse résolution ;
- `BiomeTileCache` par région ;
- `ChunkBiomeCache` ;
- `MaterialWeightCache` ;
- `PropDensityCache` ;
- `DebugOverlayCache`.

### 17.5. Niveaux de détail des biomes

- LOD0 proche : micro-habitats, props précis, matériaux détaillés.
- LOD1 moyen : sous-biome + densités simplifiées.
- LOD2 loin : biome dominant + couleur/terrain simplifié.
- LOD3 horizon : macro biome tint + atmosphère.

---

## 18. Système data-driven : exemple de fichier biome

```json
{
  "id": "temperate_broadleaf_forest",
  "displayName": "Forêt tempérée feuillue",
  "globalFamily": "temperate_forest",
  "rarity": 1.0,
  "climateEnvelope": {
    "temperatureRange": [-0.1, 0.55],
    "humidityRange": [0.45, 0.95],
    "precipitationRange": [0.35, 0.9],
    "aridityRange": [0.0, 0.45],
    "frostRiskRange": [0.0, 0.65],
    "seasonalityRange": [0.35, 0.95],
    "fuzzyFalloff": 0.25
  },
  "terrainEnvelope": {
    "elevationRange": [0.05, 0.65],
    "slopeRange": [0.0, 0.55],
    "ruggednessRange": [0.0, 0.6],
    "soilDepthRange": [0.35, 1.0]
  },
  "subBiomes": [
    "beech_core",
    "oak_core",
    "forest_edge",
    "fern_understory",
    "mossy_ravine",
    "riverine_forest",
    "autumn_grove",
    "ancient_forest_patch"
  ],
  "transitionProfile": {
    "defaultSoftnessMeters": 180,
    "edgePropBoost": 0.35,
    "materialBlendCurve": "smoothstep"
  }
}
```

---

## 19. Roadmap d'implémentation IsoWorld

### Phase 1 — Biome fields minimalistes mais solides

Objectif : remplacer `biome enum simple` par des champs continus.

- `ClimateSample` : temperature, humidity, continentality, elevation, slope.
- 8 biomes initiaux : forêt tempérée, prairie, désert, montagne, marais, taïga, côte, eau douce.
- Top-2 biome weights.
- Transition forest/prairie/désert/marais.
- Debug overlay.

### Phase 2 — Sous-biomes et matériaux

- Ajouter 5 à 10 sous-biomes par biome.
- Générer splat maps par poids.
- Ajouter micro-habitats : rive, pente, falaise, pied de falaise, clairière.
- Connecter au système de props.

### Phase 3 — BiomeGraph complet

- Définir compatibilités.
- Ajouter transitions explicites.
- Ajouter largeur adaptative.
- Ajouter interdictions/anomalies.

### Phase 4 — Hydrologie et écotones riches

- Rivières comme corridors biomes.
- Lacs, deltas, marais, oasis.
- Transitions eau-terre.
- Biomes humides locaux dans biomes secs.

### Phase 5 — WorldBiomeDNA

- Seed modifie climat global, diversité, anomalies, RPG.
- Générer mondes radicalement différents.
- Seed explorer.

### Phase 6 — Dynamique saison/météo/RPG

- États de biome.
- Incendies, inondations, neige, sécheresse.
- Corruption/purification.
- Civilisation/ruines selon époque.

### Phase 7 — Biomes avancés/alien

- Fantastique.
- Sci-fi.
- Techno-organique.
- Corruption.
- Post-catastrophe.

---

## 20. Recommandations clés

1. **Biome = écorégion multi-couche**, pas simple texture.
2. **Toujours garder des poids**, pas un unique biome ID.
3. **Créer des écotones explicites** avec contenu propre.
4. **Utiliser un BiomeGraph** pour éviter les transitions absurdes.
5. **Inclure terrain, sol, eau, pente et altitude** dans la sélection.
6. **Prévoir le seed comme ADN du monde**, pas seulement comme random source.
7. **Faire des biomes data-driven** pour pouvoir ajouter/retirer sans casser le moteur.
8. **Créer des debug overlays dès le début**.
9. **Séparer biome global, sous-biome, micro-habitat et état dynamique**.
10. **Préparer les transitions comme zones de gameplay riches** : lisières, berges, piémonts, ravins, dunes, marais, ruines envahies.

---

## 21. Checklist technique

- [ ] `WorldBiomeDNA` généré depuis seed.
- [ ] `ClimateFieldProvider` déterministe.
- [ ] `GeoHydroFieldProvider` branché sur terrain.
- [ ] `BiomeDefinition` data-driven.
- [ ] `SubBiomeDefinition` data-driven.
- [ ] `TransitionRule` data-driven.
- [ ] `BiomeGraph` avec compatibilités.
- [ ] `BiomeSelector` top-k weights.
- [ ] `EcotoneResolver` explicite.
- [ ] `SubBiomeResolver` local.
- [ ] `ChunkBiomeData` cache.
- [ ] `BiomeSplatMap` pour renderer Metal.
- [ ] `PropDensityFields` pour PropSystem.
- [ ] `FaunaHabitatFields` pour FaunaSystem.
- [ ] `GameplaySurfaceFields` pour animation/collision.
- [ ] Overlay debug.
- [ ] Seed explorer.

---

## 22. Glossaire

- **Biome** : grande unité écologique/environnementale.
- **Sous-biome** : variation locale ou régionale d'un biome.
- **Écotone** : zone de transition entre deux biomes.
- **Micro-habitat** : niche locale issue de géométrie, eau, ombre, pente ou sol.
- **Climate field** : carte continue de paramètres climatiques.
- **GeoHydro field** : carte continue de paramètres terrain/eau/sol.
- **Biome weight** : influence pondérée d'un biome à une position.
- **BiomeGraph** : graphe de compatibilité et transitions entre biomes.
- **WorldBiomeDNA** : identité globale du monde dérivée du seed.
- **Transition biome** : biome procédural spécialisé pour une frontière.

---

## 23. Sources consultées

- Epic Games — PCG Biome Core and Sample Plugins : https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-pcg-biome-core-and-sample-plugins-in-unreal-engine
- Epic Games — Procedural Content Generation Overview : https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-overview
- Microsoft Learn — Minecraft World Generation Overview : https://learn.microsoft.com/en-us/minecraft/creator/documents/world-generation
- Microsoft Learn — Minecraft Biome Components : https://learn.microsoft.com/en-us/minecraft/creator/reference/content/biomesreference/examples/components/biome_components
- FAO / WWF — Terrestrial Ecoregions of the World : https://www.fao.org/land-water/land/land-governance/land-resources-planning-toolbox/category/details/en/c/1036295/
- US EPA — Ecoregions : https://www.epa.gov/eco-research/ecoregions
- USDA Forest Service — Holdridge life zones of the conterminous United States : https://research.fs.usda.gov/treesearch/30306
- Fischer et al. — AutoBiomes: procedural generation of multi-biome landscapes : https://link.springer.com/article/10.1007/s00371-020-01920-7
- GDC Vault — Procedural World Generation of Far Cry 5 : https://www.gdcvault.com/play/1025557/Procedural-World-Generation-of-Far
- GDC Vault — Ghost Recon Wildlands: Terrain Tools and Technology : https://www.gdcvault.com/play/1024029/-ghost-recon-wildlands-terrain
- Alan Zucconi — The World Generation of Minecraft : https://www.alanzucconi.com/2022/06/05/minecraft-world-generation/
- NoisePosti.ng — Fast Biome Blending, Without Squareness : https://noiseposti.ng/posts/2021-03-13-Fast-Biome-Blending-Without-Squareness.html
