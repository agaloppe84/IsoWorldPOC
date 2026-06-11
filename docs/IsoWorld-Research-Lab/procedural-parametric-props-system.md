# Système de props procéduraux/paramétriques ultra versatile pour IsoWorld

**Sujet dédié :** point 4 — générer un panel extrêmement large et varié de props procéduraux/paramétriques : arbres, rochers, cailloux, plantes, animaux, objets manufacturés, tables, lampadaires, artefacts, détails environnementaux, etc.

**Contexte cible :** IsoWorld, moteur custom Swift/Metal sur macOS, monde déterministe par seed, génération dynamique autour du joueur, chunks, rendu temps réel haute qualité.

**But du document :** définir une architecture moderne, robuste, déterministe, extensible et scalable pour produire des props haute qualité à partir de règles, de recettes, de paramètres et de générateurs spécialisés.

---

## 1. Vision globale

Le système de props d'IsoWorld ne doit pas être un simple scatter de meshes préfabriqués. Il doit devenir un **Prop Generation System** complet, capable de produire des objets crédibles, lisibles, stylisés ou réalistes, adaptables au biome, à l'époque, au niveau technologique, aux règles du seed, à l'histoire locale du monde, à l'altitude, au climat, aux contraintes physiques et aux besoins de gameplay.

L'objectif n'est pas forcément de tout générer géométriquement au runtime. Le bon modèle est hybride :

1. **Des générateurs procéduraux déterministes** produisent des recettes, des formes, des variantes, des matériaux et des métadonnées.
2. **Des assets paramétriques** servent de base : primitives, kits modulaires, profils de branches, feuilles, vis, pierres, planches, tissus, câbles, pièces mécaniques, etc.
3. **Des règles contextuelles** décident quoi générer, où, pourquoi, avec quelle rareté et quelles contraintes.
4. **Un pipeline de cache** transforme les recettes en géométrie, instances, matériaux, collisions, LOD, imposteurs et proxies de gameplay.
5. **Un renderer GPU-friendly** affiche des milliers ou millions de petits éléments avec instancing, culling, LOD, meshlets/imposteurs et matériaux groupés.

Une bonne phrase de design :

> Un prop IsoWorld est une instance déterministe d'une recette paramétrique, évaluée dans un contexte de monde, enrichie par des règles écologiques, culturelles, physiques et narratives, puis convertie en représentation render/gameplay optimisée.

---

## 2. Inspirations industrielles et techniques

Le système proposé mélange plusieurs familles de pratiques déjà utilisées dans l'industrie ou la recherche :

- **Houdini / HDAs / PDG** : générateurs node-based, recettes procédurales, assets numériques versionnés, batch/offline generation, paramètres exposés aux artistes.
- **Unreal PCG** : graphes de génération, points porteurs d'attributs, règles de placement, seeds par point, density/steepness/bounds, runtime hierarchical generation.
- **SpeedTree** : générateurs spécialisés pour végétation, variation contrôlée, LOD dynamique, wind, billboards/imposteurs, authoring artistique + générateurs.
- **Blender Geometry Nodes / Infinigen** : génération procédurale de formes et matériaux, composition de scènes entières, randomisation contrôlée, diversité à grande échelle.
- **USD / glTF / MaterialX / OpenPBR** : représentation structurée, variantes d'assets, matériaux portables, séparation entre authoring et runtime.
- **L-systems, shape grammars, WFC, SDF/CSG, space colonization, procedural materials** : familles algorithmiques fondamentales.
- **GPU-driven rendering moderne** : instancing, argument buffers, indirect draws, culling GPU, meshlets, sparse/virtual textures, imposteurs.

L'idée n'est pas de copier un outil existant, mais de construire un système IsoWorld qui reprend les bons patterns : **recettes paramétriques + règles + attributs + génération multi-niveau + cache + rendu optimisé**.

---

## 3. Définition d'un prop dans IsoWorld

Un prop ne doit pas être seulement un mesh. Il doit contenir plusieurs couches.

### 3.1 Couches d'un prop

1. **Identité**
   - `propType`: arbre, rocher, chaise, lampe, champignon, ossement, coffre, antenne, ruine, etc.
   - `archetypeId`: chêne_tordu, granite_mossy_boulder, lampadaire_industriel, table_rustique, etc.
   - `variantId`: hash déterministe de la variante générée.
   - `generatorVersion`: version du générateur pour stabilité et migration.

2. **Contexte**
   - seed monde.
   - seed chunk.
   - biome global.
   - sous-biome.
   - altitude, pente, humidité, température, vent, exposition solaire, distance à l'eau.
   - époque/civilisation/tech level/faction.
   - proximité de POI, route, village, ruine, rivière, falaise.
   - état narratif local.

3. **Recette paramétrique**
   - dimensions.
   - proportions.
   - nombre de parties.
   - règles d'assemblage.
   - matériaux.
   - usure.
   - âge.
   - orientation.
   - animation passive éventuelle.
   - collisions.
   - tags gameplay.

4. **Géométrie**
   - mesh principal.
   - sous-meshes.
   - geometry patches.
   - meshlets / clusters.
   - variantes de LOD.
   - imposteurs.
   - collision proxy.
   - occlusion proxy.

5. **Matériaux**
   - material family : bois, roche, métal, tissu, céramique, peau, feuille, verre.
   - paramètres PBR : albedo, roughness, metallic, normal, height, AO, thickness, translucency, subsurface, clearcoat, fuzz.
   - masques procéduraux : mousse, saleté, humidité, neige, poussière, rouille, brûlure, peinture écaillée.

6. **Sémantique**
   - destructible ou non.
   - récoltable ou non.
   - grimpable, franchissable, bloquant, décoratif.
   - source de lumière.
   - source de son.
   - source de particules.
   - abri, obstacle, loot container, ressource, indice narratif.

7. **Simulation et interaction**
   - rigid body, static collider, trigger, cloth, skeletal/articulated, vegetation wind, breakable chunks.
   - état runtime minimal et déterministe.

---

## 4. Principe architectural : PropFactory + PropRecipe + PropRuntimeProxy

Le système doit séparer strictement la **recette** de la **représentation runtime**.

### 4.1 PropRecipe

La recette est le coeur déterministe : elle doit pouvoir être régénérée à l'identique depuis le seed.

Exemple conceptuel Swift :

```swift
public struct PropRecipe: Hashable, Codable {
    public let stableId: UInt64
    public let archetypeId: String
    public let generatorId: String
    public let generatorVersion: UInt32
    public let worldSeed: UInt64
    public let contextHash: UInt64
    public let parameters: PropParameterSet
    public let materialPlan: MaterialPlan
    public let semanticTags: PropSemanticTags
    public let lodPolicy: PropLODPolicy
    public let physicsPolicy: PropPhysicsPolicy
}
```

### 4.2 PropGenerator

Un générateur ne doit pas directement « dessiner ». Il doit produire un `PropBuildPlan`.

```swift
public protocol PropGenerator {
    var id: String { get }
    var version: UInt32 { get }
    var supportedFamilies: [PropFamily] { get }

    func makeRecipe(context: PropContext, rng: inout DeterministicRNG) -> PropRecipe
    func buildPlan(from recipe: PropRecipe) -> PropBuildPlan
}
```

### 4.3 PropBuildPlan

Le plan décrit ce qui doit être produit : géométrie, matériaux, collisions, LOD, metadata. Il peut être évalué en mode rapide ou en mode haute qualité.

```swift
public struct PropBuildPlan {
    public let geometryOps: [GeometryOp]
    public let materialOps: [MaterialOp]
    public let scatterOps: [SubElementScatterOp]
    public let deformationOps: [DeformationOp]
    public let collisionOps: [CollisionOp]
    public let lodOps: [LODOp]
    public let validationRules: [PropValidationRule]
}
```

### 4.4 PropRuntimeProxy

Le runtime ne doit garder que ce qui est nécessaire au rendu et au gameplay.

```swift
public struct PropRuntimeProxy {
    public let stableId: UInt64
    public let transform: Transform3D
    public let renderAssetHandle: RenderAssetHandle
    public let materialInstanceHandle: MaterialInstanceHandle
    public let bounds: BoundingBox
    public let collisionHandle: CollisionHandle?
    public let semanticFlags: UInt64
    public let interactionState: PropInteractionState?
}
```

