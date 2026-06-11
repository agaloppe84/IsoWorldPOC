# 5. Animations procédurales / paramétriques drivées par la physique

Document de référence pour **IsoWorld** — moteur procédural custom en Swift/Metal, monde déterministe par seed, génération dynamique par chunks autour du joueur, terrain vertical, rendu temps réel haute qualité.

Nom de fichier : `procedural-physics-driven-animation-system.md`

---

## 0. Vision courte

Le système d’animation d’IsoWorld ne doit pas être un simple `AnimationPlayer` qui joue des clips. Il doit être un **moteur d’adaptation corporelle** capable de transformer une intention de gameplay en mouvement crédible, stable, lisible et physiquement cohérent, tout en restant déterministe et suffisamment léger pour tourner sur MacBook Pro M1.

La bonne direction n’est pas “100 % procédural” ni “100 % mocap”. Les productions modernes utilisent plutôt une architecture hybride :

1. **Base haute qualité** : clips animés, mocap, cycles locomotion, poses de référence, clips d’interaction.
2. **Sélection intelligente** : motion matching, pose search, tagging sémantique, contexte terrain, contexte gameplay.
3. **Correction procédurale** : IK, full-body IK, stride warping, slope warping, orientation warping, motion warping, inertialization.
4. **Perception environnementale** : requêtes terrain fines, raycasts, shapecasts, SDF local, matériaux de sol, humidité, obstacles, props proches.
5. **Physique contrôlée** : character motor, centre de masse, contacts, balance, active ragdoll, réactions aux impacts, glissades, trébuchements.
6. **Paramétrisation systémique** : morphologie, équipement, chaussures, fatigue, météo, blessure, humeur, style, compétence, seed du monde.
7. **Debug massif** : contact points, foot locks, friction, phase de marche, score motion matching, support polygon, collisions prédites, erreurs IK.

L’objectif : si le joueur passe près d’un petit rocher, monte une pente humide, marche dans la neige, grimpe une falaise avec une corde, descend des escaliers attachés à une paroi ou se réceptionne sur un sol meuble, son corps doit donner l’impression d’**être conscient de toute la géométrie proche**. Les pieds, mains, bassin, torse, regard, vitesse, appuis, sons et FX doivent s’adapter ensemble.

---

## 1. Recherche industrie : ce qu’il faut retenir

### 1.1 Motion Matching : le standard moderne pour la locomotion riche

Le motion matching consiste à rechercher dans une base de mouvements le fragment qui correspond le mieux à l’état actuel du personnage et à la trajectoire désirée. Au lieu de construire un immense graphe d’états à la main, on annote des données d’animation et on laisse le moteur choisir en continu la meilleure pose/transition.

Points importants pour IsoWorld :

- Très adapté aux locomotions fluides : marche, course, arrêt, virage, strafing, demi-tour, esquive, transitions courtes.
- Très bon quand on dispose d’une base de clips ou mocap variée.
- Nécessite une **base de features** bien pensée : position/vitesse des pieds, root velocity, facing direction, trajectoire future, phase, tags, posture, état arme/outil, contrainte terrain.
- Nécessite des outils de debug : pourquoi tel clip a été choisi, poids des features, coût de transition, coût de collision, contact mismatch.
- La qualité dépend autant des données que du système de correction procédurale après sélection.

Références utiles :

- Unreal Engine documente officiellement un système Motion Matching / Pose Search avec réglages et outils de debug pour observer les choix de sélection et pondérer les critères.
- Ubisoft a communiqué sur Learned Motion Matching comme alternative apprise au motion matching classique, en gardant l’idée de base mais en réduisant certains coûts et besoins de recherche brute.
- Naughty Dog a présenté l’usage du Motion Matching dans *The Last of Us Part II*, en insistant sur les difficultés de production autant que sur la qualité finale.
- EA a présenté l’intégration du motion matching avec des interactions environnementales et multi-personnages, notamment dans Madden/FIFA.

Conséquence pour IsoWorld : **la base locomotion du joueur devrait être motion-matching-ready**, même si la première version commence par une machine d’états + blend trees. Il faut concevoir les données dès maintenant comme une future base de recherche.

---

### 1.2 Pose Warping / Stride Warping / Slope Warping : la correction procédurale indispensable

Les systèmes AAA ne changent pas de clip pour chaque petite variation de sol. Ils adaptent dynamiquement la pose :

- **Stride warping** : ajuste l’amplitude des jambes sans changer entièrement l’animation.
- **Orientation warping** : permet au corps de continuer à regarder/viser dans une direction pendant que le déplacement suit une autre direction.
- **Slope warping** : adapte les pieds et le bassin à une pente.
- **Motion warping** : modifie la root motion pour atteindre précisément une cible, par exemple une marche, une prise de main, un rebord, une attaque, une entrée dans une interaction.
- **Distance matching** : synchronise la progression d’un clip avec la distance restante avant une cible.

Pour IsoWorld, ces techniques sont cruciales parce que le monde est généré dynamiquement. On ne peut pas authorer à la main chaque escalier, rocher, falaise, pente, passerelle ou corde. Les clips doivent être des intentions : “poser le pied”, “monter”, “sauter”, “grimper”, “attraper”, “descendre”. Le système procédural adapte ensuite aux mesures réelles du terrain.

---

### 1.3 Full Body IK : passer de “pieds collés au sol” à “corps cohérent”

Un IK de pied basique corrige uniquement la jambe. Cela suffit pour un prototype, mais pas pour un personnage haute qualité. Dès que le sol devient irrégulier, humide, vertical, avec obstacles, cordes, rochers et escaliers attachés, il faut résoudre le corps comme un ensemble :

- pieds ;
- genoux ;
- bassin ;
- colonne ;
- épaules ;
- mains ;
- tête/regard ;
- centre de masse ;
- contraintes d’équilibre ;
- limites articulaires ;
- contacts multiples.

Un Full Body IK permet d’avoir plusieurs effecteurs simultanés : deux pieds sur une pente, une main sur une paroi, l’autre sur une corde, bassin ajusté, torse incliné, tête qui regarde la prochaine prise. C’est indispensable pour :

- escalade ;
- franchissement ;
- marche dans les rochers ;
- descente raide ;
- saut/réception ;
- poussée/tirage d’objet ;
- interaction avec porte, levier, table ;
- personnage blessé ou chargé ;
- animal quadrupède ;
- créature multi-pattes.

---

### 1.4 IK biomécanique prédictif : le vrai sujet du contact au sol

L’IK réactif mesure le sol sous le pied au dernier moment, puis déplace le pied. C’est simple, mais cela donne souvent :

- pied qui glisse ;
- genou qui pop ;
- bassin qui tremble ;
- pied qui se pose sur des points absurdes ;
- animation qui perd son intention ;
- personnage qui semble “flotter” au-dessus du terrain.

L’approche moderne est **prédictive** : avant que le pied touche le sol, on estime où il devrait se poser, on scanne les zones candidates, on choisit un appui naturel, puis on adapte progressivement la trajectoire du pied pendant la phase de swing. Cela permet de gérer le cas demandé : si un petit rocher est devant le joueur, le pied peut être placé naturellement **près du rocher**, sur la zone stable la plus proche, plutôt que directement au-dessus du rocher ou à travers lui.

Pour IsoWorld, chaque pas doit être planifié par un **Footstep Planner** qui connaît :

- la phase de locomotion ;
- le pied concerné ;
- la trajectoire prévue du root ;
- la vitesse du joueur ;
- la direction de regard ;
- la géométrie proche ;
- le type de sol ;
- l’humidité ;
- la friction ;
- la chaussure ;
- la pente ;
- les obstacles bas ;
- les rebords ;
- la largeur du personnage ;
- les limites articulaires ;
- la stabilité du support.

---

### 1.5 Physique contrôlée / Active Ragdoll : réalisme sans perdre le gameplay

La physique brute produit du chaos. Le clip brut produit de la rigidité. Le bon système mélange les deux :

- animation kinematic normale pour la lisibilité et le contrôle ;
- corps physique simplifié pour contacts/impulsions ;
- contraintes articulaires pour réactions ;
- PD controllers pour active ragdoll ;
- blend progressif vers ragdoll en chute/impact ;
- récupération procédurale vers animation contrôlée ;
- balance controller pour glissade, stumble, perte d’appui.

