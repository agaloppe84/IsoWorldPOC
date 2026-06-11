# IsoWorld — Système de personnages procéduraux / paramétriques haute qualité

> **Nouveau step — Character System**  
> Sujet unique : conception d’un système moderne, procédural, paramétrique et déterministe pour générer le joueur et les PNJ, leurs corps, visages, textures, vêtements, accessoires, armes, états physiques, thèmes visuels, variantes et intégrations avec les systèmes IsoWorld.  
> Contexte cible : moteur custom Swift / Metal sur Apple Silicon, monde déterministe par seed, chunks dynamiques, rendu PBR, animation procédurale/physique, audio procédural, props/buildings/biomes/terrain générés par règles.

---

## 0. Résumé exécutif

Le système de personnages d’IsoWorld ne doit pas être pensé comme un simple “character creator” avec quelques sliders. Il doit être un **système de génération d’identités physiques et visuelles**, connecté à tous les autres systèmes du monde : biomes, époque, culture, RPG, météo, animations, audio, matériaux, équipements, factions, métiers, blessures, vieillissement, climat, technologie, ressources et règles de seed.

Le joueur reste **toujours humanoïde**, mais peut avoir une infinité de variantes crédibles : taille, proportions, masse, âge, posture, morphologie, peau, cheveux, pilosité, visage, voix, vêtements, accessoires, armes, blessures, vieillissement, cicatrices, prothèses, salissures, modifications corporelles, style culturel et état physique. Les PNJ utilisent le même système, mais avec des budgets LOD plus agressifs et des règles de génération liées aux factions, régions, métiers et mondes RPG.

La recommandation centrale est de construire un système hybride :

1. **Base anatomique stable et rig compatible** : un squelette humanoïde canonique, des variations morphologiques contrôlées, des morph targets/blend shapes, des correctifs de pose, et une séparation claire entre corps, tête, cheveux, vêtements, accessoires et équipements.
2. **Génération procédurale déterministe** : chaque personnage est défini par un `CharacterDNA` compact, généré depuis `worldSeed`, `regionSeed`, `factionSeed`, `familySeed`, `characterSeed`, `lifeHistorySeed` et `equipmentSeed`.
3. **Qualité AAA par précomputation intelligente** : les détails lourds — grooms haute densité, vêtements complexes, correctifs morphologiques, textures 4K/8K, variantes de meshes — doivent être générés ou cuits offline/à l’installation/au cache, puis utilisés au runtime sous forme compacte.
4. **Runtime data-driven et Metal-friendly** : rendu via GPU skinning, morph targets limitées par budget, palettes de joints compactes, caches de matériaux, atlas/virtual textures, LOD de corps/vêtements/cheveux, crowd LOD et impostors.
5. **Customisation joueur non destructive** : le joueur peut changer apparence, vêtements, coiffure, accessoires et états cosmétiques sans casser son identité persistante, ses animations, sa collision, ses vêtements ou ses sauvegardes.
6. **États persistants du corps** : vieillissement, prise/perte de poids, blessures, cicatrices, fatigue, maladie, saleté, brûlures, perte de membre, prothèse, implants, mutations, tatouages, marques, posture, démarche et voix peuvent évoluer dans le temps.

Le nom proposé pour le système est : **ICCS — IsoWorld Character & Customization System**.

---

## 1. Recherche industrie : ce qu’il faut retenir des meilleures technologies modernes

### 1.1 MetaHuman : référence pour la qualité, pas pour l’architecture runtime custom

MetaHuman est une référence forte pour la génération de personnages réalistes : corps, visage, rig, cheveux, vêtements et animation sont pensés ensemble. La documentation récente met en avant des **Parametric Bodies**, qui permettent de définir des proportions corporelles personnalisées tout en conservant des personnages texturés, riggés et prêts à animer. MetaHuman fournit aussi un système de garde-robe, grooms et outfits compatibles avec le personnage.[^metahuman-body][^metahuman-hair-clothing]

À retenir pour IsoWorld :

- Le personnage doit être généré comme une **composition cohérente**, pas comme un mesh unique.
- Le corps paramétrique doit rester rig-compatible.
- Les vêtements doivent pouvoir s’adapter aux proportions corporelles.
- Le système doit séparer **identité**, **apparence**, **garde-robe**, **groom**, **animation**, **textures** et **états physiques**.
- Les grooms/cheveux doivent être traités comme des assets avec leurs propres LOD, pas comme une texture de tête.

Limite : MetaHuman est un écosystème fermé et lourd. IsoWorld doit s’en inspirer conceptuellement, mais garder un pipeline contrôlé, déterministe et compatible Swift/Metal.

### 1.2 Unreal Mutable : référence pour la customisation de personnages

Mutable dans Unreal est conçu pour créer du contenu dynamique et surtout des systèmes de customisation de personnages. La documentation décrit des `CustomizableObject`, `CustomizableObjectInstance` et acteurs qui combinent meshes, textures et matériaux pour produire les assets finaux.[^mutable-overview]

À retenir :

- La customisation doit être **compilée** en une représentation runtime optimisée.
- Il faut éviter de garder trop de pièces séparées si elles peuvent être fusionnées ou packées.
- Les variantes doivent être pilotées par un graphe de dépendances : si on change la taille du torse, certains vêtements, armures, sangles, sacs et holsters doivent s’adapter.
- Le système doit supporter les toggles, les variantes, les matériaux, les textures générées, les masques de visibilité, les sockets et les contraintes.

IsoWorld devrait avoir son propre équivalent : **CharacterRecipeGraph** + **CharacterBuildCache**.

### 1.3 SMPL / modèles humains paramétriques : référence pour le contrôle du corps

SMPL est un modèle 3D réaliste du corps humain basé sur le skinning et les blend shapes, appris à partir de scans 3D.[^smpl] Il montre une direction intéressante : représenter un corps humain via un nombre limité de paramètres de forme et de pose, au lieu de sculpter chaque personnage manuellement.

À retenir :

- Un corps humain plausible peut être contrôlé par un espace latent / paramétrique compact.
- Les variations morphologiques doivent être contraintes pour rester anatomiquement crédibles.
- Les correctifs de pose sont essentiels : un corps plus musclé, plus âgé ou plus lourd ne se déforme pas exactement comme un corps standard.
- Le système doit pouvoir exprimer le corps sous forme de **paramètres de haut niveau** : taille, proportions, âge, masse, musculature, posture, asymétrie, sexe morphologique optionnel, largeur d’épaules, bassin, longueur des membres, etc.

IsoWorld ne doit pas forcément intégrer SMPL tel quel, mais doit adopter la logique : **un modèle canonique + paramètres + correctifs + contraintes**.

### 1.4 Machine Learning Deformer / Neural Morph : qualité de déformation à coût runtime réduit

Unreal ML Deformer permet d’entraîner des modèles pour approximer des déformations complexes de personnages en sélectionnant des morph targets à runtime, à partir de données de simulation externes.[^ml-deformer] L’objectif est de rapprocher des déformations coûteuses — muscles, tissus, plis, corrections — d’une solution utilisable en temps réel.

À retenir :

- Les déformations haute qualité ne doivent pas toutes être simulées en temps réel.
- On peut pré-calculer des données et les approximer avec des morphs/correctifs runtime.
- Les personnages proches peuvent recevoir plus de correctifs ; les PNJ lointains beaucoup moins.
- Pour IsoWorld, un système plus simple que ML Deformer peut suffire au début : pose-space deformation, correctifs par joint, morphs compressés, puis plus tard micro-modèle neural optionnel.

### 1.5 USD Skel / glTF : standards d’échange à considérer

USD Skel définit des schémas pour échanger des meshes skinnés et animations de joints entre outils DCC.[^usdskel] glTF 2.0 supporte les animations de transforms de nodes et les poids de morph targets.[^gltf]

À retenir :

- Le pipeline IsoWorld doit pouvoir importer/exporter des rigs, skins, animations et morph targets depuis des formats standards.
- Le format runtime interne peut être custom, mais le pipeline auteur doit rester compatible avec Blender, Houdini, Maya, Substance, USD/glTF.
- Pour les personnages, USD est intéressant côté production/authoring ; glTF est intéressant comme format compact d’échange/test.

### 1.6 Hair / Groom : strands proches, cards loin, LOD obligatoire

Unreal Groom utilise un workflow strand-based pour rendre chaque mèche avec mouvement physiquement plausible, tout en gérant aussi des représentations par cards/meshes selon les LOD.[^ue-groom] Le Groom Asset Editor permet de configurer LOD, strands, cards, meshes et interpolation.[^ue-groom-editor] AMD TressFX est aussi une référence GPU pour simuler et rendre cheveux/fourrure de haute qualité.[^tressfx]

À retenir :

- Cheveux/pilosité/fourrure doivent avoir une architecture de LOD dédiée.
- Proche caméra : strands ou guides + interpolation.
- Distance moyenne : hair cards.
- Distance lointaine : shell/mesh simplifié, texture ou impostor.
- La simulation cheveux doit être optionnelle et budgétée.
- Les coiffures doivent être générées paramétriquement : silhouette, volume, longueur, densité, frizz, tresses, rasage, mèches, humidité, saleté, vent.

### 1.7 Cloth / Outfit : simulation proche, skinning/refit loin

Unreal utilise Chaos Cloth comme solveur de vêtements basé sur des particules.[^chaos-cloth] Les workflows modernes montrent que les vêtements temps réel doivent être pensés en plusieurs niveaux : vêtement skinné simple, vêtements avec bones secondaires, cloth simulé sur zones spécifiques, et simulation offline/ML/correctifs pour les plis.

À retenir :

- Tous les vêtements ne doivent pas être simulés.
- Il faut classifier les vêtements : rigide, semi-rigide, skinné, cloth léger, cloth complexe.
- Les vêtements doivent avoir des **zones** : attachée, libre, tendue, épaisse, rigide, flottante, collisionnable.
- L’adaptation au corps doit être faite par refit paramétrique + masques de clipping + correctifs.
- La simulation complète ne doit concerner que les capes, jupes, manteaux, tissus flottants, cordes, sangles longues, cheveux longs, etc.