---

## 5. Règle absolue : déterminisme stable, mais monde radicalement variable

Le monde doit changer radicalement au changement de seed, mais rester parfaitement stable pour un seed donné.

### 5.1 Hiérarchie de seeds

Utiliser une dérivation stricte :

```text
worldSeed
  -> regionSeed(regionCoord)
    -> chunkSeed(chunkCoord)
      -> placementCellSeed(cellCoord)
        -> propSlotSeed(slotIndex, layerId)
          -> propRecipeSeed(archetypeId, generatorVersion)
```

Chaque prop doit être reproductible sans dépendre de l'ordre d'évaluation. Cela interdit les RNG globaux consommés séquentiellement par le streaming. Il faut toujours dériver les seeds depuis des identifiants stables.

### 5.2 StableId recommandé

```text
stableId = hash64(
  worldSeed,
  dimensionId,
  regionCoord,
  chunkCoord,
  localCellCoord,
  propLayerId,
  slotIndex,
  archetypeId,
  generatorVersion
)
```

### 5.3 Versioning

Le générateur doit avoir une version. Si on modifie fortement l'algorithme, un vieux monde peut changer. Il faut donc choisir une politique :

- en prototype : accepter les changements ;
- en sauvegarde stable : stocker `generatorVersion` et `recipeHash` ;
- pour un monde existant : garder les anciennes recettes déjà découvertes si nécessaire.

---

## 6. Les trois niveaux de génération

### 6.1 Niveau A — sélection et placement

Question : quel prop existe à tel endroit ?

Entrées : biome, sous-biome, pente, altitude, humidité, température, sol, proximité eau, époque, civilisation, densité, POI, rareté, gameplay.

Sortie : slots de props avec type/archetype/transform approximatif.

### 6.2 Niveau B — recette et variante

Question : à quoi ressemble ce prop précisément ?

Entrées : slot seed, contexte local, archetype, contraintes.

Sortie : dimensions, forme, matériaux, âge, usure, couleur, asymétrie, détails, capacité d'interaction.

### 6.3 Niveau C — représentation render/gameplay

Question : comment l'afficher et l'interagir efficacement ?

Entrées : recette, distance caméra, budget, cache.

Sortie : mesh ou instance, LOD, imposteur, collider, material instance, tags, state minimal.

---

## 7. Familles de générateurs à prévoir

Un seul générateur universel ne suffira pas. Il faut une bibliothèque de générateurs spécialisés, connectés par un modèle commun.

### 7.1 Générateurs géométriques bas niveau

- `PrimitiveGenerator` : cube bevelé, cylindre, cône, sphère, ellipsoïde, capsule, tore, superquadrique.
- `LatheGenerator` : vases, pots, bouteilles, colonnes, pieds de table, roues.
- `SweepGenerator` : tuyaux, câbles, branches, racines, cordes, rambardes.
- `ExtrusionGenerator` : panneaux, poutres, planches, enseignes, murs, profils industriels.
- `BeveledBoxGenerator` : meubles, caisses, machines, blocs manufacturés.
- `CSGGenerator` : hard surface simple, trous, découpes, assemblages.
- `SDFGenerator` : roches, organique, usure douce, blobs, champignons, formes alien.
- `FractureGenerator` : éclats, rochers cassés, ruines, objets brisés.
- `SurfaceDetailGenerator` : fissures, bosses, strates, pores, gravures, rivets.

### 7.2 Générateurs naturels

- `TreeGenerator` : arbres feuillus, conifères, arbres morts, arbres tordus.
- `BranchingGenerator` : branches, racines, coraux, veines, éclairs cristallisés.
- `PlantGenerator` : herbes, fleurs, fougères, roseaux, plantes grasses.
- `RockGenerator` : galets, blocs, colonnes, roches stratifiées, cristaux.
- `FungusGenerator` : champignons, mycélium, polypores, moisissures.
- `NestGenerator` : nids, terriers, ruches, cocons, toiles.
- `OrganicSurfaceGenerator` : ossements, coquilles, carapaces, cornes, peaux.

### 7.3 Générateurs manufacturés

- `FurnitureGenerator` : tables, chaises, bancs, étagères, lits, coffres.
- `StreetPropGenerator` : lampadaires, panneaux, bornes, barrières, bancs, poubelles.
- `ToolGenerator` : marteaux, pelles, pinces, clés, ustensiles, instruments.
- `MachineGenerator` : pompes, turbines, moteurs, consoles, générateurs électriques.
- `ContainerGenerator` : caisses, tonneaux, sacs, jarres, coffres, bidons.
- `FabricGenerator` : tentes, drapeaux, rideaux, bâches, tapis, voiles.
- `TechPropGenerator` : antennes, capteurs, drones décoratifs, câbles, boîtiers.
- `RuinPropGenerator` : colonnes cassées, statues, dalles, murs, gravats.

### 7.4 Générateurs modulaires et grammaticaux

- `ShapeGrammarGenerator` : architecture, meubles composés, machines, façades.
- `KitAssemblyGenerator` : assemblage de pièces paramétriques compatibles.
- `WFCPropGenerator` : objets composés de tuiles/voxels/modules avec contraintes.
- `SocketGraphGenerator` : assemblages par connecteurs : pieds de table, branches, tuyaux, machines, lampadaires.
- `ConstraintSolverGenerator` : placement interne de sous-parties avec règles de non-intersection et fonctionnalité.

### 7.5 Générateurs articulés

- `ArticulatedObjectGenerator` : portes, coffres, tiroirs, leviers, machines, pièges, instruments.
- `CreatureMorphologyGenerator` : animaux simples, insectes, petits êtres, poissons, oiseaux, bestioles alien.
- `SkeletalPropGenerator` : squelette interne pour animation, IK, ragdoll léger.
- `ProceduralRigGenerator` : générer joints, axes, limites, masses, colliders.

---

## 8. Liste très longue de types de props générables

Cette liste sert de base au catalogue IsoWorld. Chaque famille peut devenir une collection d'archetypes, eux-mêmes déclinés par variantes.

### 8.1 Végétation — arbres

- chêne, hêtre, bouleau, saule, érable, frêne, orme, tilleul, peuplier, platane, châtaignier, noyer, olivier, pommier sauvage, cerisier sauvage, acacia, eucalyptus, baobab, mangrove, cyprès, séquoia, pin, sapin, épicéa, mélèze, cèdre, palmier, cocotier, palmier nain, arbre mort, arbre brûlé, arbre foudroyé, arbre creux, arbre couché, souche, tronc pourri, jeune pousse, arbre torsadé, arbre penché par le vent, arbre enneigé, arbre moussu, arbre à racines aériennes, arbre parasite, arbre cristallisé, arbre alien bioluminescent, arbre géant ancien, bonsaï naturel, arbre de savane, arbre de marais, arbre de falaise, arbre de dune, arbre sous-terrain.

### 8.2 Végétation — plantes basses

- herbe courte, herbe haute, touffe sèche, graminée, roseau, jonc, bambou jeune, bambou géant, fougère, mousse, lichen, trèfle, ortie, ronce, buisson épineux, buisson fleuri, arbuste sec, arbuste enneigé, plante rampante, liane, vigne, ivy/lierre, plante grasse, cactus boule, cactus colonne, cactus raquette, agave, aloès, fleur sauvage, tournesol sauvage, lavande, bruyère, coquelicot, tulipe sauvage, plante carnivore, nénuphar, plante aquatique, algue, varech, corail végétal fictif, spore pod, plante lumineuse, plante toxique, plante médicinale, herbe rare, champ végétal, racines apparentes.

### 8.3 Champignons, mycélium, micro-flore

- champignon à chapeau, amanite stylisée, bolet, morille, pleurote, polypore sur tronc, champignon géant, champignon bioluminescent, cercle de fées, moisissure, mycélium au sol, excroissance fongique murale, spore sac, puffball, champignon parasite, croûte de lichen, plaques de mousse, lichen pendu, mousse humide, mousse sèche, tapis de spores, filaments organiques.

### 8.4 Rochers, pierres, minéraux

