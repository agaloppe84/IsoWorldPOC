# IsoWorld — Point 14 — Système RPG procédural, déterministe et ultra versatile

**Sujet couvert uniquement :** construire un système RPG procédural où le seed peut transformer radicalement les règles du monde, les objectifs, la présence ou non d'ennemis, les époques, les styles de progression, les factions, les mythes, les quêtes, les systèmes de jeu et les conditions de victoire.

**Contexte cible :** IsoWorld, moteur custom Swift/Metal sur MacBook Pro M1, monde déterministe généré dynamiquement par chunks autour du joueur.

**Fichier :** `procedural-deterministic-rpg-system.md`

---

## 0. Résumé de la proposition

Le point 14 ne doit pas être traité comme un simple générateur de quêtes. Il doit devenir un **générateur de règles de monde**. Le seed ne produit pas seulement une carte, des biomes et des props : il produit aussi la **constitution RPG** du monde.

L'idée centrale :

```text
WorldSeed
  -> WorldRPGDNA
  -> WorldRuleset
  -> WorldHistory
  -> Factions / Cultures / Mythes / Technologies / Ressources
  -> PlayerRole / MainGoal / ProgressionModel / ThreatModel
  -> QuestGraph / EventDeck / Storylets / Endgame
  -> Runtime Story Director
```

Dans un monde, il peut y avoir des ennemis partout, une grande guerre de factions, des dieux actifs et une quête mythique. Dans un autre, aucun ennemi classique : le jeu repose sur l'exploration, l'artisanat, la maîtrise d'un métier, la résolution d'une crise écologique ou la reconstruction d'une civilisation. Dans un troisième, les règles physiques sont étranges, le temps boucle, la technologie est interdite, les souvenirs sont une monnaie, et la victoire demande de comprendre les lois du monde.

Le système proposé repose sur cinq piliers :

1. **Déterminisme total** : chaque élément RPG est généré à partir de sous-seeds stables, indépendants des chunks chargés.
2. **Règles data-driven** : pas de logique narrative hardcodée partout ; les mondes sont définis par des règles, tags, contraintes, courbes et graphes.
3. **Hybride auteur + procédural** : les briques de qualité sont écrites/conçues à la main, mais assemblées, paramétrées et contextualisées procéduralement.
4. **Simulation légère mais expressive** : factions, rumeurs, économie, réputation, dangers et événements doivent donner l'impression d'un monde vivant sans simuler toute la planète à chaque frame.
5. **Variété radicale contrôlée** : le seed peut changer l'expérience, mais un validateur garantit jouabilité, cohérence, lisibilité et progression possible.

---

## 1. Recherche industrie et références utiles

### 1.1. Dwarf Fortress — monde simulé, histoire et systèmes imbriqués

Dwarf Fortress est une référence majeure pour IsoWorld parce qu'il ne se contente pas de générer de la géométrie : il génère un monde avec civilisations, personnalités, créatures, cultures, géologie, météo, artefacts, musiques, danses et couches historiques. Le point clé à retenir n'est pas de copier la profondeur brute, mais d'adopter une logique où le monde produit des **faits historiques et systémiques** que le gameplay peut interroger.

Leçon pour IsoWorld : générer une `WorldHistory` compacte qui devient source de :

- ruines ;
- conflits actuels ;
- reliques ;
- mythes ;
- factions ;
- matériaux rares ;
- styles architecturaux ;
- tabous culturels ;
- quêtes ;
- légendes locales ;
- noms de lieux ;
- conditions de victoire.

Dwarf Fortress montre aussi qu'une simulation très profonde peut générer de l'émergence, mais qu'elle doit rester lisible. Pour IsoWorld, on doit viser une **simulation compressée** : le joueur ne voit pas les millions de faits internes, il voit les conséquences utiles.

### 1.2. RimWorld — AI Storyteller, pacing et tension contrôlée

RimWorld est un bon modèle pour le `WorldDirector`. Le jeu se présente comme un générateur d'histoires : les événements ne sont pas seulement aléatoires, ils sont distribués par un storyteller qui module le rythme, la menace, le relâchement et l'intensité. Dans IsoWorld, il faut aller plus loin : le storyteller ne doit pas seulement envoyer des raids ou des événements, il doit être configurable par le seed.

Exemples de storytellers générés par seed :

- `BenevolentChronicler` : peu de combat, progression lente, aide indirecte.
- `MythicDoomSpiral` : prophéties, catastrophes périodiques, montée de menace.
- `RandyLikeChaos` : événements plus libres, mais avec garde-fous de jouabilité.
- `EcologicalBalanceDirector` : récompense la préservation, punit la surexploitation.
- `SilentWorldDirector` : presque pas d'intervention ; le monde est calme et contemplatif.
- `PoliticalDirector` : conflits de factions, trahisons, alliances.
- `MysteryDirector` : indices rares, secrets, énigmes systémiques.

Leçon pour IsoWorld : séparer clairement **ce qui existe dans le monde** de **ce qui est révélé / déclenché au joueur**.

### 1.3. Left 4 Dead — AI Director et population procédurale

Left 4 Dead est une référence pour le pacing adaptatif. L'AI Director crée des pics et creux de tension, distribue ennemis et ressources, et évite que le joueur apprenne par cœur des placements fixes. Pour IsoWorld, l'idée devient : le `RPGDirector` ne doit pas seulement placer des ennemis, il doit gérer :

- intensité émotionnelle ;
- densité de rencontres ;
- rareté des ressources ;
- saturation cognitive ;
- moments de respiration ;
- apparition d'opportunités ;
- crises locales ;
- conséquences de réputation ;
- escalade d'un arc narratif.

### 1.4. Wildermyth — personnages, transformation, héritage

Wildermyth montre la puissance d'un RPG génératif basé sur des héros uniques, des transformations, des choix et des conséquences. Pour IsoWorld, l'idée à retenir est la notion de **mémoire de personnage** et de **mythologie personnelle** : le joueur ne progresse pas seulement par stats, il accumule des marques, histoires, relations, cicatrices, titres, dettes et transformations.

Exemples IsoWorld :

- une brûlure de magie devient une capacité permanente ;
- une faction donne un surnom au joueur ;
- un animal sauvé devient symbole local ;
- un choix moral change les rites d'un village ;
- un échec crée une légende négative ;
- une arme réparée plusieurs fois devient un objet mythique ;
- un compagnon mort devient saint, fantôme, IA, ancêtre ou constellation selon les règles du monde.

### 1.5. Caves of Qud — mélange de contenu fixe et procédural

Caves of Qud illustre une stratégie très importante : utiliser une **colonne vertébrale fixe** pour donner de la densité et de la cohérence, puis envelopper cette colonne avec des systèmes procéduraux, des factions, des histoires, des lieux et des interactions étranges. Pour IsoWorld, il ne faut pas vouloir générer 100 % du sens à partir de rien. Il faut créer des bibliothèques riches : archétypes, motifs, templates, cultures, rites, objets, lois, quêtes, dialogues, puis générer des combinaisons.

Principe recommandé :

```text
Contenu auteur de haute qualité
  + assemblage procédural déterministe
  + contraintes de cohérence
  + validation de jouabilité
  + variations contextuelles
  = monde qui semble écrit mais rejouable
```

### 1.6. Storylets et Quality-Based Narrative

Les storylets sont des morceaux narratifs conditionnels : ils deviennent disponibles selon des qualités, états, objets, relations, lieux ou événements. Ce modèle est extrêmement adapté à IsoWorld.

Exemple :

```yaml
storylet: village_elder_warns_about_old_machine
requires:
  biome: forest_temperate OR ruins_overgrown
  world.tags: [ancient_technology, local_superstition]
  player.reputation.village >= 20
  discovered.machine_ruins == true
branches:
  - ask_about_machine
  - lie_about_findings
  - offer_repair
  - threaten_elder
consequences:
  - unlock_fact: old_machine_origin
  - change_reputation: village +5 / church -10
  - spawn_quest: repair_or_destroy_machine
```