### 1.8 OpenPBR / MaterialX : matériaux portables, peau et tissus cohérents

OpenPBR est un modèle de shading standardisé conçu comme un über-shader capable de représenter une grande variété de matériaux CG.[^openpbr] Il inclut notamment des paramètres pour les matériaux organiques/subsurface, utiles pour la peau.[^openpbr-skin]

À retenir :

- Les personnages doivent utiliser un modèle matériau cohérent avec le reste d’IsoWorld.
- Peau, cheveux, yeux, tissus, cuir, métal, plastique, os, boue, sang, poussière et humidité doivent être des variations d’un pipeline PBR commun.
- Les couches dynamiques — saleté, pluie, sueur, sang, neige, poussière, usure — doivent être paramétriques et dérivées de l’environnement.

### 1.9 Metal / Apple Silicon : renderer custom viable, mais il faut être strict sur les budgets

Metal fournit compute passes, argument buffers, mesh shaders, Model I/O et des samples pour synchroniser CPU/GPU et éviter les stalls.[^metal-compute][^metal-argbuffers][^metal-mesh-shaders][^modelio] Pour les personnages, cela implique :

- GPU skinning pour les meshes visibles.
- Compute pass optionnel pour morphs, cloth léger, hair simulation, culling et pose caches.
- Argument buffers pour textures/materials/skeleton palettes.
- Triple buffering des buffers dynamiques.
- LOD agressif : les personnages peuvent exploser les budgets si peau, cheveux, vêtements, accessoires, ombres et animation sont tous full quality.

---

## 2. Vision produit pour IsoWorld

Le Character System doit répondre à ces objectifs :

1. **Personnage joueur toujours humanoïde** : lisible, animable, compatible gameplay, customisable, capable d’utiliser équipement, armes, outils, véhicules, cordes, escaliers, échelles, interactions et animations procédurales.
2. **Variantes infinies mais contrôlées** : le système doit générer de la variété sans produire d’aberrations anatomiques, de clipping massif, de vêtements impossibles ou de silhouettes incohérentes.
3. **PNJ cohérents avec le monde** : un monde antique sans métal industriel ne doit pas générer des PNJ cyberpunk ; une planète arctique doit influencer vêtements, peau exposée, accessoires, démarches et audio.
4. **Thèmes procéduraux** : chaque seed peut définir des cultures, technologies, couleurs, matériaux, costumes, normes, blessures fréquentes, tabous, symboles, armes et silhouettes.
5. **États physiques persistants** : un personnage peut vieillir, grossir, maigrir, se blesser, porter une cicatrice, perdre un membre, recevoir une prothèse, être brûlé, sali, gelé, infecté, tatoué, marqué par une faction, etc.
6. **Haute qualité visuelle** : peau crédible, yeux lisibles, cheveux stylisés ou réalistes, vêtements propres au thème, détails de surface, matériaux cohérents, silhouettes fortes.
7. **Runtime maîtrisé** : les personnages proches sont riches ; les PNJ lointains sont compactés ; les foules utilisent variations low-cost.
8. **Pipeline extensible** : ajouter un nouveau type de vêtement, une nouvelle culture, une nouvelle époque ou un nouveau corps ne doit pas nécessiter de réécrire le moteur.

---

## 3. Architecture proposée : ICCS — IsoWorld Character & Customization System

### 3.1 Vue d’ensemble

```text
World Seed
  └── WorldRPGDNA
      ├── Era / Tech Level / Magic Level / Culture Rules
      ├── Biome / Climate / Settlement / Faction Rules
      └── CharacterThemeRules
            ↓
CharacterDNA
  ├── IdentityDNA
  ├── BodyDNA
  ├── FaceDNA
  ├── SkinDNA
  ├── HairDNA
  ├── VoiceDNA
  ├── AnimationDNA
  ├── WardrobeDNA
  ├── EquipmentDNA
  ├── InjuryStateDNA
  ├── AgeStateDNA
  ├── MaterialStateDNA
  └── GameplayStateDNA
            ↓
CharacterRecipeGraph
  ├── Mesh selection / generation
  ├── Morph target weights
  ├── Skeleton proportions
  ├── Skin/hair/eye/material generation
  ├── Clothing layering and fitting
  ├── Accessory sockets
  ├── Animation profile
  ├── Audio profile
  ├── Collision/profile capsules
  └── LOD policy
            ↓
CharacterBuildCache
  ├── Runtime mesh buffers
  ├── Skinning data
  ├── Morph compressed data
  ├── Materials/textures/atlases
  ├── Hair cards/strands LODs
  ├── Cloth zones
  ├── Collision primitives
  ├── Attachment graph
  └── Debug metadata
            ↓
Runtime Systems
  ├── Renderer Metal
  ├── Animation System
  ├── Procedural Animation / IK
  ├── Audio Engine
  ├── Physics / Collision
  ├── Inventory / Equipment
  ├── RPG State
  └── Save System
```

### 3.2 Les couches du système

Le système doit être découpé en couches indépendantes :

| Couche | Rôle | Runtime ? | Exemple |
|---|---:|---:|---|
| `CharacterDNA` | Identité paramétrique compacte | Oui | Taille, âge, peau, culture, voix |
| `CharacterRecipeGraph` | Résolution des règles | Partiel | Choisir corps + vêtements compatibles |
| `CharacterBuildCache` | Assets runtime optimisés | Oui | Buffers, textures, LOD, morphs |
| `AnatomyLayer` | Corps, squelette, morphologie | Oui | Proportions, posture, collisions |
| `SurfaceLayer` | Peau, yeux, cheveux, marques | Oui | Taches, rides, cicatrices, tatouages |
| `WardrobeLayer` | Vêtements, armures, accessoires | Oui | Robe, manteau, bottes, sac |
| `EquipmentLayer` | Armes, outils, objets portés | Oui | Épée, torche, scanner, fusil |
| `StateLayer` | États persistants/cosmétiques | Oui | Blessure, vieillissement, saleté |
| `AnimationProfile` | Démarche, pose, style moteur | Oui | Boiteux, militaire, fatigué |
| `AudioProfile` | Voix, pas, respirations, efforts | Oui | Voix grave, bottes lourdes |
| `LODPolicy` | Budget selon distance/importance | Oui | Hero, NPC, crowd, impostor |

### 3.3 Principe clé : tout ne se génère pas au même moment

Il faut distinguer :

- **Génération seed-time** : création du `CharacterDNA` à partir de la seed.
- **Génération load-time** : résolution de la recette, choix des assets, calcul des morphs, cache textures.
- **Génération background/cache** : baking de textures, génération de hair cards, refit vêtements, compression.
- **Génération runtime frame** : animation, IK, morphs dynamiques, cloth léger, saleté humide, expression, audio.
- **Génération offline tooling** : authoring de bibliothèques, templates, scans, vêtements, grooms, correctifs.

Règle : **le runtime ne doit jamais faire une génération lourde qui peut être précompilée**. La proceduralité doit être majoritairement dans la donnée, les recettes, les seeds et les caches, pas dans des opérations coûteuses par frame.

---

## 4. `CharacterDNA` : représentation déterministe et compacte

### 4.1 Structure proposée

```swift
struct CharacterDNA: Codable, Hashable {
    var schemaVersion: UInt32
    var characterSeed: UInt64
    var worldSeed: UInt64
    var factionSeed: UInt64
    var familySeed: UInt64
    var lifeHistorySeed: UInt64

    var identity: IdentityDNA
    var body: BodyDNA
    var face: FaceDNA
    var skin: SkinDNA
    var hair: HairDNA
    var eyes: EyeDNA
    var voice: VoiceDNA
    var animation: AnimationDNA
    var wardrobe: WardrobeDNA
    var equipment: EquipmentDNA
    var state: CharacterStateDNA
    var theme: CharacterThemeDNA
    var lod: CharacterLODPolicy
}
```

### 4.2 Identité

`IdentityDNA` définit :

- nom généré ;
- âge chronologique ;
- âge apparent ;
- culture ;
- faction ;
- métier ;
- statut social ;
- région d’origine ;
- climat d’origine ;
- histoire de vie ;
- personnalité gameplay ;
- archétype d’animation ;
- archétype vocal ;
- préférences de vêtements ;
- couleurs symboliques ;
- marques d’appartenance ;
- contraintes religieuses/culturelles ;
- niveau technologique ;
- exposition au danger ;
- expérience de combat ;
- rang ;
- richesse ;
- hygiène ;
- accès aux soins ;
- normes esthétiques.

### 4.3 Corps

`BodyDNA` doit contenir :

- taille globale ;
- masse corporelle ;
- silhouette ;
- largeur d’épaules ;
- largeur de bassin ;
- longueur de jambes ;
- longueur de bras ;
- longueur du cou ;
- taille des mains ;
- taille des pieds ;
- volume thoracique ;
- volume abdominal ;
- musculature globale ;
- musculature par zone ;
- masse grasse globale ;
- répartition de masse grasse ;
- densité osseuse visuelle ;
- posture ;
- courbure du dos ;
- asymétrie corporelle ;
- latéralité ;
- centre de gravité ;
- amplitude articulaire ;
- souplesse ;
- force apparente ;
- fragilité apparente ;
- vieillissement physique ;
- état médical ;
- blessures permanentes ;
- prothèses ;
- amputations ;
- modifications corporelles ;
- mutations éventuelles selon univers ;
- échelle de collision ;
- échelle de pas ;
- profil de marche.

### 4.4 Visage

`FaceDNA` doit contenir :

- forme générale du crâne ;
- largeur du visage ;
- longueur du visage ;
- mâchoire ;
- menton ;
- pommettes ;
- front ;
- arcades sourcilières ;
- nez ;
- bouche ;
- lèvres ;
- oreilles ;
- yeux ;
- paupières ;
- cernes ;
- joues ;
- rides ;
- asymétrie ;
- dents visibles ;
- peau du visage ;
- pilosité faciale ;
- expressions de repos ;
- neutral pose ;
- sourcil dominant ;
- tension faciale ;
- fatigue ;
- cicatrices faciales ;
- tatouages faciaux ;
- peintures rituelles ;
- piercings ;
- implants faciaux ;
- masques ou accessoires permanents.