Les moteurs/jeux qui ont marqué l’industrie, comme ceux utilisant des approches de type Euphoria/Dynamic Motion Synthesis, montrent l’intérêt de personnages qui ne rejouent pas toujours la même réaction. Les travaux DeepMimic montrent aussi comment des politiques physiques apprises peuvent imiter des clips tout en réagissant aux perturbations. Pour IsoWorld, il ne faut pas forcément entraîner un contrôleur RL en V1, mais il faut concevoir l’architecture pour pouvoir ajouter plus tard des contrôleurs physiques spécialisés.

---

### 1.6 Runtime data-oriented : Ozz/ACL comme inspiration

Les systèmes d’animation performants sont souvent data-oriented :

- poses stockées en SoA ;
- rotations quantifiées ;
- decompression rapide ;
- sampling vectorisé ;
- blending par jobs ;
- allocation stable ;
- pas de graph objet lourd à chaque frame ;
- cache clair entre animation, skeleton, skinning et rendu.

Pour un moteur Swift/Metal, ce point est essentiel. Swift peut être très propre côté architecture, mais le runtime animation doit garder des buffers compacts, des boucles prédictibles, des allocations minimales et des données transférables vers Metal.

---

## 2. Principe central pour IsoWorld : Environment-Aware Procedural Animation

Je propose de nommer le système : **IsoMotion**.

IsoMotion est composé de cinq couches :

```text
Gameplay Intent
    ↓
Motion Brain / Planner
    ↓
Motion Selection / Clip Graph / Pose Search
    ↓
Procedural Adaptation Layer
    ↓
Physics-Aware Contact & Rendering Output
```

Le système ne reçoit pas seulement “joueur avance à 4 m/s”. Il reçoit :

```text
Je veux avancer à 4 m/s vers le nord-est,
sur une pente humide à 18°,
avec bottes lourdes,
en portant un sac,
avec un petit rocher à 42 cm devant le pied droit,
un sol argileux mou,
et une racine traversant la trajectoire du pied gauche.
```

Il doit produire :

- choix d’une animation de marche/course compatible ;
- phase et pied d’appui ;
- trajectoire future du root ;
- placement naturel des pieds ;
- adaptation bassin/torse ;
- vitesse corrigée par friction ;
- micro-glissade si nécessaire ;
- son de pas adapté ;
- particules boue/eau/neige ;
- empreinte ou décalque ;
- éventuel stumble si appui instable ;
- collision stable avec le terrain ;
- sortie déterministe.

---

## 3. Architecture globale proposée

### 3.1 Modules principaux

```text
EngineCore/
  Animation/
    Skeleton.swift
    Pose.swift
    AnimationClip.swift
    AnimationSampler.swift
    BlendTree.swift
    AnimationGraph.swift
    MotionDatabase.swift
    PoseSearchIndex.swift
    MotionTags.swift
    MotionEvents.swift

  IsoMotion/
    MotionBrain.swift
    LocomotionPlanner.swift
    FootstepPlanner.swift
    ContactSensorSystem.swift
    TerrainContactClassifier.swift
    ProceduralAnimationStack.swift
    FullBodyIKSolver.swift
    FootIKSolver.swift
    HandIKSolver.swift
    MotionWarping.swift
    PoseWarping.swift
    BalanceController.swift
    ActiveRagdollController.swift
    PhysicalAnimationBody.swift
    SurfaceResponseModel.swift
    FootwearModel.swift
    AnimationVariantRules.swift
    AnimationDebugSnapshot.swift

  Physics/
    CharacterMotor.swift
    CollisionWorld.swift
    PhysicsMaterial.swift
    ContactManifold.swift
    QueryShape.swift
    KinematicBody.swift

  World/
    TerrainSurfaceProvider.swift
    TerrainMaterialProvider.swift
    AffordanceProvider.swift
    PropCollisionProvider.swift
```

### 3.2 Flux par frame

```text
1. Lire input/gameplay intent.
2. Construire MotionRequest : vitesse, direction, action, posture, urgence.
3. Prédire trajectoire courte : 0.2 s / 0.5 s / 1.0 s.
4. Interroger le monde proche : terrain, obstacles, matériaux, humidité, affordances.
5. Choisir ou mettre à jour le clip/base pose : state machine ou motion matching.
6. Sampler animation de base.
7. Calculer contacts prédits : pieds, mains, genoux, corps.
8. Planifier pas / appuis / prises.
9. Appliquer warping root/stride/slope/orientation.
10. Résoudre IK jambes, bassin, colonne, mains, tête.
11. Appliquer physique contrôlée : balance, impulses, glissade, stumble.
12. Valider collisions : capsule, pieds, corps, penetration recovery.
13. Générer événements : footstep, dust, splash, decal, cloth reaction.
14. Envoyer pose finale au skinning/rendu.
15. Écrire debug snapshot.
```

### 3.3 Deux représentations du personnage

Le personnage doit avoir deux corps :

1. **Corps gameplay** : capsule/cylindre/capsule multi-segment, stable, simple, déterministe.
2. **Corps animation/physique fine** : pieds, mains, tibias, cuisses, bassin, torse, tête, volumes de collision secondaires.

Le corps gameplay garantit que le joueur ne traverse pas le monde. Le corps animation donne la crédibilité : pied posé au bon endroit, main qui touche une paroi, épaule qui évite un obstacle, genou qui ne traverse pas une pierre.

---

## 4. Système de perception environnementale

### 4.1 Pourquoi la perception est plus importante que l’IK

Un IK sophistiqué ne sert à rien si la cible de pied est mauvaise. La vraie qualité vient de la **perception** : connaître autour du personnage les surfaces disponibles, les risques et les affordances.

IsoMotion doit construire un `MotionEnvironmentSnapshot` autour du joueur à chaque tick animation important.

```swift
struct MotionEnvironmentSnapshot {
    let seed: UInt64
    let frameIndex: UInt64
    let rootTransform: Transform3D
    let predictedTrajectory: [TrajectorySample]
    let footContactPatches: [FootContactPatch]
    let handholds: [HandholdCandidate]
    let obstacles: [MotionObstacle]
    let slopes: [SlopeSample]
    let materials: [SurfaceMaterialSample]
    let affordances: [AnimationAffordance]
}
```

### 4.2 Requêtes nécessaires

Pour un joueur, on peut se permettre des requêtes CPU fines. Pour beaucoup de PNJ, on regroupe ou on dégrade.

Requêtes recommandées :

- raycast vertical sous chaque pied ;
- raycast vertical autour de la prochaine empreinte ;
- spherecast/capsulecast sur trajectoire du pied ;
- box sample sous la semelle ;
- requête normale/pente ;
- requête matériau ;
- requête humidité/température ;
- requête friction ;
- requête compliance / mollesse ;
- détection rebord ;
- détection obstacle bas ;
- détection trou ;
- détection marche/escalier ;
- détection prise de main ;
- détection surface verticale ;
- détection corde/échelle ;
- détection surface mouvante ;
- détection prop dynamique ;
- requête SDF locale pour rochers/racines/props proches.

### 4.3 ContactPatch

Chaque surface candidate devient une fiche utilisable par le planner :

```swift
struct ContactPatch {
    let id: UInt64
    let center: SIMD3<Float>
    let normal: SIMD3<Float>
    let tangentForward: SIMD3<Float>
    let tangentRight: SIMD3<Float>
    let area: Float
    let slopeDegrees: Float
    let roughness: Float
    let stability: Float
    let friction: Float
    let wetness: Float
    let compliance: Float
    let penetrationRisk: Float
    let edgeDistance: Float
    let material: SurfaceMaterialID
    let tags: ContactPatchTags
}
```

Tags utiles :

```text
flat, slope, steepSlope, vertical, overhang, ledge, stair, looseRock,
smallObstacle, water, mud, ice, snow, grass, gravel, sand, wood, metal,
rope, ladder, root, branch, unstable, moving, climbable, slippery,
soft, hard, noisy, silent, hot, cold, damaging, sacred, magical
```

### 4.4 Awareness de toute la géométrie proche

Pour le cas “petit rocher” :

- Le système ne doit pas seulement savoir la hauteur sous le pied.
- Il doit savoir qu’il y a un volume convexe dans l’espace de swing.
- Il doit savoir si le dessus du rocher est stable ou non.
- Il doit savoir si le pied peut passer par-dessus sans collision.
- Il doit savoir quelle zone autour est la plus naturelle.