- caillou rond, galet de rivière, gravier, éboulis, pierre plate, pierre pointue, boulder granitique, boulder basaltique, boulder calcaire, rocher stratifié, rocher fracturé, rocher moussu, rocher enneigé, rocher humide, rocher de plage, rocher volcanique, obsidienne, scorie, pierre ponce, stalactite, stalagmite, colonne basaltique, dalle naturelle, arche rocheuse miniature, pierre dressée, menhir, cairn, cristal quartz, cristal améthyste, cristal de sel, cristal alien, géode ouverte, minerai visible, veine minérale, dépôt sulfuré, dépôt calcaire, concrétions, os fossile dans roche, racines incrustées, rocher sculpté par le vent, rocher érodé par l'eau.

### 8.5 Détails de sol et debris naturels

- feuilles mortes, aiguilles de pin, brindilles, branches cassées, écorces, pommes de pin, glands, fruits tombés, pétales, graines, racines mortes, plaques de boue, flaques, traces de pas, traces d'animaux, griffures, plumes, poils, ossements, coquilles, carapaces, œufs cassés, nids tombés, sable accumulé, neige soufflée, glace fine, sel cristallisé, poussière, cendres, charbon de bois, gravats naturels, fissures de sol, plaques d'argile craquelée.

### 8.6 Eau, littoral, marais

- roseaux, bois flotté, coquillages, coraux, éponges, algues, nasses, filets, bouées, poteaux mouillés, cordages, pontons, petites barques, rames, ancres décoratives, caisses de pêche, paniers de poissons, crabes décoratifs, nids d'oiseaux aquatiques, blocs couverts de barnacles, herbes de marais, flaques boueuses, souches noyées, racines de mangrove, lotus, nénuphars, cascades miniatures, stalagmites de glace, plaques de glace flottante.

### 8.7 Animaux et créatures comme props/systèmes légers

- insectes décoratifs, scarabées, papillons, libellules, fourmis en file, essaims, lucioles, vers, escargots, grenouilles, lézards, petits oiseaux, poissons de surface, crabes, mollusques, petites tortues, rats, souris, écureuils, lapins, chauves-souris décoratives, serpents simples, araignées, cocons, ruches vivantes, bancs de poissons, oiseaux posés, carcasses animales, traces de tanières, animaux empaillés, squelettes de petits animaux, créatures alien passives, familiers procéduraux simples.

### 8.8 Mobilier intérieur

- table ronde, table rectangulaire, table basse, table de travail, établi, bureau, chaise simple, chaise rembourrée, tabouret, banc, fauteuil, lit simple, lit double, hamac, commode, armoire, étagère, bibliothèque, coffre, malle, caisse, tonneau, panier, vase, pot, jarre, lampe de table, chandelier, bougeoir, tapis, rideau, paravent, miroir, cadre, tableau, horloge, berceau, pupitre, chevalet, support d'arme fictif, présentoir, piédestal, autel, évier, baignoire, lavabo, toilettes anciennes, cuisine rustique, four, poêle, cheminée, brasero intérieur.

### 8.9 Mobilier extérieur et urbain

- banc public, table de pique-nique, lampadaire, réverbère, borne, barrière, clôture, poteau, panneau de direction, panneau publicitaire, panneau routier, poubelle, conteneur, boîte aux lettres, arrêt de bus, abribus, fontaine, bouche d'incendie, borne électrique, cabine téléphonique, kiosque, pot de fleurs, jardinière, sculpture urbaine, grille d'arbre, bouche d'égout, plaque métallique, cône de signalisation, bloc béton, baril de chantier, ruban de chantier, palissade, feu de circulation, horodateur, distributeur, banc cassé, lampadaire tordu.

### 8.10 Architecture modulaire et ruines

- brique, pierre de taille, dalle, tuile, poutre, pilier, colonne, arche, linteau, marche, escalier, rambarde, fenêtre, volet, porte, portail, grille, mur cassé, pan de mur, toit effondré, charpente, corniche, gargouille, statue, bas-relief, mosaïque, vitrail, colonne brisée, chapiteau, dalle gravée, tombe, stèle, sarcophage, autel, obélisque, fragment de statue, crâne décoratif, gravats, planches de barricade, poutres calcinées, sacs de sable, échafaudage, passerelle.

### 8.11 Infrastructure, transport et réseaux

- route marker, borne kilométrique, rail, traverse, aiguillage décoratif, wagonnet, roue, essieu, charrette, brouette, caisse roulante, tuyau, valve, pompe, vanne, canalisation, câble, gaine, transformateur, poteau électrique, pylône, antenne, parabole, panneau solaire, éolienne miniature, générateur, batterie, boîtier, panneau de contrôle, escalier métallique, passerelle industrielle, grille au sol, conduit de ventilation, extracteur, citerne, réservoir, silo, rail suspendu, convoyeur, tapis roulant, signalisation lumineuse.

### 8.12 Outils, artisanat et objets de travail

- marteau, scie, hache décorative, pelle, pioche, râteau, fourche, pince, clé anglaise, tournevis, lime, rabot, ciseau à bois, enclume, soufflet, moule, seau, arrosoir, corde, chaîne, crochet, poulie, treuil, roue dentée, engrenage, presse, établi, panier d'outils, caisse à outils, tonnelet, sac de grain, meule, moulin à main, métier à tisser, bobine, poterie, amphore, balance, lanternes d'atelier, pièces détachées, vis, boulons, ressorts.

### 8.13 Objets domestiques et nourriture

- assiette, bol, tasse, bouteille, gourde, cruche, casserole, poêle, couteau de cuisine décoratif, cuillère, fourchette, louche, planche à découper, pain, fromage, fruits, légumes, poisson séché, viande suspendue, sac de farine, panier de pommes, bocal, pot de confiture, tonneau de vin fictif, épices, herbes séchées, bougies, savon, peigne, serviette, oreiller, couverture, livre, parchemin, lettre, paquet, jouet, poupée, dés, cartes, instrument de musique.

### 8.14 Objets de commerce et marché

- étal, caisse de fruits, cageots, balance marchande, auvent, tissu suspendu, tapis marchand, enseigne, pancarte de prix, sacs d'épices, paniers, jarres, coffres, présentoirs, lanternes, table de négociation, charrette de marché, tonneaux empilés, corde de séparation, bijoux décoratifs, outils exposés, poteries, rouleaux de tissu, cage décorative, objets rares, reliques, marchandises futuristes, conteneurs scellés.

### 8.15 Objets industriels et machines

- moteur, pompe, turbine, compresseur, chaudière, réservoir, piston, volant d'inertie, générateur, ventilateur, grille, boîtier, capot, console, écran, clavier, levier, bouton, jauge, cadran, tuyau flexible, câble épais, bobine de câble, transformateur, radiateur, conduit, filtre, vanne, engrenage, chaîne industrielle, bras mécanique, capsule, module serveur, rack électronique, batterie, cellule d'énergie, imprimante 3D fictive, station de recharge, panneau maintenance, robot cassé.

### 8.16 Science-fiction, technologie avancée, alien

- terminal holographique, capsule cryo, générateur antigravité fictif, balise, drone posé, module sensoriel, tourelle décorative non fonctionnelle, antenne orbitale, panneau lumineux, réacteur miniature fictif, cube de données, cristal énergétique, artefact alien, obélisque lumineux, plante cybernétique, câble organique, incubateur, bio-tube, conteneur stase, panneau de vaisseau, débris spatial, fragments de satellite, module de survie, batterie futuriste, nanite pod, téléporteur décoratif, porte énergétique, signal beacon.

### 8.17 Fantastique, mythique, rituel

- rune stone, cercle rituel, totem, idole, autel, reliquaire, cristal magique, livre ancien, coffre scellé, torche éternelle, brasero, statue sacrée, bannière, cloche, gong, masque, sceptre décoratif, pierre flottante, racine enchantée, arbre sacré, fontaine mystique, portail dormant, fragment d'artefact, amulette géante, ossement de créature mythique, œuf ancien, stèle prophétique, vase maudit, miroir ancien, sanctuaire miniature.

### 8.18 Débris, dommages, usure et narration environnementale