### 4.5 Peau et surface

`SkinDNA` doit gérer :

- couleur de base ;
- variations de teinte ;
- sous-tons ;
- rougeurs ;
- zones plus sombres ;
- taches ;
- grains de beauté ;
- pores ;
- rugosité ;
- brillance ;
- subsurface approximé ;
- sécheresse ;
- sueur ;
- saleté ;
- boue ;
- poussière ;
- neige ;
- sang ;
- brûlure ;
- bleu/hématome ;
- cicatrice récente ;
- cicatrice ancienne ;
- tatouages ;
- peintures ;
- marques de faction ;
- marques de métier ;
- marques de maladie ;
- effets magiques/tech selon univers ;
- implants sous-cutanés ;
- veines visibles ;
- pâleur ;
- bronzage ;
- exposition climat.

### 4.6 Cheveux, pilosité, grooms

`HairDNA` doit gérer :

- présence/absence de cheveux ;
- implantation ;
- densité ;
- longueur ;
- texture ;
- raideur ;
- ondulation ;
- boucle ;
- frizz ;
- volume ;
- épaisseur des mèches ;
- couleur principale ;
- mèches secondaires ;
- grisonnement ;
- racines ;
- humidité ;
- saleté ;
- poussière ;
- neige ;
- coiffure ;
- tresse ;
- dreadlocks ;
- queue ;
- chignon ;
- rasage partiel ;
- tonsure ;
- crête ;
- coiffure militaire ;
- coiffure rituelle ;
- accessoires cheveux ;
- barbe ;
- moustache ;
- favoris ;
- sourcils ;
- cils ;
- pilosité corporelle.

### 4.7 Voix et audio

`VoiceDNA` doit gérer :

- hauteur de voix ;
- timbre ;
- souffle ;
- nasalité ;
- rugosité ;
- âge vocal ;
- accent fictif/culturel ;
- débit ;
- intensité ;
- respiration ;
- efforts ;
- cris ;
- douleur ;
- fatigue ;
- maladie ;
- masque/casque qui filtre la voix ;
- prothèse vocale ;
- voix augmentée ;
- réverbération d’équipement ;
- bruits d’armure ;
- pas liés aux chaussures ;
- frottements vêtements ;
- respiration selon endurance.

### 4.8 États persistants

`CharacterStateDNA` doit être séparé du `CharacterDNA` de naissance. Cela permet à un personnage de changer sans perdre son identité de base.

```swift
struct CharacterStateDNA: Codable, Hashable {
    var ageYearsPassed: Float
    var bodyMassDelta: Float
    var muscleDelta: Float
    var fatDelta: Float
    var fatigue: Float
    var hydration: Float
    var nutrition: Float
    var sleepDebt: Float
    var stress: Float
    var injuries: [InjuryRecord]
    var scars: [ScarRecord]
    var lostBodyParts: [BodyPartID]
    var prosthetics: [ProstheticRecord]
    var diseases: [DiseaseRecord]
    var cosmeticChanges: [CosmeticRecord]
    var dirtLayers: [MaterialContamination]
    var equipmentWear: [EquipmentWearRecord]
}
```

---

## 5. Architecture anatomique

### 5.1 Squelette canonique

Le joueur étant toujours humanoïde, il faut imposer un **squelette canonique IsoHumanoidRig** :

- root ;
- pelvis ;
- spine_01/02/03 ;
- chest ;
- neck ;
- head ;
- clavicles ;
- upper/lower arms ;
- hands ;
- doigts complets ;
- legs ;
- feet ;
- toes ;
- face rig minimal ;
- eye bones ;
- jaw ;
- optional twist bones ;
- helper bones vêtements ;
- sockets armes/outils/accessoires ;
- cloth anchors ;
- hair anchors ;
- collision anchors ;
- IK markers.

Règle : toutes les morphologies doivent rester compatibles avec ce squelette, même si les proportions changent.

### 5.2 Niveaux de rig

| Niveau | Usage | Bones | Coût | Qualité |
|---|---:|---:|---:|---:|
| `HeroRig` | Joueur, cutscene, PNJ important | complet | élevé | très haute |
| `GameplayRig` | PNJ proches | corps complet + face léger | moyen | haute |
| `CrowdRig` | foule proche/moyenne | corps simplifié | faible | correcte |
| `FarRig` | PNJ lointains | peu de bones | très faible | silhouette |
| `ImpostorRig` | très loin | aucun/skinned baked | minimal | image |

### 5.3 Morphologie : approche multi-couches

Il faut éviter un unique slider “corps”. Le corps doit être construit par couches :

1. **Scale global** : taille globale.
2. **Proportions squelettiques** : longueur des membres, largeur épaules/bassin.
3. **Volume musculaire** : masses locales.
4. **Volume gras** : volumes et zones molles.
5. **Âge** : posture, peau, volume, rides, pilosité, démarche.
6. **Asymétrie** : petites différences gauche/droite.
7. **État dynamique** : fatigue, blessure, maladie.
8. **État historique** : cicatrices, amputations, implants.

### 5.4 Zones corporelles paramétrables

- crâne ;
- visage ;
- cou ;
- épaules ;
- clavicule ;
- poitrine ;
- dos ;
- abdomen ;
- taille ;
- bassin ;
- fessiers ;
- bras haut ;
- avant-bras ;
- poignets ;
- mains ;
- doigts ;
- cuisses ;
- genoux ;
- mollets ;
- chevilles ;
- pieds ;
- orteils ;
- colonne ;
- posture générale.

### 5.5 Contraintes anatomiques

Le générateur doit empêcher :

- bras trop longs ou trop courts par rapport au gameplay ;
- pieds trop petits pour les animations ;
- proportions qui cassent les vêtements ;
- volume qui dépasse les collisions ;
- articulation impossible ;
- auto-intersections majeures ;
- épaules incompatibles avec armes ;
- mains incompatibles avec outils ;
- cou trop long/court pour casques ;
- tête incompatible avec cheveux/casques ;
- membres manquants sans profil animation adapté ;
- corps trop extrême sans LOD/collision spécifiques.

### 5.6 Collision liée au personnage

Le Character System doit fournir au système physique :

- capsule globale ;
- capsules secondaires ;
- colliders pieds ;
- colliders mains ;
- colliders tête ;
- colliders équipement ;
- colliders vêtements simulés ;
- volume d’équilibre ;
- centre de masse ;
- support polygon ;
- reach volumes ;
- climb volumes ;
- hurtboxes ;
- hitboxes ;
- sockets d’interaction.

Les proportions du personnage influencent :

- hauteur caméra ;
- longueur de pas ;
- vitesse naturelle ;
- saut ;
- portée des mains ;
- capacité à grimper ;
- volume d’évitement ;
- encombrement avec sacs/armures ;
- rayon de collision ;
- pose dans véhicules ou sièges.

---

## 6. Génération du personnage joueur

### 6.1 Contraintes spécifiques au joueur

Le joueur doit :

- rester humanoïde ;
- être compatible avec toutes les mécaniques de base ;
- utiliser toutes les armes/outils standards ;
- pouvoir porter la majorité des vêtements ;
- pouvoir monter les escaliers/cordes/échelles ;
- pouvoir grimper ;
- avoir des animations fiables ;
- avoir une silhouette lisible ;
- pouvoir être customisé ;
- sauvegarder toutes ses évolutions ;
- garder une collision stable malgré les changements cosmétiques.

### 6.2 Slider vs seed

Le joueur doit pouvoir choisir :

- une génération aléatoire depuis seed ;
- une customisation manuelle ;
- une customisation par thème ;
- une évolution en jeu ;
- des modifications temporaires ;
- des changements permanents.

Le système doit séparer :

- `BasePlayerDNA` : identité initiale.
- `PlayerCustomizationState` : choix du joueur.
- `PlayerLifeState` : conséquences du gameplay.
- `PlayerEquipmentState` : équipement actuel.
- `PlayerCosmeticState` : apparence temporaire.

### 6.3 Possibilités de génération joueur — longue liste

Le joueur pourrait générer ou modifier :

1. taille ;
2. corpulence ;
3. musculature ;
4. distribution musculaire ;
5. distribution de masse grasse ;
6. posture droite ;
7. posture voûtée ;
8. posture militaire ;
9. posture furtive ;
10. démarche relaxée ;
11. démarche nerveuse ;
12. démarche lourde ;
13. démarche blessée ;
14. démarche âgée ;
15. démarche agile ;
16. largeur d’épaules ;
17. largeur de bassin ;
18. longueur de jambes ;
19. longueur de bras ;
20. taille des mains ;
21. taille des pieds ;
22. longueur du cou ;
23. forme du torse ;
24. forme du dos ;
25. courbure de colonne ;
26. asymétrie légère ;
27. dominance droite/gauche ;
28. forme du crâne ;
29. forme du visage ;
30. menton ;
31. mâchoire ;
32. pommettes ;
33. front ;
34. nez ;
35. yeux ;
36. paupières ;
37. sourcils ;
38. oreilles ;
39. bouche ;
40. lèvres ;
41. dents ;
42. rides ;
43. âge apparent ;
44. peau lisse ;
45. peau rugueuse ;
46. pores ;
47. taches de rousseur ;
48. taches de vieillesse ;
49. grains de beauté ;
50. cicatrices ;
51. tatouages ;
52. peintures corporelles ;
53. marques de faction ;
54. marques rituelles ;
55. brûlures ;
56. traces de chirurgie ;
57. implants visibles ;
58. veines visibles ;
59. saleté ;
60. boue ;
61. poussière ;
62. sueur ;
63. sang ;
64. neige ;
65. pluie sur peau ;
66. cheveux courts ;
67. cheveux longs ;
68. cheveux bouclés ;
69. cheveux raides ;
70. cheveux ondulés ;
71. cheveux crépus ;
72. crâne rasé ;
73. tonsure ;
74. crête ;
75. queue de cheval ;
76. chignon ;
77. tresse ;
78. dreadlocks ;
79. mèches colorées ;
80. cheveux gris ;
81. barbe courte ;
82. barbe longue ;
83. moustache ;
84. favoris ;
85. sourcils épais ;
86. cils ;
87. pilosité corporelle ;
88. couleur des yeux ;
89. hétérochromie ;
90. yeux augmentés ;
91. lentilles ;
92. cicatrice œil ;
93. œil manquant ;
94. prothèse oculaire ;
95. voix grave ;
96. voix aiguë ;
97. voix rauque ;
98. voix soufflée ;
99. voix mécanique ;
100. voix masquée ;
101. accent culturel ;
102. respiration calme ;
103. respiration asthmatique ;
104. effort audible ;
105. rire ;
106. cri ;
107. douleur ;
108. fatigue vocale ;
109. vêtements de base ;
110. armure ;
111. casque ;
112. masque ;
113. sac ;
114. ceinture ;
115. chaussures ;
116. bijoux ;
117. arme principale ;
118. arme secondaire ;
119. outil ;
120. instrument ;
121. gadget technologique ;
122. objet rituel ;
123. prothèse bras ;
124. prothèse jambe ;
125. main mécanique ;
126. exosquelette ;
127. support respiratoire ;
128. lentille augmentée ;
129. cape ;
130. manteau ;
131. uniforme ;
132. style nomade ;
133. style aristocratique ;
134. style militaire ;
135. style industriel ;
136. style cybernétique ;
137. style post-apocalyptique ;
138. style forestier ;
139. style désertique ;
140. style arctique ;
141. style maritime ;
142. style souterrain ;
143. style religieux ;
144. style artisanal ;
145. style scientifique ;
146. style explorateur ;
147. style marchand ;
148. style chasseur ;
149. style mage/rituel si monde fantastique ;
150. style spatial si monde futuriste.