La requête minimale est :

```text
Foot swing capsule from current foot position to predicted foot target
+ sampling grid around target
+ obstacle classification
+ patch scoring
```

Le pied choisit ensuite entre :

- poser avant le rocher ;
- poser après le rocher ;
- poser à côté ;
- poser dessus si la surface est large/stable ;
- raccourcir le pas ;
- lever le pied plus haut ;
- ralentir ;
- déclencher micro-stumble ;
- passer en franchissement si obstacle trop haut.

---

## 5. Modèle matériaux / chaussures / météo

### 5.1 Le contact ne peut pas être binaire

Un pied sur sol sec, boue, neige, sable, pierre humide ou glace ne doit pas produire la même animation. Il faut un modèle de surface combinant :

```text
surface material + wetness + temperature + slope + roughness + compliance + footwear
```

### 5.2 SurfaceMaterial

```swift
struct SurfaceMaterialProfile {
    let id: SurfaceMaterialID
    let baseFriction: Float
    let wetFrictionMultiplier: Float
    let iceFrictionMultiplier: Float
    let compliance: Float
    let sinkDepthMax: Float
    let rebound: Float
    let noiseLevel: Float
    let footstepSoundFamily: SoundFamilyID
    let decalFamily: DecalFamilyID
    let particleFamily: ParticleFamilyID
    let gaitModifier: GaitModifier
}
```

### 5.3 FootwearProfile

```swift
struct FootwearProfile {
    let id: FootwearID
    let soleLength: Float
    let soleWidth: Float
    let soleRigidity: Float
    let gripDry: Float
    let gripWet: Float
    let gripIce: Float
    let mudRetention: Float
    let snowCompaction: Float
    let noiseMultiplier: Float
    let ankleSupport: Float
    let weight: Float
}
```

Exemples :

- pieds nus ;
- sandales ;
- chaussures souples ;
- bottes cuir ;
- bottes lourdes ;
- bottes cramponnées ;
- chaussures métalliques ;
- bottes de neige ;
- patins ;
- chaussures futuristes magnétiques ;
- exosquelette ;
- pattes animales ;
- griffes ;
- sabots ;
- roues ;
- prothèses ;
- pieds mécaniques.

### 5.4 Friction effective

La friction effective doit être calculée par une règle stable :

```text
effectiveFriction = surface.baseFriction
                  * surface.wetModifier(wetness)
                  * surface.iceModifier(temperature)
                  * footwear.gripModifier(surface)
                  * slopeModifier(slope)
                  * mudContaminationModifier(footwearState)
```

Effets animation :

| Friction | Effet gameplay | Effet animation |
|---:|---|---|
| très haute | arrêt rapide | appuis nets, peu de glisse |
| haute | marche normale | stride standard |
| moyenne | prudence légère | pas un peu plus courts |
| basse | risque glissade | bassin bas, bras ouverts, foot sliding contrôlé |
| très basse | patinage/chute | micro-corrections, pertes d’équilibre |

### 5.5 Compliance / sol mou

La compliance affecte :

- hauteur du pied ;
- enfoncement de semelle ;
- délai de stabilisation ;
- amplitude verticale du bassin ;
- bruit ;
- particules ;
- trace au sol ;
- fatigue ;
- vitesse.

Exemples :

- boue : pied s’enfonce, extraction lente, son humide ;
- neige poudreuse : enfoncement large, particules, trace persistante ;
- sable sec : glisse légère, empreinte molle ;
- mousse : amortissement, bruit faible ;
- marécage : instabilité, risque d’aspiration ;
- cendres : poussière, glissement ;
- feuilles mortes : bruit, légère instabilité ;
- gravier : micro-glissements, bruit fort.

---

## 6. Footstep Planner haute qualité

### 6.1 Entrées

```swift
struct FootstepRequest {
    let characterID: EntityID
    let foot: FootSide
    let currentFootTransform: Transform3D
    let animatedFootTarget: Transform3D
    let rootVelocity: SIMD3<Float>
    let desiredVelocity: SIMD3<Float>
    let gait: GaitType
    let phase: Float
    let strideScale: Float
    let environment: MotionEnvironmentSnapshot
    let footwear: FootwearProfile
    let body: BodyProfile
}
```

### 6.2 Scoring des positions de pied

Pour chaque candidate patch :

```text
score =
  distance_to_authored_target_weight
+ slope_weight
+ stability_weight
+ friction_weight
+ edge_safety_weight
+ obstacle_clearance_weight
+ leg_extension_weight
+ pelvis_comfort_weight
+ gait_symmetry_weight
+ terrain_semantic_weight
+ style_weight
+ previous_commitment_hysteresis
```

Le système doit éviter les changements brusques. Une fois qu’un pied est engagé vers une cible, il ne change pas chaque frame sauf si collision critique.

### 6.3 Cas du petit rocher

Pseudo-algorithme :

```text
Input: predicted foot target T from animation.
1. Build swing volume V from current foot to T.
2. Query obstacles intersecting V.
3. If obstacle height < toe clearance margin:
      lift toe trajectory slightly, keep target.
4. Else classify obstacle top:
      if top area >= sole area * threshold and normal stable:
          allow stepping on top, with caution score.
      else:
          generate candidate targets around obstacle perimeter.
5. Sample terrain patches around T, before obstacle, after obstacle, left/right side.
6. Reject candidates causing knee overextension, ankle twist, edge risk.
7. Pick candidate with best naturalness/stability/friction score.
8. Warp swing arc to avoid obstacle.
9. Lock foot on contact.
10. Adjust pelvis and opposite foot if needed.
```

Résultat attendu : le pied ne “snape” pas sur le rocher. Il se pose naturellement près de lui, passe par-dessus si nécessaire, ou modifie la longueur de pas.

### 6.4 Foot locking

Une fois le pied en contact :

- verrouiller position/rotation pendant la phase d’appui ;
- autoriser micro-slip si friction faible ;
- autoriser compression si sol mou ;
- autoriser roll talon → plante → orteils ;
- garder l’erreur dans une enveloppe acceptable ;
- relâcher progressivement au toe-off.

### 6.5 Heel/toe model

Pour une animation réaliste, chaque pied doit être plus qu’un point :

```text
heel point
ball point
toe point
inner edge
outer edge
sole rectangle/convex hull
ankle joint
```

Règles :

- montée : contact avant-pied plus fréquent ;
- descente : talon/avant-pied selon pente, bassin en arrière ;
- rocher : appui partiel, ankle roll limité ;
- boue : semelle s’enfonce globalement ;
- glace : centre de pression plus prudent ;
- course : contact plus court, correction IK plus faible pour préserver énergie.

---

## 7. Locomotion Planner

### 7.1 Modes de locomotion

Les modes ne doivent pas être des états rigides. Ce sont des intentions pondérées :

```text
idle, walk, fastWalk, jog, run, sprint,
crouchWalk, stealthWalk, limp, tiredWalk,
carefulWalk, climb, scramble, vault, jump,
fall, land, slide, swim, wade, crawl,
ladder, rope, ledgeHang, wallTraverse
```

Le système choisit un mode dominant, mais peut mélanger :

- run + wetSurface = cautiousRun ;
- walk + steepSlope = uphillWalk ;
- crouch + obstacle = lowStep ;
- sprint + looseGravel = unstableSprint ;
- injured + climb = slowPainfulClimb.

### 7.2 Trajectory prediction

Pour motion matching et foot planning, il faut prédire :

- position root future à 0.2 s ;
- position root future à 0.5 s ;
- position root future à 1.0 s ;
- facing direction ;
- velocity ;
- acceleration ;
- désir de virage ;
- contraintes de collision ;
- pente moyenne ;
- affordance prochaine.

### 7.3 Support polygon

Le personnage est stable si son centre de masse projeté reste dans une zone d’appui crédible. Le système doit calculer approximativement :

- appui pied gauche ;
- appui pied droit ;
- appui main si grimpe ;
- appui genou/coude si crawl ;
- centre de masse ;
- marge de stabilité ;
- vitesse latérale ;
- pente ;
- friction.

Effets :

- si marge faible : bras s’écartent, pas raccourci ;
- si friction faible : glissade contrôlée ;
- si centre de masse dépasse : stumble ou chute ;
- si charge lourde : bassin/torse compensent.