- planche cassée, chaise renversée, table brûlée, caisse ouverte, tonneau percé, verre brisé, éclats de céramique, papier déchiré, livres dispersés, peinture écaillée, métal rouillé, câble arraché, panneau tordu, pierre fissurée, statue décapitée, roues cassées, traces de feu, suie, coulures, impacts, griffures, marques d'outils, traces de sang stylisé si adapté, empreintes, flèches plantées fictives, morceaux de machines, fragments de drones, restes de campement, cendres de foyer, sacs éventrés.

### 8.19 Props interactifs gameplay

- coffre, porte, levier, bouton, pressure plate, interrupteur, ascenseur simple, pont mobile, mécanisme, serrure, terminal, station de craft, atelier, forge, lit de repos, feu de camp, marmite, point de récolte, plante récoltable, minerai récoltable, arbre coupable, caisse destructible, tonneau explosif fictif si gameplay arcade, piège, plaque piégée, téléporteur, autel d'amélioration, livre de compétence, obélisque de sauvegarde, point de quête, objet mythique, instrument, puzzle rotatif, statue déplaçable, miroir orientable.

### 8.20 Micro-props et détails AAA

- rivets, boulons, vis, clous, charnières, poignées, crochets, coutures, boutons, lacets, fibres de tissu, éclats de peinture, rouille localisée, poussière dans les coins, gouttes d'eau, neige accumulée, givre, mousse dans les creux, traces d'écoulement, decals de saleté, scratches, fingerprints, mud splashes, wetness masks, leaf clusters, tiny pebbles, pollen, ash particles, spider webs, web anchors, hair/fur clumps, bark flakes, sap drops, resin, wax drips, candle smoke marks.

---

## 9. Système de variantes : gènes, distributions et corrélations

La variété ne doit pas être une simple randomisation indépendante. Pour obtenir des props crédibles, il faut des **gènes corrélés**.

### 9.1 PropVariantGenome

Chaque variante peut être décrite comme un mini-génome :

```swift
public struct PropVariantGenome: Codable, Hashable {
    public var morphology: MorphologyGenes
    public var material: MaterialGenes
    public var age: AgeGenes
    public var damage: DamageGenes
    public var ecology: EcologyGenes
    public var culture: CultureGenes
    public var gameplay: GameplayGenes
}
```

### 9.2 Exemples de gènes morphologiques

- hauteur.
- largeur.
- épaisseur.
- courbure.
- asymétrie.
- torsion.
- nombre de sous-parties.
- densité de détails.
- silhouette.
- ratio vertical/horizontal.
- rugosité géométrique.
- taille relative des extrémités.
- profondeur des creux.
- quantité de fractures.
- régularité manufacturée.

### 9.3 Exemples de gènes matériaux

- couleur dominante.
- variation de teinte.
- roughness moyenne.
- niveau de metallic.
- intensité normal map.
- porosité.
- humidité.
- poussière.
- mousse.
- rouille.
- peinture.
- vernis.
- transparence.
- subsurface.
- bioluminescence.

### 9.4 Corrélations importantes

Un arbre vieux doit souvent avoir :

- tronc plus large ;
- écorce plus rugueuse ;
- branches mortes ;
- mousse possible ;
- asymétrie plus forte ;
- cavités possibles ;
- racines apparentes ;
- LOD collision plus massif.

Un lampadaire côtier doit souvent avoir :

- métal plus rouillé ;
- peinture écaillée ;
- saleté verticale ;
- base humide ;
- corrosion côté vent marin ;
- légère inclinaison si sol instable.

Un rocher de rivière doit souvent avoir :

- silhouette arrondie ;
- roughness géométrique basse ;
- matériau plus humide ;
- mousse sur zones hautes/proches berge ;
- placement aligné avec flux de rivière.

### 9.5 Distributions recommandées

- uniforme : à éviter sauf pour détails décoratifs.
- normale tronquée : dimensions réalistes.
- beta : proportions bornées avec biais.
- log-normal : taille d'objets naturels, rareté de gros spécimens.
- categorical weighted : choix d'archetype.
- Markov chain : motifs séquentiels, strates, alternance de modules.
- blue noise : placement sans amas artificiels.
- Poisson disk : distance minimale entre props.
- distributions conditionnelles : paramètres dépendants du contexte.

---

## 10. Règles de génération contextuelles

Les props doivent être sélectionnés par règles multicouches.

### 10.1 Règles environnementales

- altitude minimale/maximale.
- pente maximale.
- exposition soleil/ombre.
- humidité du sol.
- distance à l'eau.
- distance à rivière/lac/mer.
- température moyenne.
- saison.
- vent dominant.
- salinité.
- type de sol : sable, argile, roche, terre, boue, neige, glace.
- profondeur de sol.
- densité végétale locale.
- occlusion par canopée.
- risque feu.
- niveau de pollution.
- radioactivité fictive si monde SF.
- magie/énergie locale si monde fantasy.

### 10.2 Règles écologiques

- compétition entre espèces.
- symbiose : mousse sur tronc, champignons sur bois mort.
- succession écologique : herbes -> buissons -> jeunes arbres -> forêt mature.
- espèces pionnières après incendie.
- plantes rares uniquement dans niches.
- arbres morts plus probables en zones sèches/froides/brûlées.
- rochers colonisés par lichens selon humidité/âge.
- terriers près de végétation dense.
- nids dans arbres ou falaises.

### 10.3 Règles culturelles et civilisationnelles

- époque : préhistorique, antique, médiévale, industrielle, moderne, post-apo, futuriste, alien.
- tech level : pierre, bois, métal, vapeur, électrique, électronique, cybernétique, exotique.
- faction : style, matériaux, couleurs, symboles, propreté.
- richesse locale : props plus élaborés ou rudimentaires.
- densité humaine : routes, déchets, mobilier, constructions.
- religion/croyances : autels, totems, runes.
- guerre/conflit : barricades, ruines, impacts, camps.
- abandon : poussière, végétation envahissante, mobilier cassé.

### 10.4 Règles narratives/RPG

- présence ou absence d'ennemis.
- monde pacifique, hostile, mystérieux, technologique, mythique.
- quête dominante : objet mythique, compétence à maîtriser, exploration, survie, commerce, enquête.
- rareté des artefacts.
- indices environnementaux.
- props uniques déterminés par seed.
- objets verrouillés par progression.
- changements visuels selon alignement local du monde.

### 10.5 Règles de composition locale

- un arbre tombé génère souvent branches cassées, feuilles, champignons, insectes.
- un campement génère feu, pierres de foyer, sacs, bancs, restes alimentaires.
- une ruine génère gravats, colonnes cassées, végétation envahissante, poussière.
- un atelier génère établi, outils, pièces, lampes, caisses.
- un lampadaire génère éventuellement câble, base béton, boulons, zone éclairée, saleté au pied.

---

## 11. Architecture de règles : score + contraintes + solveur léger

Il faut éviter un solveur lourd global. Le bon modèle pour IsoWorld :

1. règles locales rapides ;
2. scoring par archetype ;
3. contraintes dures ;
4. tirage déterministe pondéré ;
5. correction simple ;
6. validation.

### 11.1 Contraintes dures

Un prop est interdit si :

- pente trop forte ;
- collision avec élément prioritaire ;
- biome incompatible ;
- sous-biome incompatible ;
- taille trop grande pour le slot ;
- distance minimale non respectée ;
- gameplay bloqué ;
- budget dépassé ;
- prop unique déjà généré dans la région.

### 11.2 Scores souples

Un prop devient plus probable si :

- contexte favorable ;
- voisinage compatible ;
- densité cible non atteinte ;
- variation souhaitée ;
- seed du monde favorise cette famille ;
- région raconte une histoire cohérente.

### 11.3 Exemple de score

```text
score(archetype, context) =
  biomeAffinity *
  subBiomeAffinity *
  slopeAffinity *
  moistureAffinity *
  temperatureAffinity *
  soilAffinity *
  civilizationAffinity *
  rarityWeight *
  narrativeWeight *
  localDiversityCorrection
```

### 11.4 Règles par layers

Séparer les layers :