---

## 7. PNJ : génération cohérente avec régions, factions et gameplay

### 7.1 PNJ comme produit du monde

Un PNJ doit être généré par :

- seed globale ;
- biome local ;
- settlement local ;
- faction ;
- classe sociale ;
- métier ;
- époque ;
- technologie ;
- climat ;
- dangerosité du monde ;
- économie locale ;
- religion/culture ;
- histoire personnelle ;
- accès aux ressources ;
- niveau de guerre ;
- niveau de maladie ;
- règles RPG du monde.

Exemple :

```text
worldSeed = monde désertique post-effondrement
settlement = village de canyon vertical
faction = récupérateurs solaires
profession = mécanicien grimpeur
→ peau brûlée par soleil, lunettes, foulard, gants, harnais, chaussures d’escalade, outils, poussière, posture agile, voix sèche, cicatrices, vêtements réparés, accessoires métalliques recyclés.
```

### 7.2 Classes de PNJ

- PNJ hero proche ;
- PNJ compagnon ;
- PNJ marchand ;
- PNJ civil ;
- PNJ garde ;
- PNJ artisan ;
- PNJ ennemi ;
- PNJ boss ;
- PNJ foule ;
- PNJ enfant/jeune si le jeu l’autorise ;
- PNJ âgé ;
- PNJ malade ;
- PNJ blessé ;
- PNJ robot humanoïde ;
- PNJ augmenté ;
- PNJ mutant humanoïde ;
- PNJ rituel ;
- PNJ spectral/holographique si univers compatible.

### 7.3 Budgets PNJ

| Type | Qualité | Corps | Face | Cheveux | Vêtements | Simulation | Usage |
|---|---:|---:|---:|---:|---:|---:|---|
| Companion | très haute | complet | complet | strands/cards | complet | cloth/hair partiel | proche permanent |
| Quest NPC | haute | complet | expressif | cards | détaillé | limité | dialogues |
| Civil proche | moyenne | complet | léger | cards/mesh | modulaires | très limité | ville |
| Crowd | basse | simplifié | atlas | mesh/cards | baked | non | foule |
| Far Crowd | très basse | impostor | non | texture | texture | non | ambiance |

---

## 8. Système de vêtements et accessoires

### 8.1 Principe : layering, sockets, refit, clipping masks

Les vêtements doivent être gérés par couches :

1. **Base body** : corps nu ou sous-couche.
2. **Underwear / base layer** : sous-vêtements, combinaison, bandages.
3. **Inner clothing** : chemise, tunique, t-shirt.
4. **Mid layer** : gilet, armure légère, pull.
5. **Outer layer** : manteau, cape, cuirasse.
6. **Attachment layer** : ceintures, sangles, sacs, holsters.
7. **Armor layer** : plaques, casques, protections.
8. **Tool/weapon layer** : armes, outils.
9. **Cosmetic layer** : bijoux, badges, peintures, insignes.
10. **State layer** : usure, saleté, sang, neige, pluie, déchirure.

Chaque item doit définir :

- slots occupés ;
- sockets ;
- zones corporelles recouvertes ;
- masques de peau à cacher ;
- compatibilités ;
- incompatibilités ;
- refit parameters ;
- cloth zones ;
- collision zones ;
- LODs ;
- matériaux ;
- états de dégradation ;
- sons associés ;
- poids ;
- encombrement ;
- protection ;
- chaleur ;
- étanchéité ;
- respirabilité ;
- statut culturel.

### 8.2 Liste ultra longue d’assets liés aux personnages

#### Corps / base

- mesh corps complet ;
- mesh tête ;
- mains ;
- pieds ;
- dents ;
- langue ;
- yeux ;
- cils ;
- sourcils ;
- ongles ;
- cicatrices 3D ;
- implants cutanés ;
- prothèses ;
- membres alternatifs ;
- bandages corporels ;
- pansements ;
- tatouages ;
- peintures corporelles ;
- marques rituelles ;
- marques de faction ;
- traces de brûlure ;
- traces de maladie ;
- salissures ;
- sang ;
- boue ;
- poussière ;
- sueur ;
- neige ;
- givre.

#### Cheveux / pilosité

- cheveux courts ;
- cheveux mi-longs ;
- cheveux longs ;
- cheveux rasés ;
- cheveux en bataille ;
- cheveux militaires ;
- cheveux nobles ;
- cheveux rituels ;
- tresses simples ;
- tresses multiples ;
- dreadlocks ;
- locks courtes ;
- chignons ;
- queues de cheval ;
- coupe au bol ;
- coupe asymétrique ;
- undercut ;
- crête ;
- tonsure ;
- cheveux mouillés ;
- cheveux gelés ;
- cheveux poussiéreux ;
- cheveux brûlés ;
- mèches colorées ;
- bijoux de cheveux ;
- plumes ;
- perles ;
- anneaux ;
- attaches ;
- bandeaux ;
- voile cheveux ;
- barbe courte ;
- barbe longue ;
- barbe tressée ;
- moustache ;
- favoris ;
- bouc ;
- sourcils ;
- cils ;
- pilosité torse ;
- pilosité bras ;
- pilosité jambes.

#### Sous-couches

- sous-vêtements simples ;
- caleçon ;
- brassière ;
- bandeau ;
- combinaison fine ;
- combinaison thermique ;
- sous-armure ;
- body technique ;
- tunique intérieure ;
- chemise fine ;
- maillot ;
- bandages ;
- linge rituel ;
- vêtement de nuit ;
- base cybernétique ;
- combinaison médicale ;
- couche isolante arctique ;
- couche respirante désert ;
- sous-combinaison spatiale.

#### Hauts

- t-shirt ;
- chemise ;
- tunique ;
- blouse ;
- pull ;
- gilet ;
- veste ;
- veste courte ;
- veste longue ;
- manteau ;
- cape ;
- poncho ;
- robe ;
- robe de cérémonie ;
- tabard ;
- kimono fictif ;
- haori fictif ;
- manteau militaire ;
- manteau de pluie ;
- manteau arctique ;
- manteau de fourrure ;
- parka ;
- blouson ;
- veste en cuir ;
- veste renforcée ;
- veste de pilote ;
- veste de mineur ;
- veste de scientifique ;
- veste de laboratoire ;
- blouse médicale ;
- veste de mécanicien ;
- veste de chasseur ;
- veste de pêcheur ;
- veste de marin ;
- haut de cérémonie ;
- haut de moine ;
- haut tribal ;
- haut en fibres végétales ;
- haut en métal souple ;
- haut holographique ;
- haut bio-tech ;
- haut de combinaison spatiale ;
- haut de scaphandre.

#### Bas

- pantalon simple ;
- pantalon cargo ;
- pantalon militaire ;
- pantalon de cuir ;
- pantalon matelassé ;
- pantalon arctique ;
- pantalon désert ;
- short ;
- jupe ;
- jupe longue ;
- jupe de combat ;
- robe longue ;
- pagne ;
- pantalon de travail ;
- pantalon de mine ;
- pantalon de pilote ;
- pantalon de mécanicien ;
- pantalon noble ;
- pantalon rituel ;
- pantalon renforcé ;
- pantalon avec genouillères ;
- pantalon exosquelette ;
- combinaison intégrale ;
- combinaison de plongée ;
- combinaison spatiale ;
- combinaison NBC ;
- combinaison hazmat ;
- combinaison furtive ;
- combinaison thermique ;
- combinaison de survie.

#### Chaussures

- pieds nus ;
- sandales ;
- mocassins ;
- bottes légères ;
- bottes lourdes ;
- bottes militaires ;
- bottes de montagne ;
- bottes arctiques ;
- bottes désert ;
- bottes de pluie ;
- bottes de pêche ;
- bottes de mine ;
- sabots ;
- chaussures de ville ;
- chaussures nobles ;
- chaussures de sport ;
- chaussures d’escalade ;
- crampons ;
- bottes magnétiques ;
- bottes anti-gravité ;
- bottes mécaniques ;
- chaussures silencieuses ;
- chaussures endommagées ;
- prothèses de pied ;
- patins ;
- raquettes à neige ;
- semelles de boue ;
- semelles métalliques ;
- semelles en bois ;
- semelles en cuir ;
- semelles synthétiques.

#### Gants / mains