Leçon pour IsoWorld : le RPG procédural doit être composé de **petites unités de sens**, pas uniquement de grands arcs générés d'un bloc.

### 1.7. Unreal Gameplay Ability System / StateTree / MassEntity

Unreal donne trois patterns intéressants :

- **Gameplay Ability System** : attributs, effets, capacités actives/passives, tags, tâches asynchrones. Pour IsoWorld, on peut créer un système équivalent plus simple en Swift : `Ability`, `Effect`, `AttributeSet`, `GameplayTag`, `Condition`, `Execution`.
- **StateTree** : machine d'états hiérarchique avec conditions, transitions, tâches et contexte. Très utile pour NPCs, quêtes, événements, director et comportements de factions.
- **MassEntity** : approche data-oriented pour simuler de nombreuses entités à faible coût. Pour IsoWorld, cela inspire une simulation agrégée : populations, caravanes, rumeurs, économie, migration, danger, sans update coûteux de chaque personnage.

### 1.8. Recherche récente sur PCG et génération de quêtes

Les travaux récents sur PCG montrent l'intérêt des méthodes combinées : règles, recherche, validation, machine learning et éventuellement LLMs. Pour IsoWorld, les LLMs peuvent aider en **outil offline d'authoring** ou de génération de variantes textuelles, mais le runtime déterministe ne doit pas dépendre d'un modèle distant non figé.

Approche recommandée :

- runtime déterministe : grammaires, planners, templates, règles, tags, tables, PRNG stable ;
- outil offline optionnel : LLM pour proposer des templates, noms, descriptions, variations, jamais comme source runtime non déterministe ;
- validation stricte : schémas JSON/YAML, tests, contraintes, seeds de référence.

---

## 2. Objectifs du système RPG procédural IsoWorld

Le système doit permettre au seed de changer radicalement :

- le genre RPG dominant ;
- l'époque ;
- le niveau technologique ;
- l'existence de magie ;
- le type de menace ;
- les conditions de victoire ;
- la présence ou non d'ennemis ;
- la nature des factions ;
- les ressources importantes ;
- les tabous et lois sociales ;
- le modèle de progression ;
- le rôle du joueur ;
- le niveau de violence ;
- la densité de quêtes ;
- la structure de narration ;
- les systèmes activés ;
- les interactions avec biomes, terrain, props, météo et génération de monde.

Un seed doit pouvoir produire :

- un RPG de survie hostile ;
- un RPG contemplatif sans combat ;
- un RPG politique ;
- un RPG d'artisanat ;
- un RPG de mystère archéologique ;
- un RPG post-apocalyptique ;
- un RPG de science-fiction lointaine ;
- un RPG préhistorique ;
- un RPG de guildes ;
- un RPG mythologique ;
- un RPG écologique ;
- un RPG d'enquête ;
- un RPG de colonisation ;
- un RPG de pèlerinage ;
- un RPG d'ascension spirituelle ;
- un RPG d'invention technologique ;
- un RPG de reconstruction sociale.

---

## 3. Architecture globale proposée

### 3.1. Modules principaux

```text
EngineCore
  ProceduralCore
    StableRNG
    SeedDomain
    WeightedRuleSelector
    ConstraintSolver
    DeterministicHash

  RPGCore
    WorldRPGDNA
    WorldRuleset
    EraSystem
    TechSystem
    MagicSystem
    ThreatSystem
    FactionSystem
    CultureSystem
    MythSystem
    QuestSystem
    StoryletSystem
    ObjectiveSystem
    ProgressionSystem
    ReputationSystem
    EconomySystem
    KnowledgeSystem
    DirectorSystem
    ConsequenceSystem
    WorldStateLedger
    SaveDeltaSystem

  WorldIntegration
    BiomeRPGAdapter
    TerrainRPGAdapter
    PropRPGAdapter
    WeatherRPGAdapter
    NPCSpawnAdapter
    ChunkEventAdapter
```

### 3.2. Concept central : `WorldRPGDNA`

`WorldRPGDNA` est la description compacte du monde généré à partir du seed global. Il ne stocke pas tout. Il stocke les axes qui pilotent les générateurs.

Exemple conceptuel :

```swift
struct WorldRPGDNA: Codable, Hashable {
    let seed: UInt64
    let genreBlend: GenreBlend
    let eraProfile: EraProfile
    let techProfile: TechProfile
    let magicProfile: MagicProfile
    let threatProfile: ThreatProfile
    let societyProfile: SocietyProfile
    let ecologyProfile: EcologyProfile
    let economyProfile: EconomyProfile
    let mythProfile: MythProfile
    let objectiveProfile: ObjectiveProfile
    let progressionProfile: ProgressionProfile
    let directorProfile: DirectorProfile
    let worldLawProfile: WorldLawProfile
    let toneProfile: ToneProfile
    let constraints: WorldConstraints
}
```

### 3.3. `WorldRuleset`

`WorldRuleset` transforme le DNA en règles exécutables.

Exemples :

```yaml
ruleset:
  enemies:
    enabled: false
    replacement_pressure: exploration_hazards
  death:
    model: legacy_scars
    respawn: at_last_sanctuary
  progression:
    primary: mastery_based
    secondary: knowledge_unlocks
  main_goal:
    type: restore_broken_climate_machine
  technology:
    baseline: bronze_age
    anomalies: ancient_nanotech_ruins
  magic:
    enabled: true
    source: ecological_spirits
    cost: memory_decay
  economy:
    currency: salt_and_favors
  law:
    forbidden_actions: [cut_sacred_tree, use_fire_in_dry_season]
```

### 3.4. `WorldStateLedger`

Le `WorldStateLedger` est le registre déterministe des faits importants :

- événements historiques ;
- quêtes activées ;
- décisions du joueur ;
- réputation ;
- factions rencontrées ;
- ressources découvertes ;
- objets mythiques ;
- morts importantes ;
- transformations ;
- pactes ;
- secrets connus ;
- lois violées ;
- régions modifiées.

Il doit être compact, sérialisable et compatible avec la génération chunkée. On ne sauvegarde pas tout le monde ; on sauvegarde les deltas significatifs.

---

## 4. Déterminisme : règles fondamentales

### 4.1. Domaine de seed indépendant

Chaque système doit recevoir un sous-seed stable :

```text
worldSeed
  / rpg.dna
  / rpg.history
  / rpg.factions
  / rpg.myths
  / rpg.mainGoal
  / rpg.storylets
  / rpg.localEvents.chunk(x,z)
  / rpg.npc.id
  / rpg.item.id
```

Ainsi, ajouter un nouveau biome ou charger un chunk dans un ordre différent ne doit pas changer l'histoire principale.

### 4.2. Génération stable par ID

Tous les contenus importants doivent avoir un ID dérivé du monde :

```text
FactionID = hash(worldSeed, "faction", index)
MythID    = hash(worldSeed, "myth", index)
QuestID   = hash(worldSeed, "quest", arcID, stepIndex)
NPCID     = hash(worldSeed, "npc", settlementID, role, index)
RelicID   = hash(worldSeed, "relic", mythID, index)
```

### 4.3. Éviter les cascades instables

Problème courant : si on choisit une faction en premier, puis une quête, puis un NPC, une légère modification de table change tout. Solution :

- ne jamais utiliser un flux RNG unique global ;
- utiliser des domaines de seed ;
- versionner les tables ;
- isoler les choix majeurs ;
- stocker les décisions critiques dans `WorldRPGDNA` ;
- avoir des tests de non-régression sur seeds de référence.

---

## 5. Modèle de génération en couches

### 5.1. Couche 1 — Macro-identité du monde