---

## 8. Motion Matching pour IsoWorld

### 8.1 Ne pas commencer trop gros

V1 peut être : state machine + blend tree + IK.

Mais le format doit déjà préparer V2 : motion matching.

### 8.2 MotionFeatureVector

Features recommandées :

```swift
struct MotionFeatureVector {
    var rootVelocityLocal: SIMD3<Float>
    var rootAngularVelocity: Float
    var facingDirectionLocal: SIMD2<Float>
    var trajectory0_2: SIMD2<Float>
    var trajectory0_5: SIMD2<Float>
    var trajectory1_0: SIMD2<Float>
    var leftFootPosLocal: SIMD3<Float>
    var rightFootPosLocal: SIMD3<Float>
    var leftFootVelLocal: SIMD3<Float>
    var rightFootVelLocal: SIMD3<Float>
    var pelvisHeight: Float
    var phase: Float
    var gait: UInt16
    var posture: UInt16
    var terrainClass: UInt16
    var interactionTag: UInt16
}
```

### 8.3 Ajouter des features environnementales

Pour IsoWorld, il faut aller plus loin que motion matching classique :

```text
slope at root
slope under next left foot
slope under next right foot
friction class
wetness class
obstacle height ahead
step up/down delta
clearance required
terrain compliance
climb affordance nearby
water depth
```

Ainsi, le système ne choisit pas seulement un beau clip, mais un clip compatible avec la situation.

### 8.4 Indexation

Options :

- recherche brute pour prototype ;
- KD-tree / VP-tree ;
- quantization par gait/posture/tag ;
- index par phase ;
- top-k + coût de transition ;
- cache temporel ;
- learned projection plus tard.

### 8.5 Garder le contrôle gameplay

Motion matching peut devenir trop “mou” si on suit trop les clips. IsoWorld doit prioriser :

1. input joueur ;
2. collision gameplay ;
3. lisibilité ;
4. stabilité ;
5. naturalité ;
6. fidélité au clip.

---

## 9. Warping et adaptation procédurale

### 9.1 Ordre recommandé des passes

```text
Base pose sampling
→ inertialization / transition smoothing
→ root motion extraction / correction
→ trajectory warp
→ stride/orientation/slope warping
→ foot trajectory planning
→ foot locking
→ pelvis compensation
→ full body IK
→ secondary motion
→ physical reaction layer
→ final joint limits
→ skinning pose output
```

### 9.2 Motion warping

Utiliser pour :

- atteindre une marche ;
- poser la main sur une prise ;
- attraper une corde ;
- aligner une attaque ;
- franchir un obstacle ;
- s’asseoir ;
- ouvrir une porte ;
- monter sur une plateforme ;
- entrer dans une animation contextuelle.

### 9.3 Slope warping

Règles :

- limiter rotation de cheville ;
- compenser par bassin avant de tordre les pieds ;
- préserver style du clip ;
- réduire stride sur pente forte ;
- ajuster torse selon montée/descente ;
- basculer vers animation spéciale si pente trop forte.

### 9.4 Orientation warping

Utile pour :

- déplacement isométrique/orbital ;
- viser un ennemi en se déplaçant ;
- marcher latéralement ;
- regarder une falaise en longeant ;
- se préparer à interagir avec un prop ;
- locomotion animale avec tête indépendante.

### 9.5 Inertialization

À chaque changement de clip ou correction forte, appliquer une transition inertielle pour éviter :

- popping ;
- snaps de pieds ;
- rotations brusques ;
- changement d’énergie instantané ;
- cassure entre animation et input.

---

## 10. Full Body IK / contraintes corporelles

### 10.1 Solve order recommandé

```text
1. Root/pelvis gross adjustment
2. Feet effectors
3. Knee hints
4. Pelvis height/orientation refinement
5. Spine compensation
6. Hands effectors if interaction/climb
7. Shoulder/elbow hints
8. Head/look-at
9. Joint limits
10. Contact validation pass
```

### 10.2 Limites articulaires

Chaque personnage doit avoir :

- rotation min/max par joint ;
- twist max ;
- extension max ;
- compression max ;
- poids IK par joint ;
- rigidité ;
- damping ;
- préférence de pliage ;
- seuil douleur/blessure.

### 10.3 Morphologie

Le même système doit marcher pour :

- humain petit/grand ;
- enfant/adulte ;
- personnage lourd ;
- personnage maigre ;
- quadrupède ;
- oiseau ;
- insectoïde ;
- créature multi-bras ;
- robot ;
- exosquelette.

Il faut donc éviter les hypothèses “humain bipède seulement” dans le modèle bas niveau.

```swift
struct SkeletonRoleMap {
    let root: JointID
    let pelvis: JointID?
    let spine: [JointID]
    let head: JointID?
    let limbs: [LimbDescriptor]
    let effectors: [EffectorDescriptor]
}
```

---

## 11. Physique contrôlée

### 11.1 Character motor

Le motor doit gérer :

- capsule collision ;
- step-up/step-down ;
- pente max ;
- friction ;
- glissade ;
- snap-to-ground contrôlé ;
- moving platforms ;
- collision props ;
- rebonds faibles ;
- poussée par forces ;
- interaction avec l’animation root motion.

### 11.2 Animation-driven vs physics-driven

Trois modes :

| Mode | Description | Usage |
|---|---|---|
| Kinematic animation | animation dominante | locomotion normale |
| Physical assist | animation + forces correctives | glissade, impact léger, équilibre |
| Active ragdoll | physique dominante avec objectifs de pose | chute, choc, stumble fort |

### 11.3 Balance controller

Entrées :

- centre de masse ;
- support polygon ;
- vitesse ;
- friction ;
- pente ;
- contact pieds ;
- charge portée ;
- état fatigue/blessure ;
- impulsion externe.

Sorties :

- lean additive ;
- arms compensation ;
- pas de rattrapage ;
- réduction vitesse ;
- stumble ;
- chute ;
- récupération.

### 11.4 Active ragdoll léger V1

On peut commencer avec :

- ragdoll partiel haut du corps pour impacts ;
- spring bones simples pour bras/torse ;
- blend vers pose animée ;
- pas de simulateur complet par articulation pour le joueur au début.

Puis ajouter :

- contraintes articulaires physiques ;
- PD controller par joint ;
- get-up procedural ;
- hit reactions corporelles ;
- collisions membres/props.

---

## 12. Verticalité : falaises, cordes, escaliers attachés, prises

### 12.1 Concepts d’affordance

Le terrain/procedural props doivent exposer des affordances animation :

```swift
enum AnimationAffordanceKind {
    case walkable
    case stepUp
    case stepDown
    case vault
    case mantle
    case ledgeGrab
    case handhold
    case foothold
    case climbWall
    case rope
    case ladder
    case stair
    case narrowBeam
    case slideSurface
    case crawlSpace
    case swimSurface
}
```

### 12.2 Falaise grimpable

Une falaise générée procéduralement doit produire :

- surfaces verticales ;
- aspérités ;
- prises de main ;
- prises de pied ;
- zones glissantes ;
- zones friables ;
- matériau rocheux ;
- humidité ;
- difficulté ;
- danger ;
- points pour corde.

Le système animation doit utiliser ces données pour :

- choisir mode `climb` ;
- placer mains/pieds sur prises ;
- gérer reach distance ;
- gérer fatigue ;
- gérer glissement ;
- ajuster bassin près de la paroi ;
- éviter interpenetration torse/roche ;
- regarder la prochaine prise.

### 12.3 Corde

Une corde attachée à une falaise n’est pas un simple mesh. Elle doit exposer :

- spline ;
- rayon ;
- tension ;
- points d’ancrage ;
- friction main/gant ;
- balancement ;
- vitesse de descente ;
- état mouillé ;
- capacité de support ;
- style d’animation.

Animations générables :

- attraper corde ;
- monter corde ;
- descendre corde ;
- glisser contrôlé ;
- se balancer ;
- changer de main ;
- lâcher ;
- chute ;
- se stabiliser ;
- transition corde → corniche ;
- transition corniche → corde.

### 12.4 Escalier attaché à une structure verticale

Pour un escalier généré contre une falaise :