- gants fins ;
- gants de cuir ;
- gants de laine ;
- gants arctiques ;
- gants de travail ;
- gants de mécanicien ;
- gants médicaux ;
- gants tactiques ;
- gants de combat ;
- gantelets ;
- gants isolants ;
- gants de soudure ;
- gants de pilote ;
- mitaines ;
- bagues ;
- anneaux ;
- brassards de main ;
- griffes ;
- main prothétique ;
- main robotique ;
- main augmentée ;
- module outil intégré ;
- module arme intégré.

#### Tête / casques / masques

- chapeau simple ;
- capuche ;
- bonnet ;
- turban fictif ;
- foulard ;
- bandeau ;
- couronne ;
- diadème ;
- casque léger ;
- casque lourd ;
- casque militaire ;
- casque médiéval ;
- casque de mineur ;
- casque de chantier ;
- casque de pilote ;
- casque spatial ;
- casque de plongée ;
- masque respiratoire ;
- masque à gaz ;
- masque rituel ;
- masque animal ;
- masque de cérémonie ;
- masque de soudure ;
- masque médical ;
- masque de voleur ;
- lunettes simples ;
- lunettes de soleil ;
- lunettes de protection ;
- lunettes de soudeur ;
- visière ;
- monocle ;
- lentille augmentée ;
- œil mécanique ;
- casque intégral ;
- casque ouvert ;
- casque avec antenne ;
- casque avec lampe ;
- casque avec affichage HUD ;
- casque respiratoire ;
- heaume orné ;
- masque holographique.

#### Armures / protections

- protection textile ;
- cuir léger ;
- cuir durci ;
- maille ;
- plaques ;
- armure lamellaire ;
- armure segmentée ;
- armure composite ;
- armure céramique ;
- armure balistique ;
- armure anti-radiation ;
- armure biologique ;
- armure exosquelette ;
- armure énergétique ;
- épaulières ;
- brassards ;
- coudières ;
- avant-bras ;
- plastron ;
- dorsale ;
- protège-côtes ;
- ceinture blindée ;
- tassettes ;
- cuissards ;
- genouillères ;
- jambières ;
- protège-tibias ;
- protège-cou ;
- bouclier dorsal ;
- bouclier bras ;
- champs de force visuels.

#### Sacs / portage

- sac à dos ;
- sac de voyage ;
- sac de mineur ;
- sac médical ;
- sac militaire ;
- sac de chasseur ;
- sac de marchand ;
- sac de botaniste ;
- sac de pêcheur ;
- panier ;
- besace ;
- sacoche ;
- bourse ;
- carquois ;
- holster ;
- étui à outil ;
- étui à couteau ;
- gourde ;
- cantine ;
- réservoir ;
- bouteille ;
- sac de couchage ;
- tente compacte ;
- corde ;
- grappin ;
- lampe ;
- batterie ;
- radio ;
- scanner ;
- livre ;
- parchemin ;
- caisse portée ;
- fardeau ;
- bébé/animal porté si univers adapté.

#### Bijoux / décorations

- bagues ;
- colliers ;
- pendentifs ;
- amulettes ;
- broches ;
- boucles d’oreilles ;
- bracelets ;
- chevillières ;
- perles ;
- chaînes ;
- médailles ;
- badges ;
- insignes ;
- épingles ;
- reliques ;
- talismans ;
- symboles de faction ;
- symboles religieux ;
- trophées ;
- dents ;
- plumes ;
- os ;
- coquillages ;
- circuits décoratifs ;
- néons ;
- hologrammes ;
- tatouages lumineux ;
- marques AR.

#### Armes

- bâton ;
- gourdin ;
- dague ;
- couteau ;
- épée courte ;
- épée longue ;
- sabre ;
- hache ;
- marteau ;
- masse ;
- lance ;
- hallebarde ;
- faux ;
- arc ;
- arbalète ;
- fronde ;
- javelot ;
- bouclier ;
- pistolet ;
- revolver ;
- fusil ;
- fusil de précision ;
- fusil artisanal ;
- arme énergétique ;
- taser fictif ;
- lance-filet ;
- lance-grappin ;
- arme sonique ;
- arme chimique fictive non réaliste ;
- outil offensif ;
- arme improvisée ;
- arme rituelle ;
- arme biologique fictive ;
- drone porté ;
- tourelle portable ;
- bâton magique/tech selon univers ;
- catalyseur ;
- gantelet énergétique.

#### Outils

- marteau ;
- pioche ;
- pelle ;
- hache de bûcheron ;
- scie ;
- burin ;
- pince ;
- clé ;
- tournevis ;
- corde ;
- grappin ;
- mousqueton ;
- boussole ;
- carte ;
- longue-vue ;
- jumelles ;
- scanner ;
- tablette ;
- instrument de mesure ;
- capteur météo ;
- outil médical ;
- seringue fictive ;
- trousse de soin ;
- kit de couture ;
- kit de réparation ;
- lampe torche ;
- torche ;
- lanterne ;
- briquet ;
- chalumeau ;
- outil de soudure ;
- canne ;
- béquille ;
- instrument musical ;
- caméra ;
- microphone ;
- livre ;
- carnet ;
- plume ;
- stylet ;
- appareil photo ;
- drone compact.

#### Accessoires culturels / métiers

- tablier de forgeron ;
- masque de médecin ;
- robe de savant ;
- manteau de prêtre ;
- uniforme de garde ;
- brassard de faction ;
- insigne de rang ;
- casque de mineur ;
- filet de pêcheur ;
- corde d’escalade ;
- peau de chasseur ;
- herbes de guérisseur ;
- outils de botaniste ;
- lunettes d’ingénieur ;
- clé de mécanicien ;
- instruments d’artiste ;
- instrument de musicien ;
- reliquaire ;
- chapelet fictif ;
- symbole magique ;
- circuit imprimé ;
- badge de corporation ;
- pass numérique ;
- tatouage de clan ;
- peinture de guerre ;
- cape de rang ;
- couronne locale.

---

## 9. Thèmes procéduraux de personnages

### 9.1 Principe

Un thème est un ensemble de règles :

- palette de couleurs ;
- matériaux dominants ;
- silhouettes ;
- motifs ;
- niveau d’usure ;
- protections ;
- accessoires ;
- coiffures ;
- armes ;
- chaussures ;
- symboles ;
- interdits ;
- statut social ;
- climat ;
- technologie ;
- audio ;
- animation ;
- qualité de fabrication.

### 9.2 Longue liste de thèmes potentiels

1. Préhistorique roche/os/peaux ;
2. Nomade steppe ;
3. Nomade désert ;
4. Nomade arctique ;
5. Chasseur forestier ;
6. Cueilleur tropical ;
7. Tribu fluviale ;
8. Tribu volcanique ;
9. Culture lacustre ;
10. Culture maritime primitive ;
11. Village agricole ancien ;
12. Cité antique méditerranéenne fictive ;
13. Cité antique désertique ;
14. Empire de pierre ;
15. Empire de bronze ;
16. Empire de fer ;
17. Culture de temples ;
18. Culture de pyramides ;
19. Culture de ziggourats ;
20. Culture de falaises ;
21. Culture troglodyte ;
22. Culture souterraine ;
23. Culture insulaire ;
24. Culture de marais ;
25. Culture de jungle ;
26. Culture de montagne ;
27. Culture de canyon ;
28. Culture de banquise ;
29. Culture de toundra ;
30. Culture de savane ;
31. Culture de steppe à chevaux ;
32. Culture de caravane ;
33. Culture de pêcheurs ;
34. Culture de mineurs ;
35. Culture de forgerons ;
36. Culture de verriers ;
37. Culture de tisserands ;
38. Culture de botanistes ;
39. Culture de guérisseurs ;
40. Culture de scribes ;
41. Culture de moines ;
42. Culture de chevaliers ;
43. Culture de mercenaires ;
44. Culture de pirates ;
45. Culture de marchands ;
46. Culture aristocratique ;
47. Culture théocratique ;
48. Culture république marchande ;
49. Culture féodale froide ;
50. Culture féodale tropicale ;
51. Culture renaissance ;
52. Culture baroque ;
53. Culture industrielle vapeur ;
54. Culture charbon-acier ;
55. Culture dieselpunk ;
56. Culture guerre de tranchées fictive ;
57. Culture exploration polaire ;
58. Culture océanographique ;
59. Culture expédition scientifique ;
60. Culture moderne rurale ;
61. Culture moderne urbaine ;
62. Culture militaire moderne ;
63. Culture corporate moderne ;
64. Culture survivaliste ;
65. Culture post-effondrement ;
66. Culture récupérateurs ;
67. Culture bunker ;
68. Culture irradiée fictive ;
69. Culture pandémie fictive ;
70. Culture cyberpunk pauvre ;
71. Culture cyberpunk corporate ;
72. Culture néon religieux ;
73. Culture hacker ;
74. Culture implants médicaux ;
75. Culture transhumaniste ;
76. Culture bio-tech ;
77. Culture organique vivante ;
78. Culture symbiotique ;
79. Culture robotique humanoïde ;
80. Culture androïde ;
81. Culture drone swarm ;
82. Culture spatial proche ;
83. Culture station orbitale ;
84. Culture colonie lunaire ;
85. Culture planète désert ;
86. Culture planète océan ;
87. Culture planète glacée ;
88. Culture arche générationnelle ;
89. Culture exosuit lourde ;
90. Culture terraformation ;
91. Culture futur lointain minimaliste ;
92. Culture futur lointain ornemental ;
93. Culture post-humaine humanoïde ;
94. Culture holographique ;
95. Culture énergie cristalline fictive ;
96. Culture magie rituelle ;
97. Culture alchimique ;
98. Culture chamanique ;
99. Culture nécromantique stylisée ;
100. Culture astrale ;
101. Culture solaire ;
102. Culture lunaire ;
103. Culture tempête ;
104. Culture cendre ;
105. Culture ruines anciennes ;
106. Culture bibliothèque-monde ;
107. Culture nomades du ciel ;
108. Culture bâtisseurs de ponts ;
109. Culture grimpeurs de falaises ;
110. Culture vivant sur arbres géants ;
111. Culture aquatique avec scaphandres ;
112. Culture anti-technologie ;
113. Culture hyper-technologique ;
114. Culture mix magie/tech ;
115. Culture guerre froide fictive ;
116. Culture laboratoire abandonné ;
117. Culture pénitentiaire ;
118. Culture culte de machines ;
119. Culture gardiens de nature ;
120. Culture marchands inter-biomes.