- `GroundCoverLayer`: herbes, feuilles, cailloux.
- `VegetationLayer`: arbres, buissons, plantes.
- `GeologyLayer`: rochers, cristaux, éboulis.
- `CivilizationLayer`: routes, mobilier, architecture.
- `NarrativeLayer`: objets uniques, indices, artefacts.
- `FXLayer`: particules, lucioles, poussière, fumée.
- `InteractionLayer`: récolte, coffres, portes, ateliers.

Chaque layer a son budget, sa densité et ses priorités.

---

## 12. Génération haute qualité des arbres

Les arbres sont une famille prioritaire car ils montrent immédiatement la qualité du monde.

### 12.1 Recommandation : hybride L-system + space colonization + modules

- L-system ou grammaire pour structure générale.
- Space colonization pour distribution organique des branches vers la lumière.
- Profils paramétriques pour tronc/branches.
- Modules de feuilles instanciées ou cards.
- Masques de bark procéduraux.
- Racines générées par splines/sweeps.
- Cavités et noeuds par détails procéduraux.

### 12.2 Paramètres

- espèce.
- âge.
- hauteur.
- rayon tronc.
- courbure tronc.
- nombre de branches principales.
- angles de branchement.
- phyllotaxie.
- densité feuillage.
- taille des feuilles.
- couleur saisonnière.
- santé.
- humidité.
- exposition au vent.
- neige/mousse.
- dommages : cassures, brûlures, foudre.

### 12.3 LOD des arbres

- LOD0 : tronc/branches détaillés + feuilles instanciées + normal detail + interaction proche.
- LOD1 : branches simplifiées + clusters de feuilles.
- LOD2 : canopy simplifiée + cartes de feuillage.
- LOD3 : imposteur billboard/hemisphere.
- LOD collision : capsule/tronc + quelques branches principales.

### 12.4 Variantes radicales par seed

Le seed global peut modifier les lois de végétation :

- monde aux arbres bas et très larges ;
- monde aux arbres très hauts et fins ;
- monde aux racines aériennes ;
- monde aux arbres bioluminescents ;
- monde aux feuilles géantes ;
- monde aux troncs spiralés ;
- monde post-incendie avec arbres morts dominants ;
- monde glaciaire avec conifères compacts ;
- monde alien où les arbres suivent une symétrie ternaire ou hexagonale.

---

## 13. Génération haute qualité des rochers

Les rochers doivent éviter l'effet « blob random ». Ils doivent raconter une géologie.

### 13.1 Approche recommandée

- base SDF/superquadric/bruit fractal.
- fracture planes.
- strates géologiques.
- erosion masks.
- bevels naturels.
- displacement procedural.
- material masks par orientation : mousse dessus, humidité bas, poussière creux.
- décals/fissures générés.

### 13.2 Paramètres

- type géologique : granite, basalte, calcaire, grès, schiste, volcanique, cristal.
- forme : galet, bloc, dalle, colonne, éclat, strate, menhir.
- taille.
- angularité.
- stratification.
- rugosité.
- fractures.
- humidité.
- couverture mousse/neige/sable.
- insertion dans terrain.

### 13.3 Règles contextuelles

- rivière : rochers arrondis, humides, alignés flux.
- falaise : rochers anguleux, éboulis, fractures.
- désert : vent-polished, sable accumulé côté bas.
- montagne : roches dures, éboulis, neige/givre.
- forêt humide : mousse, lichens, sol enfoui.
- volcan : basalte, scories, obsidienne.

---

## 14. Génération haute qualité des plantes

Les plantes doivent utiliser beaucoup d'instancing. Les formes peuvent être simples individuellement mais riches en population.

### 14.1 Techniques

- phyllotaxie pour feuilles/fleurs.
- L-system court pour tiges.
- spline/sweep pour tiges courbes.
- cards ou meshes bas poly pour feuilles.
- atlases de feuilles + variations de teinte.
- bend procedural au vent.
- cluster generation pour touffes.
- distribution blue-noise.

### 14.2 Paramètres

- taille.
- densité touffe.
- nombre de tiges.
- longueur tiges.
- courbure.
- type feuille.
- taille feuille.
- couleur.
- floraison.
- stade saisonnier.
- santé.
- humidité.
- vent.

### 14.3 Système de plantes rares

Les plantes rares doivent être générées par niches :

- altitude précise ;
- ombre + humidité ;
- sol minéral spécifique ;
- proximité source chaude ;
- région narrative ;
- biome secondaire ;
- saison.

---

## 15. Génération de meubles et objets manufacturés

Les props manufacturés sont différents : ils doivent paraître conçus, fonctionnels, avec symétrie, répétition, dimensions crédibles.

### 15.1 Approche recommandée : shape grammar + sockets

Un meuble peut être généré par une grammaire :

```text
Table
  -> Top + Legs + Supports + Details
Top
  -> RectTop | RoundTop | OvalTop | BrokenTop
Legs
  -> 4xLeg | 3xLeg | Pedestal | AFrame
Details
  -> Nails + Scratches + EdgeWear + OptionalDrawer
```

Chaque élément possède des sockets :

- `top.bottom.corner[i]` pour pieds ;
- `top.side.center` pour tiroir ;
- `leg.bottom` pour patins ;
- `top.surface` pour poussière/objets.

### 15.2 Paramètres

- style : rustique, noble, industriel, moderne, futuriste, alien.
- matériau : bois, métal, pierre, plastique, composite, os, cristal.
- qualité : pauvre, standard, riche, artisanal, militaire, sacré.
- âge.
- usure.
- niveau de fabrication.
- symétrie.
- décorations.
- fonctionnalité.

### 15.3 Règles de crédibilité

- les pieds doivent toucher le sol ;
- le centre de masse doit être plausible ;
- l'assise doit être à hauteur crédible ;
- les tiroirs doivent avoir poignées et façade ;
- les lampes doivent avoir source d'énergie ou logique visuelle ;
- les matériaux doivent être cohérents avec époque/biome/faction.

---

## 16. Génération de lampadaires et props urbains

Un lampadaire est un excellent test de système car il combine : géométrie, matériau, lumière, interaction, époque, usure, câbles, collisions.

### 16.1 Variantes

- torche primitive.
- lanterne suspendue.
- réverbère ancien.
- lampadaire industriel.
- poteau électrique.
- néon moderne.
- panneau lumineux futuriste.
- crystal lamp fantasy.
- champignon lumineux naturel.
- biolampe alien.

### 16.2 Paramètres

- hauteur.
- nombre de bras.
- forme du mât.
- base.
- luminaire.
- type d'émission.
- couleur lumière.
- intensité.
- flicker.
- état : allumé, éteint, cassé, intermittent.
- câble visible.
- rouille.
- inclinaison.
- panneau/affiche attaché.

### 16.3 Runtime

- lumière active seulement proche ou importante.
- proxy emissive à distance.
- shadow casting limité par budget.
- culling des petites sources.
- flicker déterministe par stableId.

---

## 17. Génération d'animaux et créatures procédurales

Même si l'animation procédurale est un autre sujet, le système de props doit pouvoir générer des formes animales décoratives ou interactives simples.

### 17.1 Architecture morphology-first

Un animal procédural peut être décrit par :

- squelette.
- segments.
- proportions.
- nombre de membres.
- type de locomotion.
- peau/fourrure/plumes/écailles.
- taille.
- silhouette.
- colliders.
- comportements simples.

### 17.2 Familles simples à prioriser

- insectes.
- petits quadrupèdes.
- poissons.
- oiseaux posés/en vol simple.
- serpents.
- amphibiens.
- créatures alien passives.

### 17.3 Génération déterministe

Le seed peut définir des lois biologiques du monde :

- symétrie bilatérale classique ;
- créatures à 6 membres ;
- créatures sans yeux ;
- faune bioluminescente ;
- carapaces minérales ;
- plumes métalliques fictives ;
- animaux minuscules mais très nombreux ;
- monde sans animaux ;
- monde dominé par insectoïdes.

### 17.4 Prudence runtime

Les animaux ne doivent pas devenir coûteux partout. Utiliser :

- props statiques/décoratifs à distance ;
- imposteurs animés ;
- skeletal simple proche ;
- comportement activé seulement autour du joueur ;
- état sauvegardé minimal.

---

## 18. Matériaux procéduraux haute qualité

Le système de props doit générer des matériaux au même niveau que la géométrie.