- chaque marche fournit un `stepUp` patch ;
- la rampe fournit des handholds optionnels ;
- le mur fournit des collisions latérales ;
- la hauteur/largeur influence la foulée ;
- si les marches sont irrégulières, le foot planner adapte chaque pas.

---

## 13. Liste très longue d’animations générables/procédurales

### 13.1 Locomotion bipède de base

- idle debout neutre ;
- idle respiratoire ;
- idle fatigué ;
- idle nerveux ;
- idle blessé ;
- idle froid ;
- idle chaud ;
- idle sous pluie ;
- idle en pente ;
- idle sur glace ;
- idle sur boue ;
- marche lente ;
- marche normale ;
- marche rapide ;
- jogging ;
- course ;
- sprint ;
- démarrage marche ;
- démarrage course ;
- arrêt doux ;
- arrêt brutal ;
- pivot gauche ;
- pivot droite ;
- demi-tour ;
- sidestep ;
- marche arrière ;
- marche diagonale ;
- marche accroupie ;
- course accroupie ;
- marche furtive ;
- marche prudente ;
- marche épuisée ;
- marche blessée ;
- boiterie légère ;
- boiterie forte ;
- marche avec charge ;
- marche avec arme ;
- marche avec outil ;
- marche en regardant ailleurs ;
- marche sur ligne étroite ;
- marche bras ouverts pour équilibre.

### 13.2 Variantes de pas / contacts

- pas court ;
- pas long ;
- pas hésitant ;
- pas lourd ;
- pas silencieux ;
- pas glissant ;
- pas dans boue ;
- pas dans neige ;
- pas dans eau peu profonde ;
- pas sur gravier ;
- pas sur feuilles ;
- pas sur métal ;
- pas sur bois ;
- pas sur corde/pont suspendu ;
- pas sur racine ;
- pas autour d’un caillou ;
- pas sur rocher plat ;
- pas sur rocher instable ;
- pas sur pente positive ;
- pas sur pente négative ;
- pas avec orteils levés ;
- pas talon d’abord ;
- pas avant-pied ;
- pas avec micro-glissade ;
- pas qui s’enfonce ;
- pas qui casse une brindille ;
- pas qui déclenche poussière ;
- pas qui projette eau/boue.

### 13.3 Terrain irrégulier

- monter pente douce ;
- monter pente forte ;
- descendre pente douce ;
- descendre pente forte ;
- traverser pente latérale ;
- marcher sur terrain bosselé ;
- marcher sur pierres plates ;
- marcher sur éboulis ;
- marcher dans hautes herbes ;
- marcher dans racines ;
- marcher dans champ labouré ;
- marcher dans marécage ;
- marcher sur sol volcanique ;
- marcher sur lave refroidie ;
- marcher dans cendres ;
- marcher sur dunes ;
- marcher sur sable humide ;
- marcher sur sable sec ;
- marcher dans neige poudreuse ;
- marcher sur neige dure ;
- marcher sur glace ;
- marcher sur pergélisol ;
- marcher sur corail ;
- marcher sur sol alien organique ;
- marcher sur sol mécanique instable.

### 13.4 Obstacles bas / franchissements

- lever pied au-dessus d’un caillou ;
- contourner petit rocher ;
- poser pied entre deux pierres ;
- franchir racine ;
- franchir branche ;
- franchir marche basse ;
- franchir marche haute ;
- passer un tronc ;
- enjamber barrière basse ;
- vault sur muret ;
- mantle sur rebord ;
- sauter petit trou ;
- franchir fossé étroit ;
- descendre d’une plateforme ;
- monter sur caisse ;
- passer sous branche basse ;
- se baisser sous poutre ;
- ramper sous obstacle ;
- esquiver obstacle latéral ;
- pousser végétation avec main ;
- écarter branche ;
- passer dans rideau de lianes.

### 13.5 Verticalité / escalade

- attraper rebord ;
- se suspendre ;
- se hisser ;
- grimper une paroi ;
- grimper avec prises rares ;
- grimper avec prises nombreuses ;
- grimper roche mouillée ;
- grimper roche friable ;
- grimper glace ;
- planter piolet ;
- utiliser corde ;
- monter corde ;
- descendre corde ;
- rappel contrôlé ;
- rappel rapide ;
- glisser sur corde ;
- passer corde à falaise ;
- passer falaise à corde ;
- grimper échelle ;
- descendre échelle ;
- grimper échelle cassée ;
- grimper treillis ;
- grimper arbre ;
- grimper liane ;
- traverser corniche ;
- shimmy gauche/droite ;
- changer de prise ;
- saut de prise ;
- poser pied sur petite saillie ;
- perdre prise ;
- rattrapage d’urgence ;
- chute depuis paroi ;
- réception contre paroi.

### 13.6 Sauts / chutes / réceptions

- saut vertical ;
- saut avant ;
- saut latéral ;
- saut court ;
- saut long ;
- saut avec élan ;
- saut sans élan ;
- saut par-dessus obstacle ;
- saut vers rebord ;
- saut vers corde ;
- saut vers pente ;
- réception stable ;
- réception glissante ;
- réception dans boue ;
- réception dans neige ;
- réception dans eau ;
- roulade ;
- réception lourde ;
- réception blessée ;
- perte d’équilibre ;
- stumble recovery ;
- chute avant ;
- chute arrière ;
- chute latérale ;
- chute en pente ;
- glissade après chute ;
- récupération au sol ;
- se relever rapidement ;
- se relever lentement.

### 13.7 Glissades / surfaces instables

- glisser sur boue ;
- glisser sur glace ;
- glisser sur pente herbeuse ;
- glisser sur gravier ;
- glisser sur sable ;
- descente contrôlée en dérapage ;
- perte d’appui d’un pied ;
- perte d’appui des deux pieds ;
- bras qui compensent ;
- genou qui touche sol ;
- main qui touche sol ;
- récupération in extremis ;
- chute complète ;
- glissade assise ;
- slide volontaire ;
- slide combat ;
- slide sous obstacle.

### 13.8 Nage / eau

- marcher dans flaque ;
- marcher dans eau aux chevilles ;
- marcher dans eau aux genoux ;
- patauger ;
- lutter contre courant ;
- entrer dans l’eau ;
- sortir de l’eau ;
- nager surface ;
- nager sous l’eau ;
- flotter ;
- plonger ;
- remonter ;
- grimper sur berge glissante ;
- se secouer après eau ;
- animations ralenties par vêtements mouillés ;
- glissade sur rocher humide.

### 13.9 Combat / impacts / réactions physiques

- hit reaction léger ;
- hit reaction fort ;
- recul impact ;
- torsion torse ;
- esquive ;
- blocage ;
- parade ;
- contre ;
- stagger ;
- knockback ;
- knockdown ;
- chute contre mur ;
- collision avec prop ;
- collision avec autre personnage ;
- prise de coup en courant ;
- garder équilibre après impact ;
- perdre arme ;
- tomber à genoux ;
- se protéger la tête ;
- active ragdoll partiel ;
- ragdoll complet ;
- récupération ragdoll → animation.

### 13.10 Interactions mains / outils

- atteindre objet ;
- saisir objet ;
- poser objet ;
- pousser porte ;
- tirer porte ;
- ouvrir coffre ;
- tirer levier ;
- tourner roue ;
- pousser caisse ;
- tirer caisse ;
- porter caisse ;
- poser caisse sur sol irrégulier ;
- ramasser caillou ;
- ramasser plante ;
- couper branche ;
- miner roche ;
- creuser sol ;
- construire structure ;
- attacher corde ;
- tendre corde ;
- planter piquet ;
- allumer feu ;
- utiliser lampe ;
- utiliser arme ;
- utiliser outil futuriste ;
- interaction avec console ;
- interaction avec mécanisme rouillé.

### 13.11 Social / émotion / état corporel

- regarder autour ;
- regarder obstacle ;
- regarder pied avant pas difficile ;
- regarder prise de main ;
- respirer fort ;
- frissonner ;
- transpirer ;
- grelotter ;
- tousser ;
- se tenir blessure ;
- protéger bras ;
- être effrayé ;
- être confiant ;
- être prudent ;
- être pressé ;
- être épuisé ;
- être lourdement chargé ;
- être surpris ;
- éviter du regard ;
- interaction conversationnelle en mouvement ;
- pointer direction ;
- faire signe ;
- se retourner vers bruit.

### 13.12 Animaux / créatures