### 9.3 Exemple de règle de thème

```yaml
CharacterTheme: canyon_climbers_solar_reclaimers
palette:
  primary: sun_bleached_ochre
  secondary: oxidized_copper
  accent: solar_blue_glass
materials:
  cloth: rough_canvas_dusty
  leather: cracked_sun_leather
  metal: recycled_aluminum_copper
  tech: low_power_solar_cells
silhouette:
  dominant: slim_layered_vertical
  attachments: ropes_hooks_tools
rules:
  require: [climbing_harness, eye_protection, sun_scarf]
  prefer: [short_hair, boots_climbing, gloves_fingerless]
  forbid: [heavy_cape, polished_armor, snow_boots]
weather_response:
  dust_accumulation: high
  rain_darkening: medium
  sun_bleaching: high
animation:
  gait: agile_careful
  idle: scans_cliff_edges
  hands: often_touch_ropes
```

---

## 10. États physiques persistants : longue liste de paramètres

### 10.1 Vieillissement

- âge chronologique ;
- âge apparent ;
- rides front ;
- rides yeux ;
- rides bouche ;
- peau relâchée ;
- perte de volume visage ;
- cheveux gris ;
- calvitie ;
- posture voûtée ;
- amplitude réduite ;
- vitesse réduite ;
- voix plus rauque ;
- respiration plus audible ;
- mains tremblantes ;
- taches de vieillesse ;
- cicatrisation visible ;
- fatigue plus rapide ;
- démarche plus prudente ;
- difficulté à grimper ;
- douleurs articulaires visuelles ;
- fragilité ;
- expérience/rang visible.

### 10.2 Corps et nutrition

- prise de poids ;
- perte de poids ;
- fonte musculaire ;
- gain musculaire ;
- déshydratation ;
- malnutrition ;
- gonflement ;
- ventre plus marqué ;
- joues creusées ;
- bras plus fins ;
- jambes plus fortes ;
- dos plus musclé ;
- épaules plus larges ;
- fatigue chronique ;
- peau sèche ;
- peau brillante ;
- cernes ;
- tremblements ;
- endurance modifiée ;
- respiration modifiée ;
- son de pas modifié.

### 10.3 Blessures temporaires

- coupure légère ;
- coupure profonde ;
- hématome ;
- bosse ;
- entorse cheville ;
- entorse poignet ;
- fracture bras ;
- fracture jambe ;
- côte fêlée ;
- brûlure légère ;
- brûlure grave ;
- gelure ;
- morsure ;
- piqûre ;
- plaie infectée ;
- saignement ;
- boiterie ;
- bras en écharpe ;
- bandage tête ;
- bandage torse ;
- bandage main ;
- œil tuméfié ;
- nez cassé ;
- respiration douloureuse ;
- douleur au saut ;
- difficulté à porter ;
- faiblesse temporaire.

### 10.4 Blessures permanentes

- cicatrice fine ;
- cicatrice large ;
- cicatrice chirurgicale ;
- cicatrice brûlure ;
- cicatrice faciale ;
- oreille abîmée ;
- nez cassé permanent ;
- œil manquant ;
- œil artificiel ;
- doigt manquant ;
- main manquante ;
- avant-bras manquant ;
- bras manquant ;
- pied manquant ;
- jambe manquante ;
- jambe prothétique ;
- bras prothétique ;
- main mécanique ;
- démarche avec prothèse ;
- asymétrie permanente ;
- colonne blessée ;
- mobilité réduite ;
- voix abîmée ;
- respiration assistée ;
- implant médical ;
- plaque osseuse visible ;
- exosupport ;
- béquille ;
- canne ;
- fauteuil/structure adaptée si gameplay le supporte.

### 10.5 États environnementaux

- mouillé par pluie ;
- trempé ;
- boueux ;
- poussiéreux ;
- couvert de sable ;
- couvert de neige ;
- givre sur vêtements ;
- sueur ;
- sang ;
- suie ;
- cendre ;
- sel marin ;
- mousse végétale ;
- pollen ;
- spores fictives ;
- huile ;
- graisse mécanique ;
- peinture ;
- résine ;
- feuilles collées ;
- boue séchée ;
- vêtements déchirés ;
- armure cabossée ;
- casque rayé ;
- armes usées ;
- chaussures encrassées ;
- cheveux mouillés ;
- cheveux gelés ;
- barbe poussiéreuse.

### 10.6 États psychophysiques visibles

- fatigue ;
- stress ;
- peur ;
- colère ;
- calme ;
- confiance ;
- douleur ;
- froid ;
- chaleur ;
- intoxication fictive ;
- vertige ;
- panique ;
- concentration ;
- vigilance ;
- sommeil manquant ;
- faim ;
- soif ;
- euphorie ;
- choc ;
- deuil ;
- traumatisme ;
- courage ;
- folie rituelle selon univers ;
- influence magique/tech ;
- contrôle mental fictif ;
- infection fictive ;
- mutation progressive.

---

## 11. Règles de génération et variantes

### 11.1 Variantes corrélées

Les paramètres ne doivent pas être indépendants. Exemple :

- Une personne âgée a plus de probabilité de cheveux gris, rides, posture modifiée, voix rauque.
- Un mineur a plus de poussière, épaules/bras développés, casque, lampe, bottes lourdes.
- Un pêcheur côtier a peau salée, vêtements imperméables, bottes, accessoires de corde/filets.
- Un soldat a uniforme, posture, chaussures standardisées, cicatrices possibles.
- Une faction riche a matériaux propres, ornements, meilleures textures.
- Une région froide impose couches thermiques, gants, capuches, peau exposée minimale.

### 11.2 Règles de compatibilité

Le système doit vérifier :

- casque compatible avec coiffure ;
- masque compatible avec barbe ;
- manteau compatible avec sac ;
- armure compatible avec cape ;
- gants compatibles avec prothèse ;
- chaussures compatibles avec pied/prothèse ;
- arme compatible avec main manquante ;
- backpack compatible avec épaulières ;
- foulard compatible avec masque respiratoire ;
- lunettes compatibles avec casque ;
- coiffure longue compatible avec col haut ;
- robe/cape compatible avec animations de course ;
- exosquelette compatible avec collision.

### 11.3 Règles de clipping

Pour chaque vêtement :

- `hiddenBodyRegions` ;
- `compressionRegions` ;
- `clothCollisionRegions` ;
- `maxBodyMorphRange` ;
- `requiresRefit` ;
- `compatibleHairVolumes` ;
- `compatibleArmorSlots` ;
- `requiresUnderLayer` ;
- `forbiddenOuterLayers`.

Exemple :

```yaml
Item: heavy_arctic_hood
slots: [head_outer, neck_outer]
hides: [hair_back_long, ears, neck]
compatibleHair: [short, braided_low_volume, shaved]
forbid: [large_helmet, high_collar_armor]
materials: [fur_trim, waxed_canvas, frost_layer]
weatherRules:
  snowAccumulation: high
  rainDarkening: medium
  windFlutter: low
```

### 11.4 Règles d’adaptation morphologique

Pour adapter les vêtements :

1. Calculer paramètres corps.
2. Appliquer refit par zones : torse, bassin, épaules, bras, jambes.
3. Appliquer correctifs pour extrêmes.
4. Cacher peau sous vêtements.
5. Vérifier collisions simples.
6. Générer/choisir taille de vêtement.
7. Appliquer tension/loose fit.
8. Déterminer zones cloth simulées.
9. Générer LODs.
10. Mettre en cache.

---

## 12. Rendu haute qualité des personnages

### 12.1 Peau

Pipeline recommandé :

- albedo haute résolution ;
- normal map pores/rides ;
- roughness map ;
- subsurface approximation ;
- curvature/ambient occlusion ;
- micro details ;
- decals dynamiques : cicatrices, tatouages, saleté, sang ;
- wetness layer ;
- snow/dust layer ;
- blush/redness zones ;
- age masks ;
- biome exposure masks.

Sans path tracing, on peut obtenir une peau crédible avec :

- diffusion enveloppée/wrap diffuse contrôlée ;
- screen-space subsurface approximé ;
- LUT peau ;
- transmission simple pour oreilles/doigts ;
- normal microdetail ;
- specular dual-lobe ;
- color variation.

### 12.2 Yeux

Les yeux doivent être prioritaires pour la qualité :

- géométrie cornée séparée ;
- iris normal/parallax ;
- wet line ;
- occlusion paupières ;
- tear duct ;
- highlights ;
- anisotropie légère ;
- couleur procédurale ;
- hétérochromie ;
- prothèse oculaire ;
- œil cybernétique.

### 12.3 Cheveux

Stratégie :

| Distance | Représentation | Simulation |
|---|---:|---:|
| très proche | guides/strands partiels | oui, limité |
| proche | cards haute qualité | bones/physics légère |
| moyenne | cards simplifiées | non ou bones |
| loin | mesh/texture | non |
| foule | atlas/impostor | non |

Pour Apple Silicon, commencer par **hair cards procédurales + bones secondaires**, puis ajouter des strands pour héros/proche si budget.

### 12.4 Vêtements

Pipeline :

- matériaux PBR ;
- texture atlas par personnage ;
- détails procéduraux : coutures, usure, patchs, saleté ;
- wrinkles normal maps ;
- cloth zones simulées ;
- secondary bones ;
- décals de dommages ;
- wetness/snow/dust ;
- metal/leather/fabric response.

### 12.5 Accessoires et armes

Les accessoires doivent être des props attachés :

- mesh static/skinned ;
- sockets ;
- offsets paramétriques ;
- collisions ;
- physics secondary ;
- LODs ;
- occlusion/clipping ;
- audio ;
- material states ;
- gameplay stats.

---

## 13. Animation et personnage paramétrique