Le seed choisit les axes majeurs :

- genre principal ;
- tonalité ;
- époque ;
- niveau technologique ;
- magie ou non ;
- place des dieux/mythes ;
- densité sociale ;
- densité de danger ;
- objectif final ;
- modèle de progression ;
- degré de simulation ;
- niveau de merveilleux ;
- niveau d'horreur ;
- niveau de violence ;
- niveau d'absurde ;
- importance de l'économie ;
- importance des factions ;
- importance de l'écologie ;
- importance des secrets.

### 5.2. Couche 2 — Histoire du monde

Générer une histoire compacte en événements structurés :

```yaml
history_event:
  id: h_042
  age: second_age
  type: empire_collapse
  actors: [solar_dynasty, salt_monks]
  cause: water_monopoly
  consequences:
    - desertification_region:northwest
    - ruins_style:sun_bronze
    - taboo:private_wells
    - relic:mirror_of_rain
```

Types d'événements historiques :

- naissance d'une civilisation ;
- âge d'or ;
- catastrophe climatique ;
- guerre de succession ;
- invention majeure ;
- apparition d'une religion ;
- chute d'un empire ;
- trahison mythique ;
- pacte avec entité ;
- maladie ancienne ;
- migration massive ;
- extinction d'espèce ;
- effondrement technologique ;
- interdiction d'une pratique ;
- création d'un artefact ;
- construction d'un réseau de routes ;
- explosion magique ;
- fusion homme-machine ;
- invasion extra-mondaine ;
- fragmentation temporelle.

### 5.3. Couche 3 — Factions et cultures

Les factions ne doivent pas seulement être des groupes ennemis. Elles doivent porter des règles :

- économie ;
- religion ;
- langage ;
- architecture ;
- technologies ;
- métiers ;
- tabous ;
- rapport aux biomes ;
- rapport à la magie ;
- rapport aux étrangers ;
- rapport à la mort ;
- style de combat ;
- style de négociation ;
- objets symboliques ;
- rites.

### 5.4. Couche 4 — Objectif global

Le jeu ne doit pas toujours demander de “tuer le boss final”. Le seed choisit un `MainGoalModel`.

Familles :

- vaincre une menace ;
- comprendre un mystère ;
- réparer un système ;
- survivre un nombre de saisons ;
- rejoindre un lieu mythique ;
- maîtriser un métier ;
- unir des factions ;
- détruire ou sauver un artefact ;
- devenir une légende ;
- restaurer un biome ;
- s'échapper ;
- fonder une colonie ;
- transmettre un héritage ;
- atteindre l'immortalité ;
- mourir correctement ;
- briser une boucle temporelle ;
- découvrir son identité ;
- construire une machine ;
- écrire une encyclopédie du monde ;
- libérer une entité ;
- empêcher une prophétie ;
- accomplir une prophétie ;
- créer une nouvelle loi du monde.

### 5.5. Couche 5 — QuestGraph

Un `QuestGraph` combine :

- objectifs majeurs ;
- arcs secondaires ;
- quêtes locales ;
- storylets ;
- événements dynamiques ;
- conséquences ;
- secrets ;
- variantes selon rôle, faction, biome, époque.

Il doit être représenté comme un graphe de dépendances, pas comme une liste linéaire.

### 5.6. Couche 6 — Runtime Director

Le `DirectorSystem` observe :

- position joueur ;
- fatigue ;
- danger récent ;
- succès/échecs ;
- ressources ;
- progression ;
- réputation ;
- météo ;
- saison ;
- biome ;
- proximité de lieux clés ;
- densité d'événements récents ;
- objectifs actifs.

Il déclenche ou retarde :

- rencontres ;
- rumeurs ;
- visions ;
- messages ;
- événements météo ;
- attaques ;
- opportunités ;
- caravanes ;
- anomalies ;
- quêtes locales ;
- signes avant-coureurs ;
- moments de repos.

---

## 6. Axes de génération du monde RPG

### 6.1. Axe époque

- Préhistoire sauvage
- Âge de pierre avancé
- Néolithique agricole
- Âge du bronze
- Antiquité mythologique
- Empire classique
- Haut Moyen Âge
- Moyen Âge féodal
- Renaissance marchande
- Âge de la navigation
- Révolution industrielle
- Ère victorienne fantastique
- Première modernité électrique
- Années radio/diesel
- Monde contemporain rural
- Monde contemporain urbain
- Cyberpunk proche futur
- Post-cyberpunk écologique
- Colonisation spatiale précoce
- Empire interplanétaire
- Futur transhumain
- Futur post-biologique
- Futur lointain incompréhensible
- Post-apocalypse primitive
- Post-apocalypse industrielle
- Post-apocalypse techno-mystique
- Monde régressé après âge d'or
- Monde cyclique où toutes les époques se répètent
- Monde fracturé avec plusieurs époques simultanées

### 6.2. Axe technologie

- Aucune technologie manufacturée
- Outils naturels
- Pierre/os/bois
- Métallurgie primitive
- Forge avancée
- Hydraulique
- Mécanique d'horlogerie
- Poudre noire
- Vapeur
- Électricité primitive
- Radio
- Combustion
- Informatique rudimentaire
- Réseaux numériques
- Cybernétique
- Nanotechnologie
- Biotechnologie
- Intelligence artificielle
- Robotique autonome
- Réalité augmentée
- Transfert de conscience
- Manipulation gravitationnelle
- Terraforming
- Technologie extradimensionnelle
- Technologie vivante
- Technologie sacrée interdite
- Technologie incomprise héritée d'une civilisation disparue

### 6.3. Axe magie / surnaturel

- Pas de magie
- Superstitions sans effet réel
- Alchimie ambiguë
- Rituels sociaux puissants mais non surnaturels
- Magie rare et coûteuse
- Magie commune mais réglementée
- Magie écologique liée aux biomes
- Magie élémentaire
- Magie des noms
- Magie des contrats
- Magie des morts
- Magie des rêves
- Magie musicale
- Magie mathématique
- Magie de mémoire
- Magie de sacrifice
- Magie technologique
- Magie divine
- Magie parasite
- Magie instable qui corrompt la géographie
- Magie disparue mais artefacts actifs
- Magie accessible seulement par métier
- Magie accessible seulement par relation/faction
- Magie basée sur la météo
- Magie basée sur les constellations
- Magie basée sur les émotions collectives

### 6.4. Axe menace

- Aucun ennemi direct
- Faune dangereuse seulement
- Bandits rares
- Monstres mythiques
- Maladie ou contamination
- Famine
- Hiver éternel
- Désertification
- Montée des eaux
- Guerre de factions
- Invasion étrangère
- Machines hors contrôle
- Entité divine
- Culte secret
- Effondrement social
- Boucle temporelle
- Monde qui s'efface
- Prophétie auto-réalisatrice
- Ombre personnelle du joueur
- Rival généré
- Le joueur lui-même est la menace
- Menace invisible détectable seulement par indices
- Menace politique non-combattable
- Menace économique
- Menace écologique
- Menace cosmique incompréhensible

### 6.5. Axe objectif final

- Tuer un boss
- Éviter de tuer qui que ce soit
- Réparer un artefact
- Détruire un artefact
- Cartographier le monde
- Sauver un biome
- Restaurer l'eau
- Remettre le soleil en marche
- Éteindre un volcan
- Réveiller un dieu
- Endormir un dieu
- Fonder une ville
- Unir sept clans
- Survivre à dix hivers
- Maîtriser un art
- Devenir maître artisan
- Construire une machine impossible
- Ouvrir une route commerciale
- Fermer une porte dimensionnelle
- Retrouver un enfant perdu
- Retrouver sa mémoire
- Découvrir pourquoi le monde existe
- Écrire le vrai nom du monde
- Choisir le prochain âge
- Préserver l'équilibre sans victoire définitive
- Accepter la fin du monde