- quadrupède marche ;
- quadrupède trot ;
- quadrupède galop ;
- quadrupède sur terrain rocheux ;
- animal qui saute ;
- animal qui grimpe ;
- reptile ondulant ;
- serpent sur pente ;
- oiseau au sol ;
- oiseau décollage ;
- oiseau atterrissage ;
- insecte multi-pattes ;
- araignée sur mur ;
- créature tentaculaire ;
- poisson nage ;
- animal blessé ;
- animal glissant ;
- animal qui évite obstacle ;
- animal qui pose patte sur rocher ;
- animal qui secoue eau/neige.

### 13.13 Props animés procéduralement

- corde qui se balance ;
- pont suspendu qui réagit aux pas ;
- herbes poussées par jambes ;
- branches poussées par bras ;
- lianes déplacées ;
- drap/tissu qui réagit ;
- sac à dos secondaire ;
- ceinture ;
- arme portée ;
- lampe tenue ;
- bouclier ;
- outil ;
- cape ;
- cheveux ;
- queue animale ;
- antennes ;
- tentacules ;
- mécanique à engrenages ;
- porte lourde ;
- trappe ;
- levier ;
- plateforme mouvante.

---

## 14. Variantes et règles de génération

### 14.1 Sources de variation

Chaque animation peut varier par :

- seed monde ;
- seed personnage ;
- morphologie ;
- taille ;
- poids ;
- longueur jambes/bras ;
- âge ;
- espèce ;
- posture ;
- personnalité ;
- culture/époque ;
- fatigue ;
- blessure ;
- peur ;
- compétence ;
- charge portée ;
- arme équipée ;
- outil équipé ;
- chaussures ;
- vêtements ;
- météo ;
- température ;
- humidité ;
- vent ;
- matériau de sol ;
- pente ;
- obstacles ;
- danger ;
- urgence ;
- visibilité ;
- musique/rythme éventuel ;
- état RPG.

### 14.2 AnimationVariantRecipe

```swift
struct AnimationVariantRecipe {
    let id: AnimationVariantID
    let baseMotionSet: MotionSetID
    let style: MotionStyle
    let gaitRules: [GaitRule]
    let surfaceRules: [SurfaceAnimationRule]
    let footwearRules: [FootwearAnimationRule]
    let physicsRules: [PhysicalAnimationRule]
    let proceduralNoise: ProceduralNoiseProfile
    let limits: VariantLimits
}
```

### 14.3 Exemple de règle

```yaml
rule: wet_rock_cautious_walk
when:
  material: rock
  wetnessMin: 0.55
  slopeMinDegrees: 8
  frictionMax: 0.45
actions:
  gait: cautiousWalk
  strideScale: 0.82
  footLift: +0.04
  footLockStrength: 0.72
  allowMicroSlip: true
  pelvisHeight: -0.03
  armBalanceWeight: 0.45
  maxTurnSpeed: -18%
  footstepFX: wetStone
```

### 14.4 Règles corrélées

Il ne faut pas randomiser indépendamment chaque paramètre. Exemple mauvais :

```text
grand personnage + petits pas + bras très hauts + chaussures lourdes + sprint très agile
```

Il faut des **profils corrélés** :

```text
heavy_boots_muddy_slope:
  stride shorter
  foot extraction slower
  higher pelvis damping
  louder footstep
  more mud particles
  lower turn acceleration
  higher stumble probability
```

### 14.5 Variation déterministe

Chaque décision doit dépendre de seeds stables :

```swift
let variantSeed = hash(worldSeed, characterID, motionFamilyID, surfaceID, biomeID)
```

Ne jamais utiliser un random global frame-dependent. Utiliser des streams nommés :

```text
AnimationStyleStream
FootstepMicroVariationStream
IdleGestureStream
ReactionVariationStream
ParticleVariationStream
```

---

## 15. Règles précises par surface

### 15.1 Roche sèche

- friction haute ;
- appuis nets ;
- bruits clairs ;
- faible enfoncement ;
- risque sur arêtes ;
- ankle roll limité sur aspérités.

### 15.2 Roche humide

- friction réduite ;
- pas plus courts ;
- bassin plus bas ;
- micro-glissades possibles ;
- mains plus souvent utilisées en montée ;
- son humide ;
- particules faibles.

### 15.3 Boue

- enfoncement ;
- extraction lente ;
- stride réduit ;
- pieds plus hauts en swing ;
- perte de vitesse ;
- empreintes ;
- splash boueux ;
- risque chute si pente.

### 15.4 Neige

- compression ;
- empreintes ;
- bruit amorti ;
- vitesse réduite ;
- pas plus hauts ;
- fatigue augmentée ;
- enfoncement selon poudreuse/dureté.

### 15.5 Glace

- friction très basse ;
- accélération/arrêt limités ;
- arms balance ;
- micro-sliding permanent ;
- pas courts ;
- orientation plus lente ;
- chute possible.

### 15.6 Sable

- glisse en montée ;
- enfoncement ;
- stride réduit ;
- poussière ;
- fatigue ;
- appuis moins nets.

### 15.7 Herbe / mousse

- sol doux ;
- bruit faible ;
- compression légère ;
- variation de hauteur ;
- interaction végétation.

### 15.8 Bois

- friction variable ;
- bruit creux ;
- flexion possible ;
- ponts/planches qui vibrent ;
- risque glissant si mouillé.

### 15.9 Métal

- son fort ;
- friction moyenne ;
- glissant si mouillé ;
- vibrations ;
- interaction magnétique éventuelle en monde futuriste.

### 15.10 Sol alien / magique

- compliance non naturelle ;
- forces locales ;
- rebonds ;
- viscosité ;
- adhérence variable ;
- animation stylisée ;
- effets lumineux aux contacts.

---

## 16. Collision terrain / joueur hyper fine

### 16.1 Trois niveaux de collision

1. **Navigation collision** : grossière, pour décider où le root peut aller.
2. **Character motor collision** : capsule stable, step-up, slope, slide.
3. **Animation contact collision** : pieds/mains/corps, pour qualité visuelle et physique fine.

### 16.2 TerrainContactProvider

```swift
protocol TerrainContactProvider {
    func sampleHeightAndNormal(at position: SIMD2<Float>) -> TerrainSample
    func queryContactPatches(in bounds: AABB) -> [ContactPatch]
    func raycast(_ ray: Ray3D, mask: CollisionMask) -> RaycastHit?
    func shapecast(_ shape: QueryShape, from: Transform3D, to: Transform3D) -> ShapeCastHit?
    func sampleSignedDistance(_ p: SIMD3<Float>) -> Float?
    func material(at p: SIMD3<Float>) -> SurfaceMaterialSample
    func affordances(in bounds: AABB) -> [AnimationAffordance]
}
```

### 16.3 Gérer les chunks

Le joueur est au centre d’un monde chunké. L’animation a besoin d’un périmètre de données autour du joueur :

- terrain collision du chunk courant ;
- voisinage proche ;
- props dynamiques proches ;
- SDF local des obstacles importants ;
- affordances verticales ;
- matériaux détaillés.

Il faut un `MotionCollisionCache` mis à jour autour du joueur :

```text
radius near = 2 m : haute précision, toutes requêtes
radius mid = 6 m : affordances, obstacles, trajectoire
radius far = 15 m : nav/trajectory seulement
```

### 16.4 Éviter le jitter

Règles :

- filtrage temporel des normales ;
- hysteresis sur contact patch ;
- foot target commitment ;
- snap limité par vitesse max ;
- dead zone sur micro-variations heightmap ;
- stabilité prioritaire sur précision brute ;
- les détails visuels très fins ne doivent pas faire trembler le corps.

---

## 17. Qualité AAA : critères concrets

### 17.1 Ce qu’il faut vérifier visuellement

- pas de foot sliding non voulu ;
- pas de pieds qui traversent rochers/racines ;
- pas de genou qui pop ;
- pas de bassin qui vibre ;
- pas de root qui contredit les pieds ;
- pas de torse trop rigide ;
- pas de rotation cheville impossible ;
- transitions invisibles ;
- différence claire entre sols ;
- réaction crédible aux impacts ;
- mains correctement placées en escalade ;
- regard contextuel ;
- timing des FX exactement au contact.

### 17.2 Debug views indispensables