### 18.1 Matérialisation par couches

Chaque matériau doit être une composition :

```text
BaseMaterial
  + ColorVariation
  + MicroNormal
  + MacroWear
  + DirtLayer
  + WetnessLayer
  + BiomeOverlay
  + AgeOverlay
  + DamageOverlay
  + OptionalEmission/Subsurface/Clearcoat/Fuzz
```

### 18.2 Masques procéduraux universels

- orientation mask : neige/mousse dessus.
- cavity mask : poussière/saleté dans creux.
- curvature mask : usure sur arêtes.
- height mask : humidité bas, décoloration haut.
- windward mask : sable/neige côté vent.
- contact mask : saleté au contact sol.
- leakage mask : coulures verticales.
- crack mask : fissures.
- burn mask : zones brûlées.
- rust mask : métal exposé + humidité.

### 18.3 Matériaux par familles

- bois : veines, cernes, écorce, noeuds, coupe, bois sec/humide, peinture.
- pierre : grains, strates, veines, cristaux, mousse, poussière.
- métal : base, roughness, rouille, usure arêtes, peinture, graisse.
- tissu : weave normal, plis, saleté, déchirures, coutures.
- verre : roughness, épaisseur, saleté, fissures.
- céramique : glaze, craquelures, éclats.
- peau/organique : subsurface, pores, écailles, poils.
- feuillage : translucency, variation teinte, saison, trous.
- neige/glace : subsurface léger, roughness, saleté, fonte.
- alien : émission, iridescence, motifs périodiques.

### 18.4 Recommandation PBR

Même si IsoWorld n'implémente pas tout OpenPBR tout de suite, son modèle interne devrait prévoir :

- base color.
- roughness.
- metallic.
- normal.
- height/parallax éventuel.
- AO.
- emissive.
- opacity/alpha clip.
- transmission/translucency simplifiée.
- subsurface foliage/skin simplifié.
- clearcoat.
- sheen/fuzz pour tissu/feuillage.

---

## 19. LOD, imposteurs et rendu de masse

Le système de props sera inutile s'il ne peut pas afficher beaucoup d'éléments.

### 19.1 Catégories de rendu

1. **Hero props**
   - haute résolution.
   - matériaux riches.
   - interaction.
   - collision précise.
   - LOD complet.

2. **Medium props**
   - géométrie simplifiée.
   - matériaux partagés.
   - collision simple.
   - instancing possible.

3. **Background props**
   - mesh très simplifié.
   - imposteur ou cluster.
   - pas de collision ou collision grossière.

4. **Micro props**
   - decals, cards, instanced meshes.
   - souvent non interactifs.
   - générés/affichés par densité.

### 19.2 LOD génération

Pour chaque prop :

- LOD0 : qualité proche.
- LOD1 : réduction géométrie.
- LOD2 : simplification silhouette.
- LOD3 : billboard/imposteur ou cluster proxy.
- Collision LOD : toujours séparé.
- Shadow LOD : silhouette simplifiée pour ombres.

### 19.3 Instancing

Les props doivent être groupés par :

- mesh archetype.
- material family.
- texture atlas.
- LOD level.
- biome overlay.

Même si chaque prop a des variations, beaucoup de variations peuvent passer par :

- instance transform ;
- per-instance color ;
- per-instance material parameters ;
- per-instance seed ;
- atlas index ;
- wind phase ;
- damage amount ;
- wetness amount.

### 19.4 Meshlets et clusters

À moyen terme, pour les props complexes :

- découper les meshes en clusters/meshlets ;
- culling par cluster ;
- LOD par cluster ;
- occlusion culling GPU ;
- génération d'Indirect Command Buffers Metal.

Ce point rejoint le futur système de LOD inspiré de Nanite, mais les props doivent déjà stocker des bounds, clusters et niveaux de simplification.

---

## 20. Collision, physique et gameplay

Ne pas générer de collisions trop détaillées.

### 20.1 Colliders par famille

- arbre : capsule tronc + capsules branches principales + disque racines.
- rocher : convex hull simplifié ou plusieurs capsules/boxes.
- plante : pas de collision ou trigger léger.
- meuble : boxes composées.
- lampadaire : capsule mât + box base.
- machine : convex decomposition simplifiée.
- animal petit : capsule ou sphere.
- débris : collision uniquement proche ou si gameplay.

### 20.2 Props destructibles

Un prop destructible doit avoir :

- état intact.
- état endommagé.
- état détruit.
- sous-débris générés.
- recette de fracture.
- loot éventuel.
- coût mémoire contrôlé.

### 20.3 Interaction déterministe

Pour un monde déterministe, il faut distinguer :

- état régénérable : forme de base.
- état mutable : cassé, récolté, ouvert, déplacé.

L'état mutable doit être sauvegardé comme delta minimal :

```text
PropStateDelta {
  stableId,
  flags: opened/destroyed/harvested/moved,
  transformOverride?,
  inventoryDelta?,
  health?
}
```

---

## 21. Génération procédurale et authoring artistique

Un système full-code devient vite incontrôlable. Il faut prévoir des assets de définition lisibles.

### 21.1 PropDefinition en YAML/JSON

Exemple :

```yaml
id: tree.oak.twisted
family: vegetation.tree
version: 1
priority: medium
biomeAffinity:
  temperate_forest: 1.0
  wetland: 0.6
  alpine: 0.2
constraints:
  slopeMax: 32
  moisture: [0.35, 0.9]
  temperature: [0.2, 0.8]
generator:
  id: tree.branching.v1
  parameters:
    height: { distribution: logNormal, min: 4.0, max: 28.0, mean: 12.0 }
    trunkBend: { distribution: beta, alpha: 2.0, beta: 5.0 }
    branchDensity: { distribution: normal, mean: 0.55, std: 0.18 }
materials:
  bark: material.wood.bark.oak
  leaves: material.leaf.oak
lodPolicy: vegetation.large
physicsPolicy: staticTrunkCapsule
semanticTags: [organic, flammable, harvestable_wood, climb_blocker]
```

### 21.2 Validation automatique

Chaque définition doit passer des tests :

- pas de NaN.
- dimensions dans limites.
- bounds corrects.
- pas d'intersections majeures.
- LOD disponibles.
- collision proxy présent si nécessaire.
- matériaux valides.
- budget triangle/texture conforme.
- stabilité seed.
- pas de variation grotesque hors style sauf désirée.

### 21.3 Outils à construire

- Seed Explorer : explorer variantes par seed.
- Prop Gallery : grille de 100 variantes d'un archetype.
- Context Preview : voir le prop selon biome/saison/âge.
- Rule Debugger : expliquer pourquoi un prop spawn ou non.
- Budget Viewer : triangles, draw calls, materials, textures, collisions.
- Snapshot Diff : comparer générateur version N et N+1.
- Golden Seeds : seeds de test à ne jamais casser.

---

## 22. Pipeline runtime recommandé pour IsoWorld

### 22.1 Étape 1 — chunk prop slots

Lorsqu'un chunk devient actif :

1. dériver `chunkSeed` ;
2. évaluer les layers de placement ;
3. générer slots candidats ;
4. filtrer par contraintes ;
5. attribuer archetypes ;
6. créer `PropRecipeRef` sans forcément générer mesh complet.

### 22.2 Étape 2 — matérialisation progressive

Selon distance/priorité :

- loin : proxy/imposteur/cluster.
- moyen : mesh LOD2/LOD1.
- proche : LOD0 + collision + interaction.
- très proche : détails, decals, animation secondaire.

### 22.3 Étape 3 — cache

Caches recommandés :

- `RecipeCache`: stableId -> recipe.
- `BuildPlanCache`: recipeHash -> buildPlan.
- `MeshCache`: geometryHash + quality -> mesh buffer.
- `MaterialInstanceCache`: materialHash -> GPU material params.
- `CollisionCache`: collisionHash -> collider.
- `ImpostorCache`: archetype/variant class -> billboard/atlas.

### 22.4 Étape 4 — rendu Metal

Pipeline possible :

1. CPU génère/stream les recettes.
2. CPU prépare instances compactes.
3. GPU cull par bounds.
4. GPU choisit LOD.
5. Indirect draws/argument buffers pour batches.
6. Shaders lisent per-instance params.
7. Matériaux appliquent variation procédurale.