---

## 7. Longue liste de mondes RPG potentiels

La liste suivante sert de banque d'archétypes. Chaque archétype peut devenir un `WorldArchetypeRecipe` avec poids, contraintes, biomes favoris, règles de progression, menace, types de factions et objectifs.

### 7.1. Mondes préhistoriques / primitifs

1. **Monde des premiers feux** — le joueur doit protéger une tribu qui vient de découvrir le feu.
2. **Migration des grands troupeaux** — gameplay centré sur suivi animalier, saisons, chasse non destructive.
3. **Vallée des mégafaunes sacrées** — animaux gigantesques, rites, tabous de chasse.
4. **Âge des peintres rupestres** — progression par symboles, mémoire visuelle et cartographie sacrée.
5. **Îles de pierre noire** — outils volcaniques, navigation primitive, esprits marins.
6. **Terre sans métal** — aucune forge ; tout repose sur bois, os, cuir, pierre, fibres.
7. **Civilisation des cavernes profondes** — verticalité, grottes, clans souterrains, champignons.
8. **Monde des totems vivants** — chaque clan protège une espèce animale.
9. **Dernier printemps glaciaire** — banquise qui recule, ressources déplacées, mythes de dégel.
10. **Premiers agriculteurs** — conflit entre nomades, chasseurs, cultivateurs.
11. **Archipel des pirogues** — océan primitif, navigation stellaire, tempêtes.
12. **Monde sans langage commun** — progression par gestes, symboles, sons.

### 7.2. Mondes antiques / mythologiques

13. **Cités de bronze et de sel** — économie de l'eau, dieux fluviaux, caravanes.
14. **Empire solaire effondré** — ruines, miroirs, temples, sécheresse.
15. **Mer aux mille oracles** — îles prophétiques, navigation, choix ambigus.
16. **Royaumes de ziggourats vivantes** — temples qui poussent comme organismes.
17. **Guerre des constellations** — le ciel influence magie, agriculture, monstres.
18. **Âge des héros sans dieux** — les dieux ont disparu, leurs fonctions sont vacantes.
19. **Bibliothèque du désert** — quête de connaissance, manuscrits, tempêtes de sable.
20. **Monde des labyrinthes royaux** — architecture politique, épreuves, monstres rituels.
21. **Delta des rois-crocodiles** — hydrologie, dynasties animales, marais sacrés.
22. **Cités jumelles ennemies** — diplomatie, commerce, guerre évitable.
23. **Route d'ambre** — caravane, économie, banditisme, pactes tribaux.
24. **Île du titan endormi** — terrain vivant, séismes, culte géologique.

### 7.3. Mondes médiévaux / féodaux

25. **Royaume féodal fracturé** — seigneurs, villages, taxes, serments.
26. **Terre des chevaliers sans guerre** — honneur, tournois, quêtes non violentes.
27. **Forêt des pactes anciens** — fées, serments, frontières invisibles.
28. **Monastères du bout du monde** — savoir, calligraphie, discipline, pèlerinage.
29. **Routes hantées** — auberges, rumeurs, fantômes liés aux lieux.
30. **Montagnes des clans de forge** — minéraux, guildes, dettes de sang.
31. **Royaume sous interdit magique** — magie cachée, inquisition, dilemmes.
32. **Terre du roi absent** — personne ne sait si le souverain existe encore.
33. **Archipel des corsaires pieux** — piraterie, religion, commerce.
34. **Duchés de marais** — paludisme, passerelles, maisons sur pilotis, noblesse amphibie.
35. **Frontière des terres sauvages** — colonisation, diplomatie avec peuples locaux.
36. **Peste des rêves** — menace non physique, guérison par exploration mentale.

### 7.4. Mondes renaissance / exploration / commerce

37. **Âge des cartographes** — objectif principal : cartographier et nommer.
38. **République des guildes** — progression par métiers, brevets, monopoles.
39. **Monde des grandes foires** — économie itinérante, réputation commerciale.
40. **Îles inconnues et botanique rare** — plantes, remèdes, écologie.
41. **Compagnie maritime corrompue** — commerce, sabotage, exploration.
42. **Cités d'imprimeurs** — information, pamphlets, censure, réputation.
43. **Renaissance alchimique** — science/magie ambiguë, laboratoires, recettes.
44. **Routes célestes** — ballons, observatoires, vents, îles flottantes.
45. **Guerre froide des académies** — inventions, espionnage, savoir interdit.
46. **Monde des masques diplomatiques** — identité sociale, bals, secrets.

### 7.5. Mondes industriels / diesel / modernes

47. **Vallée des usines mortes** — pollution, machines abandonnées, syndicats.
48. **Frontière ferroviaire** — rails, villages, bandits, logistique.
49. **Ville fumante verticale** — quartiers sociaux empilés, ascenseurs, smog.
50. **Guerre des inventeurs** — brevets, automates, sabotage.
51. **Campagne électrifiée** — modernité qui transforme villages et croyances.
52. **Monde de radio et de brouillard** — communications, signaux, mystères.
53. **Après la grande panne** — infrastructures modernes sans électricité stable.
54. **Société sans nuit** — éclairage permanent, fatigue, révolte des dormeurs.
55. **République des ponts** — transport, urbanisme, corruption.
56. **Archipel pétrolier** — énergie, écologie, crime organisé.
57. **Métropole des ascenseurs sacrés** — verticalité sociale et physique.
58. **Monde de surveillance primitive** — papiers, fichiers, bureaucratie.

### 7.6. Mondes contemporains étranges

59. **Village où rien ne meurt** — immortalité locale, stagnation sociale.
60. **Ville qui change de plan chaque nuit** — navigation, mémoire, cartographie dynamique.
61. **Station de montagne isolée** — météo, relations, mystère.
62. **Région vidée par un événement inconnu** — exploration, traces, reconstruction.
63. **Monde des objets conscients** — chaque prop peut porter mémoire ou volonté.
64. **Banlieue mythologique** — dieux cachés dans quotidien moderne.
65. **Île administrative infinie** — bureaucratie surréaliste, permis, tampons.
66. **Désert de panneaux solaires** — énergie, factions techniques, chaleur.
67. **Pays sans cartes fiables** — routes mouvantes, GPS impossible.
68. **Grande réserve écologique** — conservation, braconnage, science.

### 7.7. Mondes post-apocalyptiques

69. **Après l'eau** — l'eau est monnaie, guerre des puits.
70. **Après les machines** — robots dormants, pièces rares, techno-tabous.
71. **Après les spores** — champignons géants, air toxique, symbioses.
72. **Après les océans montés** — villes noyées, bateaux, plongée.
73. **Après l'hiver nucléaire** — froid, bunkers, lumière rare.
74. **Après le soleil trop proche** — chaleur mortelle, vie nocturne.
75. **Après la mémoire** — tout le monde oublie cycliquement.
76. **Après la gravité cassée** — zones de flottement, ruines aériennes.
77. **Après la biotechnologie** — espèces hybrides, jardins dangereux.
78. **Après la guerre des dieux-machines** — reliques semi-divines.
79. **Après la fin ratée du monde** — apocalypse stoppée à moitié.
80. **Après la disparition des adultes** — sociétés d'enfants, héritages incompris.

### 7.8. Mondes fantasy avancés

81. **Monde où la magie coûte des souvenirs**.
82. **Monde où chaque sort change le climat local**.
83. **Monde où les dieux sont élus démocratiquement**.
84. **Monde où les dragons sont des institutions bancaires**.
85. **Monde où les forêts déplacent les frontières**.
86. **Monde où les noms vrais sont des armes**.
87. **Monde où les morts deviennent routes**.
88. **Monde où les montagnes sont des ancêtres**.
89. **Monde où les guildes contrôlent les éléments**.
90. **Monde sans humains** — autres espèces intelligentes seulement.
91. **Monde où chaque biome a sa loi physique**.
92. **Monde des cités dans les arbres géants**.
93. **Monde de magie judiciaire** — procès, preuves surnaturelles, contrats.
94. **Monde où le métal attire les monstres**.
95. **Monde où le mensonge crée des créatures**.
96. **Monde où les saisons sont des entités politiques**.