Le Character System doit alimenter l’Animation System :

- proportions du squelette ;
- longueur des jambes ;
- longueur des bras ;
- poids ;
- centre de masse ;
- force ;
- fatigue ;
- chaussures ;
- blessure ;
- prothèse ;
- équipement porté ;
- armure lourde ;
- sac ;
- cape ;
- arme ;
- démarche culturelle ;
- profession.

Exemples :

- bottes lourdes + armure → pas plus lents, bruit métallique, inertie ;
- jambe blessée → boiterie, IK asymétrique, évitement d’appui ;
- chaussures d’escalade → placement pied plus précis ;
- prothèse jambe → swing spécifique, son mécanique ;
- vieillesse → amplitude réduite, anticipation différente ;
- sac lourd → centre de masse déplacé ;
- manteau long → restrictions de sprint et cloth.

---

## 14. Audio lié au personnage

Chaque personnage doit générer :

- voix ;
- respiration ;
- effort ;
- douleur ;
- cris ;
- rire ;
- toux ;
- pas ;
- frottements vêtements ;
- cliquetis armure ;
- sons accessoires ;
- sons armes ;
- sons prothèses ;
- sons de sac ;
- sons de casque/masque ;
- audio de fatigue ;
- audio de froid ;
- audio de blessure.

Les paramètres de chaussures doivent influencer :

- volume ;
- attaque ;
- grave/aigu ;
- friction ;
- glissement ;
- résonance ;
- matière de semelle ;
- poids du personnage ;
- sol ;
- humidité ;
- vitesse ;
- fatigue ;
- boiterie.

---

## 15. Customisation en jeu

### 15.1 Ce que le joueur peut changer

- coiffure ;
- barbe ;
- couleur cheveux ;
- tatouages ;
- peintures ;
- vêtements ;
- armure ;
- accessoires ;
- sacs ;
- armes visibles ;
- prothèses cosmétiques ;
- implants ;
- masques ;
- casques ;
- bijoux ;
- couleurs de vêtements ;
- motifs ;
- patchs ;
- usure volontaire ;
- style de démarche ;
- voix si système lore compatible ;
- posture ;
- emblèmes ;
- matériel de faction.

### 15.2 Ce que le gameplay peut changer

- vieillissement ;
- poids ;
- muscles ;
- blessures ;
- cicatrices ;
- membres perdus ;
- prothèses ;
- maladie ;
- mutations ;
- teint ;
- fatigue ;
- saleté ;
- usure vêtements ;
- réputation visible ;
- statut social ;
- marques de factions ;
- effets de climat ;
- effets de magie/tech ;
- exposition au soleil ;
- cernes ;
- démarche ;
- voix.

### 15.3 Sauvegarde

La sauvegarde ne doit pas stocker tous les meshes/textures. Elle doit stocker :

- `CharacterDNA` ;
- état courant ;
- équipements ;
- overrides joueur ;
- modifications persistantes ;
- IDs de caches valides ;
- versions de schémas ;
- seeds.

Si le cache est absent, il est régénéré déterministiquement.

---

## 16. Système de LOD personnage

### 16.1 LOD par composant

Chaque personnage doit avoir des LOD indépendants :

- body LOD ;
- face LOD ;
- hair LOD ;
- clothing LOD ;
- accessory LOD ;
- material LOD ;
- animation LOD ;
- physics LOD ;
- audio LOD ;
- AI LOD ;
- shadow LOD ;
- collision LOD.

### 16.2 Politique proposée

| Niveau | Distance/importance | Corps | Face | Cheveux | Vêtements | Animation | Audio |
|---|---:|---:|---:|---:|---:|---:|---:|
| LOD0 | joueur/cinématique | full | full | high | high + cloth | full | full |
| LOD1 | PNJ dialogue | high | high | cards high | high | full/IK | full |
| LOD2 | PNJ proche | medium | medium | cards | medium | reduced | important only |
| LOD3 | ville | low | atlas | mesh | low | reduced fps | low |
| LOD4 | foule loin | impostor | none | texture | texture | baked | none |

### 16.3 Optimisations Metal

- GPU skinning ;
- morphs compressés ;
- animation texture/buffer pour foules ;
- palette de joints compactée ;
- culling par personnage ;
- culling par composant ;
- indirect rendering ;
- material batching ;
- atlas textures ;
- shadow LOD ;
- cloth/hair update rate réduit ;
- animation update rate variable ;
- impostors pour foule ;
- cache des poses.

---

## 17. Pipeline d’authoring

### 17.1 Outils recommandés

- Blender pour meshes, morphs, rigging, geometry nodes, hair prototyping ;
- Houdini pour génération procédurale avancée, vêtements/variantes, batch processing ;
- Substance Designer/Painter pour matériaux et masques ;
- USD pour scènes/rigs complexes et échanges ;
- glTF pour prototypes runtime ;
- outils custom Swift pour visualiser `CharacterDNA` ;
- générateur interne de recettes ;
- validator automatique.

### 17.2 Bibliothèques à constituer

- base bodies ;
- morph targets ;
- face shapes ;
- skin materials ;
- hair templates ;
- beard templates ;
- clothing templates ;
- armor templates ;
- accessory templates ;
- weapon templates ;
- footwear templates ;
- state decals ;
- tattoo/motif library ;
- faction symbols ;
- material swatches ;
- animation profiles ;
- voice profiles ;
- footstep profiles ;
- LOD templates ;
- collision templates.

### 17.3 Build pipeline

```text
Authoring Assets
  ↓
Validation DCC
  ↓
Export USD/glTF/intermediate
  ↓
IsoCharacterCompiler
  ├── normalize skeleton
  ├── validate skin weights
  ├── generate LODs
  ├── compress morphs
  ├── build material atlases
  ├── generate masks
  ├── build cloth zones
  ├── build hair LODs
  ├── build collision proxies
  ├── build socket metadata
  └── write .iwcharpkg
  ↓
Runtime CharacterBuildCache
```

---

## 18. Data model des items

```yaml
CharacterItem:
  id: desert_climber_boots_01
  category: footwear
  slots: [feet]
  themeTags: [desert, climbing, survival, low_tech]
  bodyCompatibility:
    footLength: [0.85, 1.20]
    footWidth: [0.80, 1.25]
    legMorph: any
  gameplay:
    tractionRock: 0.9
    tractionMud: 0.4
    tractionIce: 0.2
    noiseStone: 0.45
    noiseWood: 0.35
    noiseMetal: 0.6
    warmth: 0.2
    waterproof: 0.1
  render:
    materials: [worn_leather, rope_wrap, dusty_rubber]
    lods: [lod0, lod1, lod2]
  audio:
    footstepProfile: leather_grip_boot
  proceduralState:
    dust: biome_desert
    wear: profession_climber
    repairs: faction_reclaimer
```

---

## 19. Character generator : algorithme de haut niveau

```text
function generateCharacter(worldDNA, region, settlement, faction, role, characterSeed):
    rng = StableRNG(characterSeed)

    identity = generateIdentity(worldDNA, region, faction, role, rng)
    theme = resolveCharacterTheme(worldDNA, region, faction, role, identity, rng)

    body = generateBody(identity, theme, rng)
    face = generateFace(identity, body, theme, rng)
    skin = generateSkin(identity, body, region.climate, theme, rng)
    hair = generateHair(identity, theme, age, rng)
    voice = generateVoice(identity, body, age, theme, rng)

    wardrobe = selectWardrobe(theme, climate, role, status, body, rng)
    equipment = selectEquipment(theme, role, wealth, danger, rng)

    state = generateLifeHistoryMarks(identity, role, worldDanger, rng)

    validateCompatibility(body, hair, wardrobe, equipment, state)
    applyFallbacksIfNeeded()

    buildCache = compileCharacter(body, face, skin, hair, wardrobe, equipment, state)

    return CharacterInstance(CharacterDNA(...), buildCache)
```

---

## 20. Validation automatique

Chaque personnage généré doit passer des tests :

### 20.1 Anatomie

- proportions acceptables ;
- rig valide ;
- skin weights valides ;
- pas de membres incohérents ;
- collision compatible ;
- sockets atteignables ;
- amplitude articulaire suffisante.

### 20.2 Vêtements

- slots non conflictuels ;
- clipping sous seuil ;
- casque/coiffure compatible ;
- chaussures/pieds compatibles ;
- gants/mains compatibles ;
- sac/cape compatibles ;
- masques de corps appliqués ;
- cloth zones valides ;
- LODs présents.

### 20.3 Gameplay

- joueur peut courir ;
- joueur peut sauter ;
- joueur peut grimper ;
- joueur peut porter armes/outils ;
- joueur peut interagir ;
- PNJ peut exécuter son rôle ;
- collision pas excessive ;
- prothèses supportées ;
- blessures ont animation adaptée.

### 20.4 Rendu

- textures disponibles ;
- materials valides ;
- hair LODs valides ;
- normal maps correctes ;
- pas d’overdraw excessif ;
- budget triangles respecté ;
- budget draw calls respecté ;
- budget textures respecté.

### 20.5 Lore / thème

- équipement compatible époque ;
- matériaux disponibles dans région ;
- couleurs compatibles faction ;
- métier cohérent ;
- climat cohérent ;
- statut social cohérent ;
- culture cohérente.

---

## 21. Exemples de personnages générés

### 21.1 Joueur explorateur de canyon solaire

- taille moyenne ;
- corps sec/agile ;
- peau bronzée/séchée ;
- cheveux courts poussiéreux ;
- lunettes solaires ;
- foulard ;
- harnais ;
- corde ;
- bottes d’escalade ;
- gants sans doigts ;
- sac compact ;
- outils de réparation solaire ;
- cicatrice avant-bras ;
- démarche légère et prudente ;
- sons de mousquetons ;
- poussière accumulée.

### 21.2 PNJ mineur de cité souterraine

- corps trapu ;
- épaules fortes ;
- peau pâle/poussiéreuse ;
- casque avec lampe ;
- lunettes sales ;
- veste renforcée ;
- pantalon épais ;
- bottes lourdes ;
- pioche ;
- sac à minerai ;
- toux légère ;
- démarche lourde ;
- sons métalliques ;
- charbon/suie.