- skeleton pose ;
- base pose vs final pose ;
- foot targets ;
- contact patches ;
- candidate foot placements ;
- selected placement score ;
- rejected placements ;
- normals ;
- friction map ;
- wetness map ;
- support polygon ;
- center of mass ;
- motion matching selected frame ;
- top-k candidates ;
- IK error ;
- collision penetration ;
- foot lock state ;
- stumble probability ;
- CPU time per pass.

### 17.3 Métriques automatiques

- erreur de pied au contact ;
- distance de glissement non voulu ;
- erreur IK moyenne/max ;
- nombre de corrections brusques ;
- variation hauteur bassin frame-to-frame ;
- ratio contact stable ;
- temps CPU animation ;
- temps collision queries ;
- nombre de requêtes par frame ;
- allocations runtime ;
- divergence déterministe entre deux runs.

---

## 18. Budget performance pour MacBook Pro M1

### 18.1 Cible joueur unique haute qualité

Pour le joueur :

```text
Animation sampling/blending: 0.1 - 0.3 ms CPU
Contact queries:             0.1 - 0.5 ms CPU
Foot planner:                0.05 - 0.2 ms CPU
IK/FBIK:                     0.1 - 0.5 ms CPU
Physics assist:              0.05 - 0.3 ms CPU
Debug off total:             ~0.5 - 1.5 ms CPU
```

Ce sont des ordres de grandeur de design, pas des mesures. Le but est d’éviter une architecture qui explose dès qu’on ajoute des PNJ.

### 18.2 PNJ

Niveaux de qualité :

| Distance | Qualité animation | Requêtes terrain | IK |
|---:|---|---|---|
| 0-5 m | complet | haute précision | full |
| 5-15 m | moyen | patch simplifié | pieds seulement |
| 15-40 m | bas | height/normal | minimal |
| >40 m | impostor/clip | aucune ou rare | non |

### 18.3 GPU / Metal

Le CPU doit gérer le joueur et quelques PNJ proches. Metal peut aider pour :

- skinning GPU ;
- calcul de matrices finales ;
- foule lointaine ;
- sampling massif de terrain pour plusieurs agents ;
- génération de debug buffers ;
- collision broadphase simplifiée ;
- animation de végétation/props ;
- requêtes parallèles sur heightfield.

Mais attention :

- les décisions gameplay doivent rester déterministes ;
- la latence GPU peut compliquer les contacts immédiats ;
- sur M1, il faut minimiser les synchronisations CPU↔GPU ;
- le joueur principal doit avoir une version CPU fiable.

---

## 19. Pipeline données

### 19.1 Import animation

Formats possibles :

- glTF pour skeleton/animation ;
- FBX offline puis conversion ;
- format interne compact ;
- clips générés procéduralement ;
- poses correctives ;
- motion tags ;
- events.

### 19.2 Préprocessing

Pour chaque clip :

- extraire root motion ;
- détecter contacts pieds/mains ;
- calculer foot velocity ;
- calculer phase ;
- calculer trajectory samples ;
- annoter gait/posture/action ;
- détecter loops ;
- compresser ;
- créer features motion matching ;
- créer événements footstep ;
- valider limites articulaires.

### 19.3 Motion tags

```yaml
clip: walk_forward_01
family: locomotion
speedRange: [1.0, 1.8]
gaits: [walk]
posture: standing
contacts:
  leftFoot: auto
  rightFoot: auto
terrainCompatibility:
  slopeMax: 15
  roughnessMax: 0.4
  waterDepthMax: 0.05
styleTags:
  - neutral
  - adult
  - unarmed
```

### 19.4 Clips procéduraux purs

Certains mouvements peuvent être générés sans mocap :

- idle respiratoire ;
- regard ;
- léger balancement ;
- antennes/tentacules ;
- queue ;
- corde ;
- robot mécanique ;
- insecte stylisé ;
- props secondaires ;
- micro tremblements ;
- aim offsets ;
- recoil simple ;
- posture fatigue.

Mais les mouvements humains complexes haute qualité doivent s’appuyer sur clips/mocap ou données bien authorées.

---

## 20. Système de règles

### 20.1 MotionRuleGraph

Un graph de règles peut transformer les paramètres monde/personnage/surface en modificateurs animation.

```text
Inputs:
  character profile
  world seed profile
  biome
  weather
  terrain material
  gameplay intent
  equipment
  current motion state

Outputs:
  gait override
  stride scale
  foot lift
  IK weights
  balance weights
  friction behavior
  stumble probability
  animation style
  FX/audio/decal events
```

### 20.2 Priorités

```text
1. sécurité collision
2. contraintes gameplay
3. contraintes physiques
4. lisibilité joueur
5. style/personnalité
6. micro-variation seedée
```

### 20.3 Exemple complet

```yaml
rule: small_rock_near_right_foot
priority: 80
when:
  obstacle.kind: smallRock
  obstacle.height: [0.08, 0.32]
  obstacle.distanceToPredictedFoot: [0.0, 0.35]
  gait: [walk, jog]
actions:
  footPlanner:
    generateSideCandidates: true
    allowStepOnTopIfStable: true
    minTopAreaSoleRatio: 0.65
    increaseSwingClearance: 0.08
    preserveAnimatedTiming: true
  ik:
    footWeight: 0.9
    pelvisCompensation: 0.35
  style:
    lookAtObstacleChance: 0.15
```

---

## 21. Intégration RPG / seed monde

Même si le document est centré animation, IsoWorld veut que la seed puisse changer les règles du monde. L’animation doit être branchée dessus.

Exemples :

- monde basse gravité : sauts plus hauts, pas plus longs, réceptions lentes ;
- monde haute gravité : posture lourde, pas courts, fatigue ;
- monde glaciaire : toutes surfaces extérieures ont risque de glisse ;
- monde organique : sol mou, rebondissant, réactions visqueuses ;
- monde mécanique : surfaces métalliques, magnétisme, vibrations ;
- monde toxique : personnage évite certains contacts ;
- monde aquatique : locomotion amphibie ;
- monde vertical : escalade fréquente, corps plus agile ;
- monde sans ennemis : animations exploration calmes ;
- monde hostile : idle vigilant, transitions rapides ;
- époque futuriste : exosquelette, pas assistés ;
- époque primitive : pieds nus/sandales, interactions manuelles ;
- monde magique : lévitation partielle, contacts lumineux.

---

## 22. Roadmap recommandée

### Phase 1 — Base robuste

- Skeleton/Pose/AnimationClip ;
- sampler ;
- blend simple ;
- root motion optionnelle ;
- character motor capsule ;
- terrain height/normal query ;
- foot IK simple ;
- footstep events ;
- debug draw.

### Phase 2 — Contact terrain fin

- ContactPatch ;
- matériaux/friction/wetness ;
- foot locking ;
- pelvis compensation ;
- small obstacle avoidance ;
- slope warping ;
- stride scaling ;
- decals/FX/audio par matériau.

### Phase 3 — Locomotion planner

- prédiction trajectoire ;
- footstep planner ;
- règles de surface ;
- stumble/glissade ;
- support polygon approximatif ;
- chaussures ;
- fatigue/charge.

### Phase 4 — Interactions verticales

- affordances rebords ;
- climb mode ;
- hand IK ;
- rope/ladder/stair affordances ;
- motion warping vers cibles ;
- ledge grab / mantle.

### Phase 5 — Motion matching

- preprocess clips ;
- feature extraction ;
- pose search brute ;
- top-k debug ;
- indexation ;
- transitions inertialisées ;
- features terrain.

### Phase 6 — Physique avancée

- active ragdoll partiel ;
- balance controller ;
- impact reactions ;
- get-up system ;
- collision membres ;
- PNJ qualité variable.

### Phase 7 — ML/learned optionnel

- learned motion matching ;
- contrôleurs spécialisés ;
- modèles de pose ;
- entraînement offline ;
- runtime compact.

---

## 23. Recommandations concrètes de design

### 23.1 Ne jamais faire dépendre le gameplay des os

Le gameplay doit dépendre du motor/capsule/contacts validés, pas de la pose finale qui peut être modifiée pour la qualité visuelle.

### 23.2 Ne jamais corriger un pied isolément sans bassin

Si un pied monte de 20 cm, le bassin doit réagir. Sinon le genou casse visuellement.

### 23.3 Ne jamais utiliser les normales brutes du terrain sans filtrage