---

## 23. Stratégie de performance

### 23.1 Ne pas tout générer en mesh unique

Pour beaucoup de props, utiliser :

- base mesh partagée ;
- variation shader ;
- transform de sous-parties ;
- instancing ;
- decals ;
- displacement/normal maps ;
- atlas.

### 23.2 Coûts par distance

| Distance | Représentation | Collision | Matériaux | Animation |
|---|---|---|---|---|
| très loin | imposteur/cluster | non | baked | non |
| loin | LOD3 | non | simple | shader léger |
| moyen | LOD2/LOD1 | grossière si bloquant | PBR réduit | wind/simple |
| proche | LOD0 | oui | complet | complet |
| interaction | LOD0 + state | précis utile | complet | gameplay |

### 23.3 Budget par chunk

Chaque chunk devrait avoir des budgets par layer :

- triangles visibles max.
- props interactifs max.
- lumières dynamiques max.
- draw batches max.
- material families max.
- collision bodies max.
- génération CPU par frame max.
- mémoire mesh/texture max.

---

## 24. Approche « qualité AAA » sans équipe AAA

Le rendu haute qualité vient surtout de la cohérence et du détail contextuel.

### 24.1 Les leviers les plus rentables

1. silhouettes variées ;
2. matériaux PBR propres ;
3. usure et saleté contextuelles ;
4. decals/procedural masks ;
5. placement naturel ;
6. cohérence biome/époque ;
7. LOD invisibles ;
8. lumière et contact shadows ;
9. micro-détails proches ;
10. animation secondaire subtile.

### 24.2 Éviter les pièges

- randomisation indépendante incohérente ;
- props flottants ;
- répétition visible ;
- collision trop lourde ;
- trop de matériaux uniques ;
- génération runtime trop ambitieuse ;
- pas de validation ;
- absence de règles d'écologie/culture ;
- LOD qui pop ;
- proportions irréalistes.

### 24.3 Détail contextuel

Un même prop doit changer selon contexte :

- table dans maison riche : vernis, ornements, propre.
- table dans cabane humide : bois gonflé, mousse, pieds irréguliers.
- table post-apo : métal recyclé, peinture écaillée, rouille.
- table futuriste : composite, lumière intégrée, bords arrondis.
- table fantasy : gravures, runes, bois ancien.

---

## 25. Exemple complet : génération d'un arbre

```text
Input:
  worldSeed = 381929
  chunk = (12, -4)
  biome = temperate_forest
  slope = 8°
  moisture = 0.72
  ageField = mature

Placement:
  layer vegetation.large selects tree.oak.twisted

Recipe:
  height = 17.4m
  trunkRadius = 0.63m
  trunkBend = 0.31
  branchCount = 14
  health = 0.78
  moss = 0.42
  deadBranches = 3
  leafHueShift = -0.04

BuildPlan:
  sweep trunk spline
  branch graph with taper
  scatter leaf clusters
  generate bark masks
  add moss orientation/cavity mask
  collision capsule trunk
  LOD0/1/2/impostor

Runtime:
  near: LOD0, wind leaves, capsule collision
  medium: LOD1, simplified leaves
  far: impostor
```

---

## 26. Exemple complet : génération d'un lampadaire

```text
Input:
  biome = coastal_town
  techLevel = industrial
  factionStyle = rusted_blue
  distanceToSea = 42m
  windExposure = 0.8

Placement:
  civilization.street layer, near road spline

Recipe:
  archetype = lamp.post.industrial.curved
  height = 4.7m
  baseRadius = 0.32m
  armCount = 1
  tilt = 3.2°
  rust = 0.67
  paintChips = 0.51
  lightColor = warm
  flicker = 0.12
  cable = visible overhead

BuildPlan:
  lathe base
  sweep pole
  socket attach lamp head
  add bolts
  add rust masks by curvature + sea wind direction
  emissive material
  capsule collision
  point/spot light proxy

Runtime:
  light active within lighting budget
  emissive only when far
  flicker phase from stableId
```

---

## 27. Exemple complet : génération d'une table

```text
Input:
  location = abandoned_cabin
  era = low_tech
  humidity = 0.81
  wealth = low

Recipe:
  archetype = furniture.table.rustic
  topShape = rectangular
  topSize = 1.4 x 0.8m
  legStyle = uneven_wood
  drawer = false
  damage = 0.36
  dirt = 0.72
  moss = 0.18

BuildPlan:
  bevelled planks for tabletop
  four legs socketed under top
  cross supports
  nail heads instanced
  warped board deformation
  edge wear masks
  box colliders

Runtime:
  static prop
  can support small items
  collision box simplified
```

---

## 28. Données et formats internes

### 28.1 PropCatalog

```swift
public struct PropCatalog {
    public var families: [PropFamily]
    public var archetypes: [String: PropArchetype]
    public var generators: [String: PropGeneratorDescriptor]
    public var materials: [String: MaterialDescriptor]
    public var ruleSets: [String: PropRuleSet]
}
```

### 28.2 PropArchetype

```swift
public struct PropArchetype: Codable {
    public let id: String
    public let family: PropFamily
    public let generatorId: String
    public let biomeAffinities: [BiomeId: Float]
    public let constraints: PropConstraints
    public let parameterSchema: PropParameterSchema
    public let materialSlots: [MaterialSlotDescriptor]
    public let lodPolicyId: String
    public let physicsPolicyId: String
    public let semanticTags: [String]
}
```

### 28.3 PropContext

```swift
public struct PropContext {
    public let worldSeed: UInt64
    public let dimensionId: UInt32
    public let regionCoord: SIMD2<Int32>
    public let chunkCoord: SIMD2<Int32>
    public let localPosition: SIMD3<Float>
    public let biome: BiomeId
    public let subBiome: SubBiomeId
    public let altitude: Float
    public let slope: Float
    public let moisture: Float
    public let temperature: Float
    public let soil: SoilType
    public let wind: SIMD2<Float>
    public let civilization: CivilizationContext?
    public let narrative: NarrativeContext
}
```

---

## 29. Plan d'implémentation réaliste pour IsoWorld

### Phase 0 — Fondations déterministes

- `DeterministicRNG` stable.
- hash utilities.
- `StableId` pour props.
- `PropContext` minimal.
- `PropCatalog` minimal.
- tests golden seeds.

### Phase 1 — Props naturels simples

- rochers SDF/primitive noise.
- cailloux instanciés.
- herbes/cards.
- arbres simples générés par branching.
- matériaux PBR simples.
- placement par biome/slope/moisture.

### Phase 2 — Registry + règles

- YAML/JSON definitions.
- scoring system.
- constraints.
- layer budgets.
- debug view.
- seed gallery.

### Phase 3 — Variantes avancées

- `PropVariantGenome`.
- corrélations âge/usure/matériau.
- weathering masks.
- biome overlays : neige, sable, mousse, humidité.
- LOD policies.

### Phase 4 — Props manufacturés

- bevelled boxes.
- sweep/lathe.
- sockets.
- shape grammar simple.
- tables/chaises/caisses/lampadaires.
- collisions composées.

### Phase 5 — Pipeline rendu massif

- instancing par famille.
- per-instance params.
- culling par bounds.
- LOD distance.
- imposteurs simples.
- material atlases.

### Phase 6 — Props interactifs

- state deltas.
- récoltable/destructible/openable.
- lumière dynamique budgetée.
- triggers.
- gameplay affordances.

### Phase 7 — Outils et qualité

- Prop Gallery.
- Rule Debugger.
- Budget Viewer.
- Snapshot Diff.
- validation automatique.
- export/import offline.

### Phase 8 — Génération avancée

- WFC local pour objets composés.
- SDF/CSG plus riche.
- meshlet/cluster LOD.
- creature morphology simple.
- articulated props.

---

## 30. Priorités recommandées

Pour obtenir vite un résultat visible et scalable :

1. rochers/cailloux/éboulements ;
2. herbes/plantes basses ;
3. arbres simples mais nombreux ;
4. bois mort/souches/branches ;
5. caisses/tonneaux/tables ;
6. lampadaires/torches avec lumière ;
7. ruines modulaires ;
8. props de campement ;
9. micro-details et decals ;
10. interactive props simples.