### 7.9. Mondes science-fiction / futur lointain

97. **Planète terraformée inachevée** — biomes instables, machines climatiques.
98. **Colonie sans Terre** — mémoire culturelle fragmentée.
99. **Monde d'IA jardinières** — robots écologiques, humains invités.
100. **Empire orbital tombé au sol** — anneaux, débris, ascenseurs cassés.
101. **Planète bibliothèque** — savoir stocké dans organismes.
102. **Monde post-humain** — corps modulaires, identités multiples.
103. **Civilisation de clones divergents** — identité, caste, mémoire.
104. **Monde de nanites sauvages** — matériaux vivants, contamination.
105. **Colonie sous dôme fissuré** — oxygène, politique, maintenance.
106. **Monde sans sol naturel** — tout est construit, recyclé, artificiel.
107. **Ruines d'une guerre interstellaire oubliée**.
108. **Monde où les étoiles communiquent**.
109. **Futur sans matière rare** — économie purement énergétique.
110. **Planète-musée d'une civilisation disparue**.
111. **Monde de simulation consciente** — règles modifiables par artefacts.
112. **Station spatiale devenue écosystème**.

### 7.10. Mondes expérimentaux / métaphysiques

113. **Monde en boucle temporelle locale**.
114. **Monde où les choix non pris existent physiquement**.
115. **Monde où les souvenirs sont des lieux visitables**.
116. **Monde où chaque mort écrit une nouvelle loi**.
117. **Monde où les émotions modifient la météo**.
118. **Monde où le joueur est une légende avant d'agir**.
119. **Monde où les cartes mentent volontairement**.
120. **Monde où les factions sont des idées, pas des peuples**.
121. **Monde où les quêtes sont des maladies narratives**.
122. **Monde où l'économie repose sur le temps de vie**.
123. **Monde où les ruines viennent du futur**.
124. **Monde où les objets rêvent les humains**.
125. **Monde où les biomes votent**.
126. **Monde où le silence est une ressource**.
127. **Monde où la victoire consiste à ne rien changer**.
128. **Monde où le joueur doit choisir quelle réalité devient canon**.

---

## 8. Longue liste de systèmes RPG implémentables

### 8.1. Systèmes de règles du monde

1. Loi de mortalité variable
2. Loi de magie variable
3. Loi de technologie autorisée/interdite
4. Loi de rareté des ressources
5. Loi de climat extrême
6. Loi de causalité étrange
7. Loi de mémoire altérée
8. Loi de réputation publique
9. Loi de tabous culturels
10. Loi de factions dominantes
11. Loi de violence permise/interdite
12. Loi de propriété privée
13. Loi d'hospitalité
14. Loi religieuse locale
15. Loi de corruption écologique
16. Loi de chance/malédiction
17. Loi de transformation corporelle
18. Loi de dette
19. Loi de serment
20. Loi de vérité/mensonge

### 8.2. Systèmes de progression

21. XP classique
22. Progression par compétences utilisées
23. Progression par métiers
24. Progression par réputation
25. Progression par connaissance
26. Progression par cartographie
27. Progression par artisanat
28. Progression par relations
29. Progression par rituels
30. Progression par artefacts
31. Progression par mutations
32. Progression par implants
33. Progression par titres sociaux
34. Progression par serments
35. Progression par lignage
36. Progression par compagnons
37. Progression par maîtrise d'un biome
38. Progression par découverte de lois du monde
39. Progression par sacrifice
40. Progression par transmission à la génération suivante

### 8.3. Systèmes de quêtes

41. Quêtes storylets
42. Quêtes planifiées par graphe de dépendances
43. Quêtes de faction
44. Quêtes de métier
45. Quêtes de biome
46. Quêtes saisonnières
47. Quêtes météo
48. Quêtes de pèlerinage
49. Quêtes de reconstruction
50. Quêtes de chasse non létale
51. Quêtes d'enquête
52. Quêtes de diplomatie
53. Quêtes commerciales
54. Quêtes d'escorte
55. Quêtes d'archéologie
56. Quêtes de rituel
57. Quêtes de réparation
58. Quêtes de sabotage
59. Quêtes de cartographie
60. Quêtes de survie
61. Quêtes sans texte, basées sur indices environnementaux
62. Quêtes générées par rumeur
63. Quêtes générées par NPC dynamique
64. Quêtes de rivalité personnelle
65. Quêtes de transmission héritage

### 8.4. Systèmes de factions

66. Réputation multi-axes
67. Diplomatie faction/faction
68. Guerre de territoires abstraite
69. Commerce inter-factions
70. Espionnage
71. Alliances temporaires
72. Trahisons
73. Vassalité
74. Guildes professionnelles
75. Ordres religieux
76. Clans familiaux
77. Cités-états
78. Corporations
79. Communes autonomes
80. Cultes secrets
81. Factions non humaines
82. Factions animales intelligentes
83. Factions machines
84. Factions biomes
85. Factions fantômes
86. Factions nomades
87. Factions pirates
88. Factions scientifiques
89. Factions anti-technologie
90. Factions écologistes extrêmes

### 8.5. Systèmes NPC / social

91. Mémoire de NPC
92. Relations entre NPCs
93. Familles générées
94. Métiers et routines
95. Besoins simples
96. Secrets personnels
97. Rumeurs
98. Humeurs
99. Peurs
100. Ambitions
101. Dettes
102. Serments
103. Mariages / alliances
104. Rivalités
105. Mentorat
106. Apprentissages
107. Deuil
108. Migration
109. Recrutement de compagnons
110. Compagnons temporaires
111. Compagnons non humains
112. Animaux liés au joueur
113. NPCs transformables par événements
114. NPCs qui deviennent légendes
115. NPCs absents mais influents par traces

### 8.6. Systèmes économie / ressources

116. Monnaie classique
117. Troc
118. Monnaie eau
119. Monnaie sel
120. Monnaie mémoire
121. Monnaie temps de vie
122. Monnaie réputation
123. Monnaie faveur
124. Ressources saisonnières
125. Ressources périssables
126. Ressources sacrées
127. Marchés dynamiques légers
128. Pénuries locales
129. Caravanes
130. Contrebande
131. Taxes
132. Inflation simple
133. Artisanat par qualité de matériaux
134. Réparation
135. Recyclage
136. Brevets / recettes
137. Routes commerciales
138. Monopoles factionnels
139. Prix influencés par météo/biome
140. Crises économiques événementielles

### 8.7. Systèmes artisanat / métiers

141. Forge
142. Cuisine
143. Herboristerie
144. Alchimie
145. Couture
146. Charpenterie
147. Maçonnerie
148. Ingénierie
149. Mécanique
150. Électronique
151. Robotique
152. Biotechnologie
153. Enchantement
154. Calligraphie magique
155. Cartographie
156. Navigation
157. Médecine
158. Chirurgie
159. Agriculture
160. Élevage
161. Apiculture
162. Brasserie
163. Poterie
164. Verrerie
165. Musique rituelle
166. Architecture
167. Construction de ponts
168. Domestication d'espèces
169. Extraction minière
170. Recherche scientifique

### 8.8. Systèmes connaissance / secrets

171. Encyclopédie générée
172. Bestiaire généré
173. Herbier généré
174. Géologie locale
175. Langues anciennes
176. Symboles
177. Cartes partielles
178. Rumeurs contradictoires
179. Indices environnementaux
180. Archéologie
181. Mythes falsifiés
182. Vérité historique cachée
183. Bibliothèques
184. Fragments audio/visuels
185. Observations astronomiques
186. Recettes secrètes
187. Lois physiques cachées
188. Secrets de faction
189. Généalogies
190. Prophéties ambiguës