Les normales de micro-détails créent du jitter. Il faut filtrer selon taille de semelle et gait.

### 23.4 Garder une notion d’intention d’animation

L’IK ne doit pas détruire l’animation. Une course doit rester énergique, même sur terrain irrégulier.

### 23.5 Préférer des règles lisibles aux hacks invisibles

Chaque adaptation doit pouvoir être expliquée dans le debug :

```text
stride reduced because wet rock friction = 0.38
right foot target moved 17 cm left because smallRock obstacle score
pelvis lowered 4 cm because slope lateral compensation
```

### 23.6 Préparer le futur sans l’imposer en V1

Motion matching, active ragdoll et ML peuvent arriver par étapes. Mais les données doivent être conçues dès maintenant pour les supporter.

---

## 24. Exemple de frame complète

Situation : le joueur marche sur une pente rocheuse humide, avec bottes lourdes, un petit rocher devant le pied droit.

```text
1. Input: move forward 1.6 m/s.
2. Terrain: rock, wetness 0.7, slope 12°, roughness 0.5.
3. Footwear: heavy boots, wet grip medium.
4. SurfaceResponse: effectiveFriction = 0.42.
5. MotionBrain: gait devient cautiousWalk.
6. Animation: choisit clip walk_forward_cautious ou réduit stride.
7. RightFootPlanner: détecte obstacle height 0.18 m dans swing volume.
8. Top du rocher trop petit pour semelle complète.
9. Génère candidates autour du rocher.
10. Choisit patch 14 cm à gauche, stable, normal acceptable.
11. Augmente swing clearance de 6 cm.
12. Foot lock au contact, micro-slip autorisé 1.5 cm.
13. Pelvis descend 3 cm, torse penche légèrement.
14. Bras gagnent 0.25 en balance weight.
15. FX: son wet stone, petite projection d’eau.
16. Debug: affiche score candidat et raison du déplacement.
```

Résultat : le joueur ne traverse pas le rocher, ne pose pas absurdement le pied dessus, ne patine pas comme sur glace, et l’animation reste naturelle.

---

## 25. Structure de données finale suggérée

```swift
struct MotionRequest {
    let entityID: EntityID
    let desiredVelocity: SIMD3<Float>
    let desiredFacing: SIMD3<Float>
    let action: MotionAction
    let posture: MotionPosture
    let urgency: Float
    let equipment: EquipmentState
}

struct MotionState {
    var gait: GaitType
    var phase: Float
    var currentClip: AnimationClipID?
    var rootTransform: Transform3D
    var rootVelocity: SIMD3<Float>
    var footStates: [FootState]
    var balance: BalanceState
    var physicalMode: PhysicalAnimationMode
}

struct FootState {
    var side: FootSide
    var phase: FootPhase
    var lockStrength: Float
    var currentTransform: Transform3D
    var targetTransform: Transform3D
    var contactPatchID: UInt64?
    var slipAmount: SIMD3<Float>
}

struct ProceduralAnimationOutput {
    var finalPose: Pose
    var rootDelta: TransformDelta
    var events: [AnimationEvent]
    var debug: AnimationDebugSnapshot?
}
```

---

## 26. Sources / références de recherche

Cette section liste les ressources à lire ou garder comme références pendant l’implémentation.

### Moteurs / documentation officielle

- Unreal Engine — Motion Matching / Pose Search : https://dev.epicgames.com/documentation/unreal-engine/motion-matching-in-unreal-engine
- Unreal Engine — Motion Warping : https://dev.epicgames.com/documentation/unreal-engine/motion-warping-in-unreal-engine
- Unreal Engine — Pose Warping : https://dev.epicgames.com/documentation/unreal-engine/pose-warping-in-unreal-engine
- Unreal Engine — Animation Warping plugin : https://dev.epicgames.com/documentation/unreal-engine/API/PluginIndex/AnimationWarping
- Unreal Engine — Control Rig : https://dev.epicgames.com/documentation/unreal-engine/control-rig-in-unreal-engine
- Unreal Engine — Control Rig Full Body IK : https://dev.epicgames.com/documentation/unreal-engine/control-rig-full-body-ik-in-unreal-engine
- Unity — Animation Rigging / Two Bone IK : https://docs.unity3d.com/Packages/com.unity.animation.rigging@1.1/manual/constraints/TwoBoneIKConstraint.html
- Unity — Kinematica experimental motion matching workflow : https://docs.unity3d.com/Packages/com.unity.kinematica@0.8/manual/Getting-Started.html
- Apple Metal — compute passes : https://developer.apple.com/documentation/metal/compute-passes
- Apple Metal — performing calculations on a GPU : https://developer.apple.com/documentation/Metal/performing-calculations-on-a-gpu

### Industrie / GDC / studios

- Ubisoft La Forge — Introducing Learned Motion Matching : https://www.ubisoft.com/en-us/studio/laforge/news/6xXL85Q3bF2vEj76xmnmIu/introducing-learned-motion-matching
- GDC — Motion Matching and the Road to Next-Gen Animation : https://www.gdcvault.com/play/1023280/Motion-Matching-and-The-Road
- GDC — Fitting the World: A Biomechanical Approach to Foot IK : https://www.gdcvault.com/play/1023316/Fitting-the-World-A-Biomechanical
- GDC — Motion Matching in The Last of Us Part II : https://www.gdcvault.com/play/1027118/Motion-Matching-in-The-Last
- Naughty Dog GDC 2021 resources : https://www.naughtydog.com/blog/naughty_dog_at_gdc_2021
- GDC — Environmental and Motion Matched Interactions; Madden, FIFA and Beyond : https://www.gdcvault.com/play/1027465/Animation-Summit-Environmental-and-Motion
- GDC — FIFA 22 Hypermotion / ML Flow : https://gdcvault.com/play/1027746/Animation-Summit-FIFA-22-s
- GDC — IK Rig: Procedural Pose Animation : https://gdcvault.com/play/1023279/IK-Rig-Procedural-Pose

### Recherche académique / technique

- Phase-Functioned Neural Networks for Character Control : https://dl.acm.org/doi/10.1145/3072959.3073663
- PDF PFNN : https://theorangeduck.com/media/uploads/other_stuff/phasefunction.pdf
- Learned Motion Matching : https://dl.acm.org/doi/abs/10.1145/3386569.3392440
- DeepMimic : https://arxiv.org/abs/1804.02717
- DeepMimic project/code : https://github.com/xbpeng/DeepMimic
- Environment-aware Motion Matching : https://arxiv.org/html/2510.22632v1
- Motion Matching for Character Animation and VR Avatars in Unity : https://arxiv.org/abs/2310.05215
- ProtoRes learned inverse kinematics : https://arxiv.org/abs/2106.01981
- DiffMimic differentiable physics : https://arxiv.org/abs/2304.03274

### Runtime / compression

- ozz-animation : https://guillaumeblanc.github.io/ozz-animation/
- ozz runtime animation data : https://guillaumeblanc.github.io/ozz-animation/documentation/animation_runtime/
- Animation Compression Library : https://github.com/nfrechette/acl
- Unreal ACL plugin : https://dev.epicgames.com/documentation/unreal-engine/API/PluginIndex/ACLPlugin

---

## 27. Conclusion

Pour IsoWorld, le système d’animation doit être pensé comme un **système de mouvement conscient de l’environnement**. Le terrain procédural, les props, les matériaux, la météo, les chaussures, la verticalité et la physique ne sont pas des détails ajoutés après coup : ils doivent alimenter directement les choix d’animation.

La recommandation forte :

```text
V1 : animation clips + motor + foot IK + matériaux + debug
V2 : footstep planner + contact patches + slope/stride/orientation warping
V3 : verticalité + affordances + hand IK + motion warping
V4 : motion matching environnemental
V5 : active ragdoll / physique avancée
V6 : learned motion matching / contrôleurs ML spécialisés
```

Le point le plus important est l’architecture de données. Si IsoWorld possède tôt un bon modèle `MotionEnvironmentSnapshot`, `ContactPatch`, `FootwearProfile`, `SurfaceMaterialProfile`, `MotionFeatureVector` et `AnimationVariantRecipe`, alors le moteur pourra évoluer progressivement vers un rendu d’animations très réaliste, systémique, déterministe et compatible avec un monde généré dynamiquement.