Ces familles couvrent nature + civilisation + gameplay + qualité visuelle.

---

## 31. Système de style global par seed

Pour que le monde se transforme radicalement au changement de seed, introduire un `WorldStyleGenome`.

```swift
public struct WorldStyleGenome {
    public let morphologyBias: MorphologyBias
    public let vegetationLaw: VegetationLaw
    public let geologyLaw: GeologyLaw
    public let civilizationLaw: CivilizationLaw
    public let materialPalette: MaterialPaletteLaw
    public let rarityLaw: RarityLaw
    public let weirdness: Float
    public let symmetryBias: SymmetryBias
    public let decayBias: DecayBias
}
```

### 31.1 Exemples de lois de monde

- arbres très hauts, meubles fins, architecture verticale.
- monde bas, massif, rocheux, objets trapus.
- monde humide : mousse partout, bois sombre, métal rouillé.
- monde sec : poussière, fissures, plantes grasses, bois clair.
- monde cristallin : cristaux dans roches, props anguleux, matériaux iridescents.
- monde organique : formes courbes, machines bio-mécaniques.
- monde industriel : tuyaux, rouille, lampes, câbles, mobilier métal.
- monde ancien : pierre, bois, gravures, autels.
- monde futuriste : matériaux lisses, lumières, panneaux, modules.
- monde post-apo : récupération, cassures, patchwork, saleté.
- monde sans civilisation : props naturels uniquement.
- monde sur-civilisé : traces humaines partout.

---

## 32. Qualité par cohérence narrative

Chaque prop doit répondre à trois questions :

1. **Pourquoi est-il là ?**
2. **Comment le contexte l'a modifié ?**
3. **Que peut comprendre le joueur ?**

Exemples :

- Des caisses près d'un pont indiquent une route commerciale.
- Des champignons sur une souche indiquent humidité et ancienneté.
- Un lampadaire rouillé et penché indique vent marin/abandon.
- Des pierres alignées indiquent ancien rituel ou chemin.
- Des outils dispersés indiquent fuite, accident ou chantier.

C'est ce type de cohérence qui donne un sentiment AAA même avec une génération économique.

---

## 33. Recommandation finale d'architecture

Le système idéal pour IsoWorld est :

```text
PropSystem
  ├── PropCatalog
  │   ├── PropFamilies
  │   ├── PropArchetypes
  │   ├── PropGeneratorDescriptors
  │   ├── MaterialDescriptors
  │   └── RuleSets
  ├── PropPlacementSystem
  │   ├── Layers
  │   ├── Context samplers
  │   ├── Scoring
  │   ├── Constraints
  │   └── Slot generation
  ├── PropRecipeSystem
  │   ├── Deterministic variant genome
  │   ├── Correlated parameters
  │   └── Versioned recipes
  ├── PropBuildSystem
  │   ├── Geometry ops
  │   ├── Material ops
  │   ├── LOD ops
  │   ├── Collision ops
  │   └── Validation
  ├── PropRuntimeSystem
  │   ├── Streaming
  │   ├── Cache
  │   ├── State deltas
  │   └── Interactions
  └── PropRenderingSystem
      ├── Instancing
      ├── Culling
      ├── LOD/impostors
      ├── Per-instance params
      └── GPU-friendly batches
```

---

## 34. Ce qu'il ne faut pas faire

- Générer un mesh unique pour chaque petite variation.
- Mettre toute la logique dans le renderer.
- Mélanger placement, recette, géométrie et gameplay dans une seule classe.
- Utiliser un RNG global consommé selon l'ordre de streaming.
- Faire des règles uniquement par biome sans contexte local.
- Oublier les métadonnées sémantiques.
- Négliger l'usure, la saleté, l'âge et le contexte.
- Faire des collisions détaillées pour tous les props.
- Ajouter trop de matériaux uniques.
- Ne pas prévoir d'outils de debug.
- Ne pas versionner les générateurs.

---

## 35. Résumé actionnable

Pour IsoWorld, le point 4 doit devenir un sous-système majeur nommé par exemple **ParametricPropSystem**.

Sa promesse :

- générer un nombre massif de props crédibles ;
- rendre chaque monde visuellement différent selon le seed ;
- rester déterministe ;
- rester performant ;
- permettre des props naturels, manufacturés, interactifs, articulés et narratifs ;
- produire des variantes haute qualité par corrélations de paramètres ;
- supporter un pipeline moderne Metal/Swift avec instancing, LOD, cache et rendu GPU-friendly.

La première version ne doit pas tout faire. Mais elle doit poser les abstractions correctes :

1. `PropContext`
2. `PropCatalog`
3. `PropArchetype`
4. `PropGenerator`
5. `PropRecipe`
6. `PropBuildPlan`
7. `PropRuntimeProxy`
8. `PropRuleSet`
9. `PropVariantGenome`
10. `PropStateDelta`

Avec ces briques, IsoWorld peut commencer simple, puis évoluer vers un système extrêmement versatile.

---

## 36. Sources et ressources consultées

- SideFX Houdini — Procedural Modeling : https://www.sidefx.com/products/houdini/modeling/procedural-modeling/
- SideFX Houdini Digital Assets : https://www.sidefx.com/docs/houdini/assets/index.html
- SideFX PDG / Houdini Engine : https://www.sidefx.com/docs/hengine/_h_a_p_i__p_d_g.html
- Houdini Engine for Unreal : https://www.sidefx.com/docs/houdini/unreal/intro.html
- Unreal Engine — Procedural Content Generation Overview : https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-overview
- Unreal Engine — PCG Biome Core Overview : https://dev.epicgames.com/documentation/unreal-engine/procedural-content-generation-pcg-biome-core-and-sample-plugins-overview-guide-in-unreal-engine
- Unity SpeedTree : https://unity.com/products/speedtree
- SpeedTree Modeler LOD documentation : https://docs.unity3d.com/speedtree-modeler/manual/level-of-detail.html
- Infinigen : https://infinigen.org/
- Infinigen Indoors paper : https://arxiv.org/abs/2406.11824
- Infinigen-Sim / Articulated assets : https://arxiv.org/abs/2505.10755
- Blender Geometry Nodes Manual : https://docs.blender.org/manual/en/latest/modeling/geometry_nodes/index.html
- Adobe Substance 3D Designer node library : https://experienceleague.adobe.com/en/docs/substance-3d-designer/using/substance-graphs/nodes-reference-for-substance-graphs/node-library/node-library
- Adobe Substance 3D Sampler filters : https://experienceleague.adobe.com/en/docs/substance-3d-sampler/using/filters/filters
- Adobe Substance Image to Material : https://experienceleague.adobe.com/en/docs/substance-3d-sampler/using/filters/tools/image-to-material
- OpenUSD glossary / composition : https://openusd.org/release/glossary.html
- USD asset structure guidelines : https://lf-aswf.atlassian.net/wiki/spaces/WGUSD/pages/11273723/Guidelines+for+Structuring+USD+Assets
- glTF 2.0 specification : https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
- glTF EXT_mesh_gpu_instancing : https://github.com/KhronosGroup/glTF/blob/main/extensions/2.0/Vendor/EXT_mesh_gpu_instancing/README.md
- OpenPBR specification : https://academysoftwarefoundation.github.io/OpenPBR/
- Apple Metal sample code — Modern Rendering with Metal : https://developer.apple.com/metal/sample-code/
- Apple WWDC — Metal mesh shaders : https://developer.apple.com/videos/play/wwdc2022/10162/
- Apple Metal Feature Set Tables : https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf
- The Algorithmic Beauty of Plants : https://algorithmicbotany.org/papers/abop/abop.pdf
- Procedural Modeling of Buildings, Müller et al. : https://peterwonka.net/Publications/pdfs/2006.SG.Mueller.ProceduralModelingOfBuildings.final.pdf
- Procedural Content Generation in Games survey : https://arxiv.org/html/2410.15644v1
- meshoptimizer : https://github.com/zeux/meshoptimizer
- GPU-driven rendering overview : https://www.vkguide.dev/docs/gpudriven/gpu_driven_engines/