### 21.3 Noble d’une culture froide

- posture droite ;
- peau claire avec rougeurs froides ;
- coiffure soignée ;
- manteau long brodé ;
- fourrure ;
- gants ;
- bijoux discrets ;
- bottes fines ;
- parfum/audio subtil ;
- marche lente ;
- faible saleté ;
- emblèmes de maison.

### 21.4 Vétéran cybernétique

- âge avancé ;
- cicatrices ;
- œil mécanique ;
- bras prothétique ;
- manteau usé ;
- bottes lourdes ;
- arme modulaire ;
- voix filtrée ;
- cliquetis de prothèse ;
- animation asymétrique ;
- capteurs lumineux ;
- état de fatigue chronique.

---

## 22. Spécificités Swift / Metal

### 22.1 Modules Swift proposés

```text
EngineCore/Characters
  ├── CharacterDNA.swift
  ├── CharacterGenerator.swift
  ├── CharacterRecipeGraph.swift
  ├── CharacterBuildCache.swift
  ├── BodyMorphSystem.swift
  ├── WardrobeSystem.swift
  ├── EquipmentSystem.swift
  ├── CharacterStateSystem.swift
  ├── CharacterLODSystem.swift
  ├── CharacterValidation.swift
  └── CharacterSerialization.swift

Rendering/Metal/Characters
  ├── CharacterRenderer.swift
  ├── GPUSkinningPass.swift
  ├── MorphTargetPass.swift
  ├── HairRenderer.swift
  ├── ClothLitePass.swift
  ├── CharacterMaterialBinder.swift
  └── CharacterShadowPass.swift
```

### 22.2 Buffers runtime

- `JointPaletteBuffer` ;
- `InverseBindPoseBuffer` ;
- `SkinWeightBuffer` ;
- `MorphDeltaBuffer` ;
- `MorphWeightBuffer` ;
- `CharacterInstanceBuffer` ;
- `MaterialParameterBuffer` ;
- `AttachmentTransformBuffer` ;
- `ClothParticleBuffer` ;
- `HairGuideBuffer` ;
- `CollisionProxyBuffer`.

### 22.3 Priorité d’implémentation renderer

1. Skinned mesh simple.
2. Materials PBR peau/vêtement basiques.
3. Morph targets visage/corps.
4. Vêtements modulaires skinnés.
5. Hair cards.
6. Accessoires sockets.
7. LODs par composant.
8. Saleté/sang/wetness par masks.
9. Cloth léger.
10. Hair simulation légère.
11. Crowd animation textures.
12. Impostors.

---

## 23. Interaction avec les autres systèmes IsoWorld

### 23.1 Terrain

- chaussures adaptées aux sols ;
- saleté/boue/neige sur vêtements ;
- animation selon pente ;
- état selon climat ;
- poussière selon désert ;
- usure selon rochers ;
- équipement d’escalade selon verticalité.

### 23.2 Biomes

- vêtements climatiques ;
- couleurs naturelles ;
- matériaux disponibles ;
- peau exposée ;
- accessoires ;
- métiers ;
- maladies ;
- coiffures pratiques ;
- sons de pas.

### 23.3 Props / buildings

- métiers liés aux objets ;
- vêtements locaux ;
- outils associés ;
- culture architecturale reflétée sur les habits ;
- matériaux partagés ;
- emblèmes.

### 23.4 RPG

- faction ;
- classe sociale ;
- historique ;
- blessures ;
- progression ;
- réputation visible ;
- quêtes ;
- statut ;
- transformation du joueur.

### 23.5 Audio

- voix ;
- pas ;
- vêtements ;
- respirations ;
- accessoires ;
- prothèses ;
- armure ;
- état physique.

### 23.6 Animation

- IK dépendant morphologie ;
- motion matching adapté ;
- blessures ;
- poids ;
- équipements ;
- chaussures ;
- prothèses ;
- vieillissement.

---

## 24. Roadmap d’implémentation

### Phase 1 — Base jouable

- squelette humanoïde canonique ;
- skinned mesh simple ;
- `CharacterDNA` minimal ;
- sliders taille/corpulence/visage simples ;
- vêtements modulaires simples ;
- sockets armes/outils ;
- PBR peau/vêtement ;
- sauvegarde customisation ;
- LOD simple.

### Phase 2 — Variantes déterministes

- génération PNJ par seed ;
- thèmes culture/faction ;
- règles vêtements/climat ;
- hair cards ;
- cicatrices/tatouages/saleté ;
- body morphs plus riches ;
- validation automatique ;
- cache de build.

### Phase 3 — Haute qualité personnage joueur

- yeux avancés ;
- peau subsurface approximée ;
- morphs visage ;
- expressions ;
- vêtements refit ;
- chaussures gameplay ;
- audio personnage ;
- vieillissement basique ;
- blessures visibles.

### Phase 4 — Système persistant

- prise/perte de poids ;
- vieillissement complet ;
- blessures permanentes ;
- prothèses ;
- membres manquants supportés ;
- modifications gameplay ;
- customisation avancée ;
- équipements culturels ;
- état environnemental.

### Phase 5 — PNJ/foules

- crowd LOD ;
- animation textures ;
- impostors ;
- variété de foules ;
- métiers/factions ;
- settlement population generator ;
- budget manager.

### Phase 6 — Qualité avancée

- cloth léger ;
- hair simulation proche ;
- pose-space correctives ;
- ML-like deformer simplifié ;
- génération avancée de textures ;
- refit vêtements automatisé ;
- tooling debug complet.

---

## 25. Décisions recommandées

1. Construire un **squelette humanoïde canonique unique** pour joueur/PNJ humanoïdes.
2. Séparer corps, tête, cheveux, vêtements, accessoires, équipements, état et audio.
3. Utiliser `CharacterDNA` comme source de vérité persistante.
4. Générer les variantes par règles corrélées, pas par random indépendant.
5. Précompiler les assets complexes dans `CharacterBuildCache`.
6. Utiliser GPU skinning et LOD par composant.
7. Commencer par hair cards, pas strands complets.
8. Commencer par vêtements skinnés + cloth zones limitées, pas simulation complète.
9. Implémenter les blessures/états comme couches et morphs paramétriques.
10. Lier chaussures, corps, animation, terrain et audio dès le début.
11. Garder un pipeline compatible USD/glTF/Blender/Houdini/Substance.
12. Mettre en place un validator très tôt.
13. Prévoir les prothèses/amputations dans l’architecture, même si le gameplay arrive plus tard.
14. Permettre au joueur de changer d’apparence via overrides non destructifs.
15. Ne jamais générer de personnage “visuellement impossible” sans fallback.

---

## 26. Sources et références

[^metahuman-body]: Epic Games — MetaHuman Body Controls / Parametric Bodies : https://dev.epicgames.com/documentation/metahuman/body-controls
[^metahuman-hair-clothing]: Epic Games — MetaHuman Hair and Clothing Controls : https://dev.epicgames.com/documentation/metahuman/hair-and-clothing-controls
[^mutable-overview]: Epic Games — Mutable Overview in Unreal Engine : https://dev.epicgames.com/documentation/unreal-engine/mutable-overview-in-unreal-engine
[^ml-deformer]: Epic Games — ML Deformer Framework / How to use ML Deformer : https://dev.epicgames.com/documentation/unreal-engine/how-to-use-the-machine-learning-deformer-in-unreal-engine
[^smpl]: Max Planck Institute / SMPL : https://smpl.is.tue.mpg.de/
[^usdskel]: OpenUSD — UsdSkel Skeleton Schema and API : https://openusd.org/dev/api/usd_skel_page_front.html
[^gltf]: Khronos — glTF 2.0 Specification : https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html
[^ue-groom]: Epic Games — Hair Rendering and Simulation in Unreal Engine : https://dev.epicgames.com/documentation/unreal-engine/hair-rendering-and-simulation-in-unreal-engine
[^ue-groom-editor]: Epic Games — Groom Asset Editor User Guide : https://dev.epicgames.com/documentation/unreal-engine/groom-asset-editor-user-guide-in-unreal-engine
[^tressfx]: AMD GPUOpen — TressFX : https://gpuopen.com/tressfx/
[^chaos-cloth]: Epic Games — Clothing Tool / Chaos Cloth : https://dev.epicgames.com/documentation/unreal-engine/clothing-tool-in-unreal-engine
[^openpbr]: Academy Software Foundation — OpenPBR Surface Shading Model : https://academysoftwarefoundation.github.io/OpenPBR/
[^openpbr-skin]: Maxon / Redshift — OpenPBR Material, subsurface/skin notes : https://help.maxon.net/r3d/maya/en-us/Content/html/Material%2BOpenPBR.html
[^metal-compute]: Apple — Metal Compute Passes : https://developer.apple.com/documentation/metal/compute-passes
[^metal-argbuffers]: Apple WWDC21 — Explore bindless rendering in Metal : https://developer.apple.com/videos/play/wwdc2021/10286/
[^metal-mesh-shaders]: Apple WWDC22 — Transform your geometry with Metal mesh shaders : https://developer.apple.com/videos/play/wwdc2022/10162/
[^modelio]: Apple — Model I/O : https://developer.apple.com/documentation/ModelIO

---

## 27. Conclusion

Le système de personnages d’IsoWorld doit être un pilier transversal du moteur. Il ne doit pas seulement générer des corps et des vêtements ; il doit exprimer la seed du monde, la culture, les biomes, l’époque, les règles RPG, les métiers, les blessures, l’histoire de vie, la météo, les matériaux, l’audio et les animations.

La clé est de combiner :

- un modèle humanoïde stable ;
- des paramètres riches ;
- des règles de cohérence ;
- des caches runtime ;
- des LOD agressifs ;
- une intégration forte avec animation/audio/terrain ;
- une customisation joueur non destructive ;
- des états physiques persistants.

Avec cette architecture, IsoWorld peut générer des personnages crédibles, variés et expressifs, tout en restant compatible avec un moteur custom Swift/Metal et des mondes procéduraux déterministes.