### 8.9. Systèmes combat / non-combat

191. Combat classique
192. Combat rare et dangereux
193. Combat optionnel
194. Monde pacifiste
195. Menaces environnementales
196. Domptage au lieu de combat
197. Négociation au lieu de combat
198. Fuite valorisée
199. Pièges
200. Posture / intimidation
201. Désarmement
202. Blessures localisées
203. Morale ennemie
204. Hostilité dynamique
205. Ennemis qui apprennent localement
206. Boss non tuables
207. Boss sociaux
208. Boss environnementaux
209. Boss économiques
210. Boss temporels

### 8.10. Systèmes endgame

211. Boss final
212. Conseil final de factions
213. Rituel final
214. Construction finale
215. Voyage final
216. Procès final
217. Décision morale finale
218. Sacrifice final
219. Ascension
220. Exil
221. Transmission générationnelle
222. Fin ouverte
223. Plusieurs fins selon world laws
224. Monde qui continue après victoire
225. New game+ mythologique
226. Le joueur devient une faction
227. Le joueur devient une loi du monde
228. Le monde se régénère avec nouveau seed dérivé
229. Victoire par connaissance complète
230. Victoire par équilibre durable

---

## 9. Gestion des variantes

### 9.1. Variantes corrélées, pas indépendantes

Mauvais modèle : choisir époque, magie, factions, objectif et économie indépendamment.

Bon modèle : créer des corrélations.

Exemple :

```text
Si era = bronze_age
et climate = arid
et economy = water_based
alors factions probables = temple_hydraulic, caravan_clans, well_guardians
alors objectifs probables = restore_rain, break_water_monopoly, find_underground_river
alors biomes narratifs = desert, oasis, salt_flat, dry_canyon
alors props importants = cisterns, wells, aqueducts, sun_mirrors
```

### 9.2. Matrice de compatibilité

Chaque recette doit déclarer :

- tags requis ;
- tags interdits ;
- tags préférés ;
- poids de base ;
- modificateurs ;
- budget de complexité ;
- dépendances ;
- risques de contradiction.

Exemple :

```yaml
world_archetype: water_empire_collapse
requires:
  climate.any: [arid, semi_arid, seasonal_drought]
  tech.min: bronze
forbids:
  world.oceanic: dominant
boosts:
  - if economy.currency == water: +3.0
  - if magic.source == rain_spirits: +2.0
  - if terrain.has_canyons: +1.5
outputs:
  factions: [water_priests, caravan_clans, cistern_engineers]
  main_goals: [restore_rain_engine, democratize_wells, expose_sun_dynasty_lie]
```

### 9.3. Variation multi-niveau

Un même archétype doit avoir plusieurs niveaux de variation :

- variation macro : époque, genre, menace ;
- variation méso : factions, objectifs, ressources ;
- variation locale : lieux, NPCs, rumeurs ;
- variation esthétique : noms, symboles, couleurs, matériaux ;
- variation gameplay : combat, craft, survie, enquête ;
- variation narrative : dilemmes, fins, révélations.

---

## 10. Génération de quêtes : design recommandé

### 10.1. Ne pas générer seulement des tâches

Une quête procédurale ne doit pas être : “va à X, tue Y, rapporte Z”. Elle doit être un objet structuré :

```text
Quest = Motivation + Contexte + Acteurs + Lieu + Obstacle + Choix + Conséquence + Récompense + Trace dans le monde
```

### 10.2. Taxonomie de motivations

- sauver ;
- réparer ;
- comprendre ;
- retrouver ;
- escorter ;
- convaincre ;
- prouver ;
- purifier ;
- corrompre ;
- construire ;
- détruire ;
- négocier ;
- cacher ;
- révéler ;
- transmettre ;
- apprendre ;
- enseigner ;
- venger ;
- pardonner ;
- soigner ;
- cartographier ;
- mesurer ;
- infiltrer ;
- fuir ;
- survivre ;
- choisir ;
- sacrifier ;
- créer ;
- unifier ;
- diviser.

### 10.3. Templates de quêtes paramétriques

```yaml
quest_template: repair_world_system
slots:
  system: [rain_machine, lighthouse_network, memory_archive, climate_tree]
  missing_part: generated_relic_or_material
  blocker: faction_conflict_or_environmental_hazard
  moral_choice: restore_old_order_or_create_new_order
steps:
  - discover_symptom
  - identify_broken_system
  - locate_expert_or_record
  - acquire_part_or_knowledge
  - resolve_blocker
  - perform_repair
  - choose_configuration
consequences:
  - biome_change
  - faction_reaction
  - economy_shift
  - unlock_endgame_branch
```

### 10.4. Planner léger

Pour les quêtes plus complexes, utiliser un planner simple :

- état initial : faits du monde ;
- état cible : objectif ;
- actions possibles : templates ;
- contraintes : lieux, factions, ressources ;
- coût : distance, difficulté, narrativité ;
- validation : progression possible.

Le planner peut générer un graphe, puis le système sélectionne les étapes intéressantes.

---

## 11. Présence ou absence d'ennemis

### 11.1. `ThreatProfile`

```swift
struct ThreatProfile {
    let combatEnabled: Bool
    let enemyDensity: Float
    let hostilityModel: HostilityModel
    let primaryThreat: ThreatKind
    let secondaryThreats: [ThreatKind]
    let nonCombatPressure: [PressureKind]
}
```

### 11.2. Mondes sans ennemis directs

Dans ces mondes, il faut remplacer la tension par :

- météo ;
- faim ;
- fatigue ;
- isolement ;
- énigmes ;
- navigation ;
- économie ;
- diplomatie ;
- maladies ;
- temps limité ;
- catastrophes ;
- préservation écologique ;
- rareté ;
- conflits sociaux non violents ;
- obligations morales.

### 11.3. Mondes avec ennemis contextuels

Les ennemis ne doivent pas être juste des spawns :

- ils appartiennent à des biomes ;
- ils ont des raisons ;
- ils répondent aux actions du joueur ;
- ils peuvent être évités ;
- ils peuvent être négociés ;
- ils peuvent être déplacés par météo/saison ;
- ils peuvent disparaître si une cause systémique est résolue.

---

## 12. Systèmes de règles avancées par seed

### 12.1. Exemple A — Monde “quête mythique d'objet”

```yaml
main_goal: find_mythic_object
object:
  type: mirror_of_rain
  powers: [restore_rain, reveal_lies]
  cost: ages_user_when_used
world_rules:
  water_is_currency: true
  rain_is_illegal: true
  enemies: temple_guards
progression:
  main: reputation_with_caravan_clans
  secondary: archaeology
endings:
  - return_object_to_temple
  - destroy_object
  - use_object_for_people
  - hide_object_forever
```

### 12.2. Exemple B — Monde sans ennemis, maîtrise d'un domaine

```yaml
main_goal: become_master_cartographer
combat: disabled
pressure: weather, navigation, resource_management
progression:
  skills: [cartography, climbing, astronomy, survival]
quests:
  - map_fog_valley
  - chart_moving_forest
  - triangulate_mountain_signal
  - draw_true_world_map
endgame:
  type: publish_or_hide_map
```

### 12.3. Exemple C — Futur lointain post-humain

```yaml
era: far_future
tech: post_biological
magic: none
world_law: identity_is_modular
player_role: wandering_body_editor
main_goal: recover_original_self_or_transcend_it
systems:
  - body_modification
  - memory_trade
  - AI_factions
  - synthetic_ecology
  - relic_protocols
```

### 12.4. Exemple D — Monde de crise écologique

```yaml
main_goal: restore_biome_balance
threat: ecological_collapse
combat: optional
progression: knowledge, ecology, faction_trust
rules:
  overharvest_changes_biome: true
  animal_extinction_possible: true
  weather_reacts_to_player_actions: true
endings:
  - industrial_solution
  - spiritual_solution
  - hybrid_solution
  - failure_desertification
```

---

## 13. Intégration avec terrain, biomes, props, météo

### 13.1. Terrain

Le système RPG doit lire :

- altitude ;
- pente ;
- accessibilité ;
- verticalité ;
- grottes ;
- falaises ;
- rivières ;
- ressources ;
- géologie ;
- danger.

Exemples :

- un monde de pèlerinage génère des sanctuaires sur sommets ;
- un monde de guildes minières génère des conflits autour de veines rares ;
- un monde de cartographie donne de la valeur aux points de vue ;
- un monde d'exil place les objectifs au-delà de barrières naturelles.

### 13.2. Biomes

Chaque biome peut fournir :

- ressources ;
- dangers ;
- factions natives ;
- mythes locaux ;
- quêtes de restauration ;
- maladies ;
- animaux sacrés ;
- tabous ;
- matériaux de craft.

### 13.3. Props

Les props doivent devenir des objets RPG :

- un arbre peut être sacré ;
- une table peut être liée à une guilde ;
- un lampadaire peut indiquer une ancienne route ;
- un rocher peut contenir une rune ;
- un animal peut être messager ;
- une ruine peut stocker un fait historique ;
- un pont peut être territoire factionnel ;
- une plante peut être monnaie.

### 13.4. Météo

La météo doit influencer :

- événements ;
- quêtes ;
- déplacements ;
- économie ;
- magie ;
- maladies ;
- faune ;
- visibilité ;
- moral des NPCs ;
- disponibilité des ressources.

---

## 14. Runtime léger : systémique sans explosion CPU

### 14.1. Simulation agrégée

Ne pas simuler chaque habitant. Simuler des agrégats :

```text
SettlementState:
  population_bucket
  food_level
  water_level
  morale
  threat_level
  faction_control
  economy_pressure
  rumor_pool
  active_crisis
```

### 14.2. Tick basse fréquence

- micro gameplay joueur : chaque frame ;
- NPCs proches : 10-30 Hz ;
- zones locales : 1 Hz ;
- settlements proches : toutes les 10-60 s ;
- factions globales : toutes les minutes ou à événement ;
- histoire globale : seulement à triggers.

### 14.3. Événements différés

Quand une zone n'est pas chargée, on ne simule pas tout. On calcule un résumé déterministe :

```text
resolveOfflineSettlement(settlementID, elapsedWorldDays, relevantEvents)
```

---

## 15. Data model recommandé

### 15.1. `GameplayTag`

Utiliser des tags hiérarchiques :

```text
world.era.bronze
world.magic.ecological
world.threat.none
world.goal.restore
faction.type.guild
biome.desert.salt_flat
resource.water.sacred
law.taboo.fire
player.role.cartographer
quest.motivation.repair
```

### 15.2. `RuleRecipe`

```yaml
id: world_rule_memory_currency
category: economy
requires:
  world.magic.any: [memory, dream, psychic]
forbids:
  world.tone: pure_realism
outputs:
  economy.currency: memory
  systems.enable: [memory_trade, identity_risk]
  quest_tags.add: [recover_memory, sell_memory, stolen_identity]
weight: 1.0
```

### 15.3. `Storylet`

```yaml
id: storylet_stranger_knows_your_lost_name
requires:
  world.tags: [memory_currency]
  player.memory.lost_name: true
  location.type: market OR shrine
cooldown: once_per_world
choices:
  - buy_the_name
  - threaten_stranger
  - ask_who_sold_it
  - refuse_to_know
consequences:
  - unlock_fact: lost_name_owner
  - change_attribute: identity_stability
  - spawn_quest: find_memory_thief
```

### 15.4. `ObjectiveRecipe`

```yaml
id: objective_master_a_domain
requires:
  progression.primary: mastery_based
slots:
  domain: [cartography, forge, music, medicine, climbing, botany]
steps:
  - find_mentor
  - acquire_tools
  - complete_three_trials
  - create_masterwork
  - face_final_judgement
endings:
  - recognized_by_guild
  - reject_guild_and_found_school
  - disappear_into_legend
```

---

## 16. Validation de cohérence et de jouabilité

Chaque monde généré doit passer des validators :

### 16.1. Validators obligatoires

- `HasMainGoalValidator`
- `MainGoalReachableValidator`
- `ProgressionLoopExistsValidator`
- `NoContradictoryWorldLawValidator`
- `StartingAreaPlayableValidator`
- `ResourceAvailabilityValidator`
- `FactionGraphConnectedValidator`
- `QuestGraphSolvableValidator`
- `NoSoftLockValidator`
- `ChunkIndependenceValidator`
- `PerformanceBudgetValidator`

### 16.2. Exemples de contradictions à détecter

- objectif final demande magie, mais magie désactivée ;
- quête demande ennemis, mais combat désactivé sans alternative ;
- économie basée sur eau, mais monde océanique abondant sans rareté ;
- progression par réputation, mais aucune faction générée ;
- monde sans technologie, mais objectif demande ordinateur ;
- mort permanente obligatoire, mais quête critique peut tuer sans avertissement ;
- objectif dans biome inaccessible au niveau de départ ;
- faction clé hostile sans route diplomatique/combat.

### 16.3. Réparation automatique

Au lieu de rejeter trop souvent, le système peut réparer :

- ajouter une faction neutre ;
- ajouter une route alternative ;
- remplacer un objectif ;
- convertir un combat en négociation ;
- ajouter un mentor ;
- ajouter une ressource rare ;
- réduire une contrainte ;
- placer un indice supplémentaire ;
- activer un système manquant.

---

## 17. Qualité narrative : éviter le contenu générique

### 17.1. Spécificité

Une quête générée doit contenir au moins trois spécificités :

- un lieu précis ;
- un objet précis ;
- une faction précise ;
- une loi du monde ;
- une conséquence ;
- une relation ;
- un détail culturel ;
- une contrainte environnementale.

Mauvais : “Va chercher une relique dans une grotte.”

Bon : “Va chercher le miroir de pluie dans la citerne effondrée des prêtres solaires, mais ne l'expose pas au soleil avant l'équinoxe sinon l'oasis de départ s'assèche.”

### 17.2. Conséquences visibles

Chaque arc important doit changer quelque chose :

- prix ;
- météo ;
- faction ;
- dialogue ;
- architecture ;
- disponibilité d'un lieu ;
- apparence d'un biome ;
- NPC déplacés ;
- rumeurs ;
- danger ;
- musique ;
- lumière ;
- fin possible.

### 17.3. Mémoire du monde

Le monde doit se souvenir sous forme compacte :

```text
Fact: player.saved_oasis = true
Fact: sun_priests_exposed = true
Fact: caravan_clans_trust_player = 65
Fact: rain_mirror_used_count = 2
Fact: northwest_desert_recovery_stage = 1
```

---

## 18. Rôle possible du joueur

Le seed peut définir un rôle initial :

- survivant ;
- enfant du village ;
- exilé ;
- cartographe ;
- pèlerin ;
- artisan ;
- chasseur ;
- médecin ;
- messager ;
- diplomate ;
- moine ;
- apprenti mage ;
- mécanicien ;
- archéologue ;
- botaniste ;
- garde-frontière ;
- explorateur ;
- contrebandier ;
- ancien soldat ;
- amnésique ;
- clone ;
- robot ;
- esprit incarné ;
- héritier d'une dette ;
- porteur de malédiction ;
- témoin d'une prophétie ;
- gardien d'un objet ;
- dernier membre d'un ordre ;
- fondateur potentiel ;
- personne ordinaire dans un monde extraordinaire.

Chaque rôle doit changer :

- compétences de départ ;
- réputation initiale ;
- relations ;
- objectifs ;
- équipements ;
- tabous ;
- dialogues ;
- accès à factions.

---

## 19. Interaction avec progression AAA et systèmes modernes

Même si IsoWorld est custom, il est utile de s'inspirer du modèle “Ability/Effect/Tag” :

```text
Ability = action utilisable ou passive
Effect = modification temporaire/permanente
Attribute = valeur mesurable
Tag = condition sémantique
Rule = contrainte ou réaction
```

Exemples :

```yaml
ability: read_old_weather_stones
requires: [skill.cartography >= 20, world.magic.ecological]
effects:
  - reveal_weather_pattern
  - unlock_map_layer: ancient_rain_routes
```

```yaml
effect: oath_of_silence
attributes:
  speech_disabled: true
  stealth_bonus: +15
  spirit_reputation: +20
expires: when_player_breaks_oath
```

---

## 20. Debug tools indispensables

### 20.1. World DNA Inspector

Affiche :

- seed ;
- archétype ;
- époque ;
- règles ;
- menaces ;
- objectif ;
- systèmes activés ;
- factions ;
- courbes de director.

### 20.2. Quest Graph Viewer

Affiche :

- arcs ;
- dépendances ;
- lieux ;
- NPCs ;
- objets ;
- conditions ;
- softlocks potentiels.

### 20.3. Storylet Debugger

Affiche :

- storylets éligibles ;
- storylets bloqués ;
- raisons de blocage ;
- poids ;
- cooldown ;
- conséquences prévues.

### 20.4. Faction Simulator View

Affiche :

- relations ;
- objectifs ;
- ressources ;
- territoires ;
- hostilité ;
- événements récents.

### 20.5. Director Timeline

Affiche :

- tension ;
- événements passés ;
- événements candidats ;
- raisons de choix ;
- budget de danger ;
- budget narratif.

---

## 21. Roadmap d'implémentation IsoWorld

### Phase 1 — Fondations data

- `StableRNG`
- `SeedDomain`
- `GameplayTag`
- `WorldRPGDNA`
- `WorldRuleset`
- chargeur YAML/JSON interne
- validators simples
- debug print du monde généré

### Phase 2 — Génération macro

- archétypes de monde ;
- époque ;
- tech ;
- magie ;
- menace ;
- objectif global ;
- progression ;
- 20 seeds de test.

### Phase 3 — Factions et quêtes

- générateur de factions ;
- générateur d'objectifs ;
- storylets ;
- quest graph simple ;
- conséquences dans `WorldStateLedger`.

### Phase 4 — Intégration chunks

- événements locaux déterministes ;
- lieux narratifs ;
- props avec tags RPG ;
- liens biome/terrain ;
- rumeurs locales.

### Phase 5 — Director

- tension ;
- pacing ;
- sélection d'événements ;
- cooldown ;
- adaptation au joueur ;
- debug timeline.

### Phase 6 — Systèmes profonds

- économie ;
- réputation ;
- métiers ;
- connaissance ;
- mythes ;
- endgames multiples ;
- transformations joueur.

### Phase 7 — Qualité production

- outils visuels ;
- seed browser ;
- tests de non-régression ;
- benchmark CPU ;
- documentation de recettes ;
- export/import de world DNA ;
- fixtures de mondes remarquables.

---

## 22. Minimum viable system recommandé

Pour démarrer efficacement :

1. Générer `WorldRPGDNA` avec 12 axes.
2. Générer 3 factions.
3. Générer 1 objectif principal.
4. Générer 1 modèle de progression.
5. Générer 10 storylets locales.
6. Générer 5 rumeurs.
7. Générer 3 lois du monde.
8. Générer 1 ressource clé.
9. Générer 1 artefact ou savoir clé.
10. Afficher tout dans un debug panel.

Exemple de premier seed intéressant :

```text
Seed 1849203
Era: Bronze Age
Climate: Arid
Magic: Ecological rain spirits
Threat: Water monopoly, no monsters
Main Goal: Restore democratic access to underground water
Progression: Reputation + cartography + hydraulic engineering
Factions: Sun Priests, Caravan Clans, Cistern Engineers
World Laws: Rain is illegal, wells are sacred, fire magic dries soil
Endgame: choose between restoring old rain machine or decentralizing water tech
```

---

## 23. Conclusion

Le système RPG procédural d'IsoWorld doit être conçu comme un **générateur de mondes jouables**, pas comme un générateur de quêtes isolées. Le seed doit produire une constitution RPG cohérente : lois, époque, factions, menaces, objectifs, progression, économie, mythes, tabous, endgames et systèmes activés.

Le meilleur modèle est hybride :

- contenu auteur de qualité ;
- assemblage procédural déterministe ;
- règles data-driven ;
- storylets conditionnels ;
- quest graphs validés ;
- simulation agrégée légère ;
- director adaptatif ;
- forte intégration avec terrain, biomes, props et météo.

Si ce système est bien posé, IsoWorld pourra générer des expériences très différentes avec la même base moteur : parfois un RPG de combat, parfois un jeu de survie écologique, parfois une enquête archéologique, parfois une simulation de guildes, parfois un pèlerinage contemplatif, parfois une odyssée futuriste. Le point crucial est de rendre les règles du monde elles-mêmes procédurales.

---

## 24. Sources et références consultées

- IsoWorldPOC GitHub — POC Swift/macOS, génération procédurale par chunks, terrain vertical, architecture découplée : https://github.com/agaloppe84/IsoWorldPOC
- Dwarf Fortress sur Steam — description de monde simulé, civilisations, personnalités, créatures, cultures, météo, géologie, artefacts et génération profonde : https://store.steampowered.com/app/975370/Dwarf_Fortress/
- RimWorld — présentation officielle comme story generator piloté par AI storyteller : https://rimworldgame.com/
- RimWorld Wiki — détails sur AI Storytellers, événements, difficulté et facteurs comme richesse, colonistes et temps depuis événement majeur : https://rimworldwiki.com/wiki/AI_Storytellers
- Valve / Mike Booth — AI Systems of Left 4 Dead, AI Director et population procédurale : https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf
- Valve — Replayable Cooperative Game Design: Left 4 Dead, pacing et AI Director : https://cdn.akamai.steamstatic.com/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf
- Wildermyth — RPG tactique procédural centré personnages, choix, conséquences et héritage : https://wildermyth.com/
- Game Developer — Caves of Qud, mélange de contenu fixe, génération, histoire et lore procédural : https://www.gamedeveloper.com/design/tapping-into-the-potential-of-procedural-generation-in-caves-of-qud
- Failbetter Games — Storylets / Quality-Based Narrative : https://www.failbettergames.com/news/echo-bazaar-narrative-structures-part-two
- Epic Games — Gameplay Ability System : https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-ability-system-for-unreal-engine
- Epic Games — StateTree : https://dev.epicgames.com/documentation/unreal-engine/overview-of-state-tree-in-unreal-engine
- Epic Games — MassEntity : https://dev.epicgames.com/documentation/unreal-engine/mass-entity-in-unreal-engine
- Maleki & Zhao, 2024 — Procedural Content Generation in Games: A Survey with Insights on Emerging LLM Integration : https://arxiv.org/html/2410.15644v1
- Borawski et al., 2026 — From World-Gen to Quest-Line: A Dependency-Driven Prompt Pipeline for Coherent RPG Generation : https://arxiv.org/abs/2604.25482
- Breault, Ouellet & Davies, 2018 — Let CONAN tell you a story: Procedural quest generation : https://arxiv.org/abs/1808.06217
- Zamorano, Cetina & Sarro, 2023 — The Quest for Content: A Survey of Search-Based Procedural Content Generation for Video Games : https://arxiv.org/abs/2311.04710
