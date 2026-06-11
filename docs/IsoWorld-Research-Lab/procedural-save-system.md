# IsoWorld — Système de sauvegarde complet côté jeu et côté outils du moteur

**Nouveau step — Gestion de sauvegarde / persistance / versioning / projets outils**  
**Contexte cible :** moteur custom Swift/Metal sur macOS, génération procédurale déterministe par seed, monde dynamique en chunks, outils procéduraux/paramétriques intégrés, debug world, génération de worlds réels, assets et graphes éditables.

---

## 0. Résumé exécutif

Pour IsoWorld, un système de sauvegarde classique du type “dump complet de l’état mémoire” serait une mauvaise base. Le monde est déterministe, chunké, dynamique et potentiellement énorme. Il faut donc séparer très strictement :

1. **Ce qui est généré par seed** et ne doit pas être sauvegardé intégralement.
2. **Ce qui a changé depuis la génération** et doit être persisté sous forme de deltas.
3. **Ce qui appartient au joueur** : personnage, inventaire, progression, quêtes, état RPG, position, découvertes.
4. **Ce qui appartient au monde vivant** : entités persistantes, constructions, destructions, ressources exploitées, états de factions, événements historiques.
5. **Ce qui appartient aux outils** : graphes procéduraux, recettes de props, presets terrain, nodes, assets paramétriques, sessions d’édition, scènes de test.
6. **Ce qui est du cache** : meshes générés, navmesh, light probes, previews, thumbnails, artefacts GPU, qui doivent être reconstruisibles et supprimables.

La proposition centrale est un système nommé **ISPS — IsoWorld Save & Persistence System**.

ISPS repose sur une architecture hybride :

- **Fichiers manifestes lisibles** pour les métadonnées, les slots, les projets et le debug.
- **Base SQLite en mode WAL** ou format binaire journalisé pour l’état structuré volumineux, les index et les deltas.
- **Fichiers région/chunk** pour les mutations spatiales du monde.
- **Content Addressed Storage** pour les gros blobs d’assets/outils/caches.
- **Snapshots + journaux d’événements** pour combiner chargement rapide, rollback, debug, replay déterministe et robustesse.
- **Migrations explicites** pour que les anciennes sauvegardes restent ouvrables après évolution du moteur.
- **Séparation nette entre game saves, tool projects, generated caches et user preferences**.

La règle fondamentale : **on sauvegarde l’intention, l’identité, les deltas et l’histoire ; on ne sauvegarde pas ce que le moteur peut recalculer parfaitement à partir de la seed et des versions de générateurs.**

---

## 1. Objectifs du système

### 1.1 Objectifs côté jeu

Le système doit permettre :

- Charger un monde déterministe à partir d’une seed.
- Reprendre une partie exactement à l’état attendu.
- Sauvegarder les changements locaux sans écrire tout le monde.
- Persister un monde potentiellement immense.
- Gérer des slots multiples.
- Gérer autosave, quicksave, manual save, checkpoint, permadeath optionnel.
- Gérer la corruption partielle et restaurer le dernier état valide.
- Gérer les migrations entre versions moteur.
- Gérer le debug et la comparaison de seeds.
- Gérer des replays déterministes pour reproduction de bugs.
- Gérer les mondes aux règles RPG très différentes.
- Gérer les systèmes futurs : météo, personnages paramétriques, buildings, assets procéduraux, audio, UI, FX.

### 1.2 Objectifs côté outils

Le système doit permettre :

- Sauvegarder des projets outils : terrain, biomes, props, personnages, audio, FX, UI, buildings.
- Sauvegarder des graphes node-based.
- Sauvegarder des recettes procédurales et presets paramétriques.
- Sauvegarder l’état d’édition : caméras, layouts, sélections, overlays debug.
- Sauvegarder des versions et snapshots d’assets.
- Comparer deux versions d’un graphe ou d’un preset.
- Revenir en arrière localement.
- Exporter des assets vers le runtime.
- Isoler les caches rebuildables des sources authoring.
- Permettre une future collaboration ou sync cloud sans réécrire l’architecture.

### 1.3 Objectifs qualité

Le système doit être :

- **Déterministe** : même seed + mêmes versions + mêmes deltas = même monde.
- **Crash-safe** : un crash pendant l’écriture ne doit pas détruire la sauvegarde.
- **Versionné** : chaque donnée a une version de schéma et éventuellement une version de générateur.
- **Migrant** : les sauvegardes anciennes doivent pouvoir être migrées.
- **Observable** : manifestes, checksums, logs, diagnostics, outils de validation.
- **Scalable** : monde énorme, chunks nombreux, assets variés.
- **Modulaire** : chaque système déclare ses données persistantes.
- **Économe** : pas de duplication massive, caches supprimables.
- **Testable** : golden saves, hash determinism, crash injection, replay.

---

## 2. Recherche et inspirations modernes

### 2.1 Sauvegardes de jeux modernes

Les moteurs modernes séparent généralement les données sauvegardées par domaine. Unreal utilise des classes `SaveGame` personnalisées et permet plusieurs fichiers de sauvegarde ou plusieurs classes pour séparer les informations globales des données spécifiques à une partie. Cette idée est importante pour IsoWorld : il ne faut pas un unique fichier monolithique, mais des domaines et slots séparés.

Unity recommande typiquement un stockage dans un chemin persistant par application et insiste sur la séparation entre données de progression, préférences et fichiers générés. Godot distingue les cas simples, où JSON peut suffire, des cas complexes/volumineux où une sérialisation binaire devient préférable.

Pour IsoWorld, ces patterns se traduisent par :

- JSON/TOML/YAML uniquement pour manifestes, presets lisibles, petites métadonnées.
- Binaire ou SQLite pour l’état de monde volumineux.
- Domaines séparés pour profil, partie, monde, outils, caches.
- Identification explicite des objets persistants.

### 2.2 Mondes chunkés et formats région

Les mondes à chunks utilisent souvent une hiérarchie spatiale : monde → région → chunk → cellule/entité/delta. Minecraft a popularisé l’idée de fichiers région qui regroupent un ensemble de chunks, évitant d’avoir des millions de petits fichiers. Pour IsoWorld, le monde est généré autour du joueur et doit pouvoir persister des mutations locales. Une approche région/chunk est donc naturelle.

La différence importante : IsoWorld n’est pas forcément voxel. Les fichiers région ne doivent pas stocker “tout le terrain”, mais plutôt :

- Deltas terrain.
- Deltas props.
- Entités persistantes.
- Deltas de navigation.
- Traces gameplay importantes.
- Modifications environnementales.
- États locaux de simulation.

### 2.3 SQLite, WAL et transactions

SQLite est une bonne brique de persistance locale : petit, robuste, transactionnel, disponible partout, adapté à des index et tables structurées. Son mode WAL permet d’écrire dans un journal avant consolidation, ce qui améliore la robustesse et les lectures concurrentes. Pour un moteur Swift/macOS, SQLite est très intéressant pour :

- Index de chunks.
- Table d’entités persistantes.
- Slots de sauvegarde.
- Journal d’événements.
- Métadonnées de versions.
- Historique d’outils.
- Mapping asset ID → blob.

Mais SQLite ne doit pas forcément contenir les gros blobs de meshes/textures/caches. Les gros blobs peuvent rester dans un store de fichiers adressés par hash, indexé par SQLite.

### 2.4 Apple/macOS : documents, fichiers, Codable, SwiftData/Core Data

Apple fournit plusieurs niveaux :

- `FileManager` pour stocker correctement les fichiers longs dans Documents/Application Support.
- `Codable` pour encoder/décoder des types Swift vers représentations externes.
- `NSDocument` / `DocumentGroup` pour les apps document-based, utiles côté outils.
- SwiftData/Core Data pour la persistance d’objets, migrations et modèles d’app.

Recommandation IsoWorld :

- **Ne pas utiliser SwiftData comme format principal de sauvegarde runtime du monde.** Trop couplé au modèle app, moins idéal pour des fichiers de monde massifs, portables, chunkés et testables.
- **Utiliser SwiftData ou SQLite pour les métadonnées app/outils** si cela accélère le développement.
- **Utiliser `Codable` pour les petits manifests/presets/versioned structs**, pas pour écrire naïvement tout l’état du monde.
- **Utiliser une architecture document/package pour les projets outils** : `.isoproj`, `.isoasset`, `.isograph`, `.isoworld`.

### 2.5 USD, Git, Perforce, CRDT : inspirations côté outils

Les outils procéduraux auront des assets évolutifs, des graphes, des variantes et des blobs. Les inspirations utiles :

- **USD** : composition par couches, références, payloads, variantes, overrides sparsifiés.
- **Git** : objets adressés par contenu, snapshots, packfiles, delta compression.
- **Perforce** : verrouillage de fichiers binaires lourds, pertinent si les assets deviennent collaboratifs.
- **CRDT/local-first** : utile à long terme pour collaboration offline et merge automatique de certains graphes/textes/presets, mais probablement trop ambitieux pour la V1.

Recommandation : pour la V1, faire un modèle de projets outils local-first, versionné, avec snapshots et content-addressed blobs. Préparer les IDs et opérations pour une future collaboration, sans implémenter tout de suite un CRDT complet.

---

## 3. Principe clé : seed + versions + deltas

Dans IsoWorld, une sauvegarde de monde doit être composée de :

```text
WorldRuntimeState = Generate(WorldSeed, GeneratorVersions, WorldDNA) + PersistentDeltas + SimulationState + PlayerState
```

### 3.1 Ce qui vient de la génération

Ne pas sauvegarder intégralement :

- Terrain de base.
- Biomes de base.
- Props non modifiés.
- Buildings non visités/non modifiés.
- Populations non rencontrées si elles sont dérivables.
- Météo de fond si déterministe.
- Assets procéduraux si leur recette est stable.
- Matériaux procéduraux si leur `MaterialDNA` est stable.

Sauvegarder seulement :

- Seed monde.
- `WorldDNA`.
- Versions/hashes des générateurs.
- Paramètres de génération.
- Règles RPG générées.
- Overrides du joueur ou du système.

### 3.2 Ce qui doit être persisté

Persister :

- Position et état du joueur.
- Inventaire et équipement.
- Apparence du personnage si customisée.
- Progression RPG.
- Quêtes actives/terminées/échouées.
- Découvertes de carte.
- Entités rencontrées qui doivent rester cohérentes.
- Props détruits, déplacés, récoltés, transformés.
- Bâtiments construits/modifiés/détruits.
- Terrain modifié par gameplay.
- Ressources extraites.
- États de portes/coffres/containers.
- Traces permanentes ou semi-permanentes.
- Événements historiques qui ont changé le monde.
- États de factions et économies.
- Relations PNJ importantes.
- Zones visitées ou observées si leur contenu a été “figé”.

### 3.3 Versions de générateurs

Une seed ne suffit jamais. Il faut stocker :

```json
{
  "worldSeed": "A9F2-...",
  "engineVersion": "0.8.0",
  "saveSchemaVersion": 12,
  "terrainGeneratorVersion": "terrain-v4:sha256:...",
  "biomeGeneratorVersion": "biome-v3:sha256:...",
  "propGeneratorVersion": "props-v7:sha256:...",
  "rpgGeneratorVersion": "rpg-v2:sha256:...",
  "assetRecipePackVersion": "base-pack-v15:sha256:..."
}
```

Sans cela, une mise à jour du moteur peut rendre l’ancienne sauvegarde incohérente.

### 3.4 Modes de compatibilité

Trois modes possibles :

1. **Strict deterministic mode** : la sauvegarde utilise exactement les versions de générateurs d’origine. Si le moteur a changé, on garde l’ancien générateur embarqué ou on refuse le chargement.
2. **Migrated mode** : on migre les données vers les nouveaux générateurs avec des règles explicites.
3. **Regenerated mode** : on accepte que le monde change autour des deltas, utile seulement pour debug ou expérimentations.

Pour un jeu, le mode par défaut doit être **migrated**, avec fallback strict pour les saves importantes.

---

## 4. Architecture globale ISPS

### 4.1 Modules principaux

```text
ISPS
├── SaveCoordinator
├── SaveSlotManager
├── PersistenceRegistry
├── SerializationLayer
├── WorldDeltaStore
├── ChunkRegionStore
├── EntityStateStore
├── EventJournal
├── SnapshotManager
├── ToolProjectStore
├── AssetBlobStore
├── CacheStore
├── MigrationManager
├── IntegrityValidator
├── CloudSyncAdapter
└── DebugSaveInspector
```

### 4.2 SaveCoordinator

Responsabilités :

- Orchestrer les sauvegardes manuelles, autosaves, checkpoints.
- Demander à chaque système de produire un snapshot cohérent.
- Gérer les écritures atomiques.
- Gérer les jobs async.
- Éviter d’écrire pendant un état instable du moteur.
- Produire un rapport de sauvegarde.
- Gérer les erreurs et rollback.

### 4.3 PersistenceRegistry

Chaque système du moteur déclare :

- Son `systemID` stable.
- Sa version de schéma.
- Les types de données persistantes.
- Ses encodeurs/décodeurs.
- Ses règles de migration.
- Ses hooks de validation.
- Sa priorité de sauvegarde/chargement.

Exemple :

```swift
protocol PersistentSystem {
    var systemID: PersistentSystemID { get }
    var schemaVersion: Int { get }
    func captureSaveState(context: SaveCaptureContext) throws -> SystemSaveBlob
    func restoreSaveState(_ blob: SystemSaveBlob, context: LoadContext) throws
    func migrate(_ blob: SystemSaveBlob, from version: Int, to version: Int) throws -> SystemSaveBlob
    func validate(_ blob: SystemSaveBlob) -> [SaveValidationIssue]
}
```

### 4.4 Domaines de persistance

Séparer les domaines :

```text
Profile Domain
Game Slot Domain
World Domain
Chunk Delta Domain
Entity Domain
RPG Domain
Tool Project Domain
Asset Source Domain
Generated Cache Domain
Debug/Replay Domain
Settings Domain
```

Chaque domaine a son cycle de vie, sa fréquence d’écriture et son format.

---

## 5. Types de sauvegardes côté jeu

### 5.1 Profil global joueur

Contient :

- Identité joueur locale.
- Préférences de gameplay.
- Paramètres d’accessibilité.
- Config inputs.
- Langue.
- Options graphiques/audio.
- Achievements internes.
- Déblocages globaux.
- Historique de seeds utilisées.
- Liste des mondes créés.
- Dernier slot ouvert.

Ce domaine est petit, fréquent, et peut être en JSON/SQLite.

### 5.2 Save slot de monde

Contient :

- Manifest du monde.
- Seed.
- WorldDNA.
- Versions de générateurs.
- Résumé pour menu.
- Miniature/screenshot.
- Temps joué.
- Date dernière sauvegarde.
- Position approximative.
- Nom du monde.
- Mode de difficulté/règles RPG.
- Liste des fichiers région actifs.

### 5.3 Sauvegarde joueur

Contient :

- Position monde précise.
- Orientation/caméra.
- Vitesse si sauvegarde en mouvement autorisée.
- État physique.
- Santé, fatigue, faim, soif, température.
- États de blessures.
- Apparence actuelle.
- Vieillissement, morphologie, scars, amputations/prothèses.
- Inventaire.
- Équipement porté.
- Armes/outils.
- Compétences.
- Progression RPG.
- Quêtes.
- Relations.
- Historique d’événements personnels.

### 5.4 Sauvegarde monde macro

Contient :

- Temps du monde.
- Saison/date/calendrier.
- État météo macro.
- État des factions.
- Économie macro.
- État des settlements importants.
- Guerre/paix/alliances.
- Événements historiques générés ou déclenchés.
- Objectif final du monde.
- Règles RPG évolutives.

### 5.5 Sauvegarde chunks/régions

Contient, par région :

- Chunks modifiés.
- Deltas terrain.
- Deltas props.
- Entités persistantes locales.
- Ressources consommées.
- Bâtiments construits/détruits.
- Décals permanents.
- Traces longues.
- Containers.
- Loot généré et figé.
- Navmesh local modifié.
- Collision delta si nécessaire.

### 5.6 Sauvegarde entités

Entités persistantes :

- PNJ nommés.
- Animaux suivis par simulation.
- Compagnons.
- Ennemis uniques.
- Boss.
- Véhicules.
- Machines.
- Portes/coffres/pièges.
- Objets posés par joueur.
- Props transformés.
- Projectiles persistants rares.
- Drones/robots.
- Structures mobiles.

Chaque entité a un `PersistentEntityID` stable, dérivé soit :

- Du seed + emplacement + générateur + ordinal, pour entités générées.
- D’un UUID/ULID déterministe attribué lors de création gameplay.

### 5.7 Sauvegarde de replay/debug

Contient :

- Seed.
- Version moteur.
- Inputs horodatés.
- Ticks de simulation.
- Hashs périodiques d’état.
- Événements importants.
- Position caméra debug.
- Logs de génération.

Objectif : reproduire un bug sans sauvegarder toute la mémoire.

---

## 6. Types de sauvegardes côté outils

### 6.1 Projet moteur global `.isoproj`

Un projet outils contient :

```text
MyIsoWorldProject.isoproj/
├── manifest.json
├── project.db
├── assets/
├── graphs/
├── worlds/
├── presets/
├── source_blobs/
├── previews/
├── cache/
├── history/
└── diagnostics/
```

Contenu :

- Liste d’assets procéduraux.
- Graphes terrain/biomes/props/characters/audio/FX/UI/buildings.
- Presets de génération.
- Versions internes.
- Références à blobs.
- Miniatures et previews.
- Sessions de debug.
- Tests golden seeds.

### 6.2 Asset procédural `.isoasset`

Exemples :

- Arbre paramétrique.
- Rocher paramétrique.
- Bâtiment.
- Tenue personnage.
- Générateur audio de pas.
- FX de poussière.
- Module UI.

Format package :

```text
OakTreeGenerator.isoasset/
├── manifest.json
├── graph.isograph
├── parameters.json
├── variants.json
├── validation.json
├── thumbnails/
├── baked_preview/
├── source_blobs/
└── cache/
```

### 6.3 Graphe procédural `.isograph`

Contient :

- Nodes.
- Ports.
- Connexions.
- Types.
- Valeurs par défaut.
- UI positions.
- Groupes/commentaires.
- Versions de nodes.
- Validation.
- Tests intégrés.

Important : les données sémantiques du graphe doivent être séparées de l’état UI. Cela permet de versionner et comparer les graphes sans bruit visuel.

### 6.4 Preset paramétrique `.isopreset`

Contient :

- Référence au générateur.
- Paramètres exposés.
- Contraintes.
- Seed locale.
- Tags.
- Compatibilité biome/époque/thème.
- Preview.
- Notes.

### 6.5 Monde test/debug `.isotestworld`

Contient :

- Seed.
- Zone restreinte.
- Overrides de systèmes.
- Liste d’assets à tester.
- Caméras prédéfinies.
- Scénarios.
- Assertions.
- Replays.

### 6.6 Layouts et préférences outils

À stocker séparément :

- Layout panels.
- Dernier graphe ouvert.
- Zoom/pan node editor.
- Onglets.
- Filtres.
- Favoris.
- Raccourcis.
- Préférences de grille.
- Couleurs debug.

Ne jamais mélanger ces préférences avec le contenu source d’un asset.

---

## 7. Structure de fichiers recommandée

### 7.1 Racine utilisateur

Sur macOS, utiliser `Application Support` pour les données app non directement manipulées par l’utilisateur, et `Documents` pour les projets document-based que l’utilisateur gère explicitement.

```text
~/Library/Application Support/IsoWorld/
├── Profiles/
├── Saves/
├── ToolProjectsIndex/
├── GlobalCache/
├── Logs/
├── CrashReports/
└── Settings/
```

### 7.2 Save slot package

```text
Saves/
└── World_A9F2_Main.isosave/
    ├── manifest.json
    ├── summary.json
    ├── screenshot.heic
    ├── state.sqlite
    ├── state.sqlite-wal
    ├── regions/
    │   ├── r.0.0.isoregion
    │   ├── r.0.1.isoregion
    │   └── r.-1.0.isoregion
    ├── blobs/
    │   ├── ab/cd/abcdef....blob
    │   └── 91/20/9120ef....blob
    ├── journals/
    │   ├── eventlog-000001.isojournal
    │   └── eventlog-000002.isojournal
    ├── snapshots/
    │   ├── snapshot-000010.isosnap
    │   └── snapshot-000020.isosnap
    ├── migrations/
    ├── diagnostics/
    └── tmp/
```

### 7.3 Pourquoi un package plutôt qu’un fichier unique ?

Avantages :

- Écriture partielle plus rapide.
- Caches supprimables.
- Régions indépendantes.
- Meilleure récupération après corruption.
- Facilité de debug.
- Cloud sync plus granulaire.
- Possibilité d’exclure certains dossiers.

Inconvénients :

- Plus complexe qu’un fichier unique.
- Besoin d’un manifest strict.
- Besoin d’outils de réparation.

Pour IsoWorld, le package est nettement préférable.

### 7.4 Format `.isoregion`

Un fichier région peut contenir :

```text
IsoRegionFile
├── Header
│   ├── magic
│   ├── version
│   ├── regionCoord
│   ├── compression
│   ├── chunkIndexOffset
│   ├── checksum
│   └── flags
├── ChunkIndex
│   ├── chunkCoord
│   ├── offset
│   ├── size
│   ├── deltaVersion
│   ├── checksum
│   └── lastModifiedTick
└── ChunkDeltaPayloads
    ├── terrainDelta
    ├── propDelta
    ├── entityDelta
    ├── navDelta
    └── localEvents
```

### 7.5 Format blobs CAS

Chaque blob est adressé par hash :

```text
blobs/sha256Prefix/sha256Full.blob
```

Utilisé pour :

- Meshes générés optionnellement conservés.
- Previews outils.
- Thumbnails.
- Gros graphes compressés.
- Audio previews.
- Snapshots compressés.
- Caches temporaires.

Si deux assets produisent le même blob, un seul stockage.

---

## 8. Formats de sérialisation

### 8.1 JSON lisible

À utiliser pour :

- Manifestes.
- Résumés de slots.
- Petits presets.
- Paramètres outils.
- Debug exports.
- Tests golden simples.

Avantages : lisible, diffable, pratique.

Limites : volumineux, lent, pas idéal pour gros états, flottants parfois ambigus, schémas moins stricts.

### 8.2 Binary Codable custom

À utiliser pour :

- Petits blobs Swift fortement typés.
- États système peu volumineux.

Attention : ne pas dépendre naïvement de la structure Swift courante sans version explicite. Ajouter toujours :

- magic.
- schema version.
- system ID.
- endian.
- checksum.
- compression.

### 8.3 SQLite

À utiliser pour :

- Index.
- États structurés.
- Entités.
- Journaux.
- Métadonnées de monde.
- Historique outils.

Tables possibles :

```sql
save_manifest(key TEXT PRIMARY KEY, value BLOB);
world_versions(system_id TEXT PRIMARY KEY, schema_version INTEGER, generator_hash TEXT);
entities(entity_id TEXT PRIMARY KEY, type_id TEXT, region_x INTEGER, region_z INTEGER, payload BLOB);
chunks(region_x INTEGER, region_z INTEGER, chunk_x INTEGER, chunk_z INTEGER, dirty INTEGER, last_tick INTEGER, payload_ref TEXT);
events(event_id INTEGER PRIMARY KEY, tick INTEGER, type_id TEXT, payload BLOB);
asset_refs(asset_id TEXT PRIMARY KEY, hash TEXT, type_id TEXT, version INTEGER);
```

### 8.4 FlatBuffers / Cap’n Proto / Protobuf-like

Options possibles si le projet grossit :

- **FlatBuffers** : lecture sans parsing complet, utile pour runtime.
- **Cap’n Proto** : philosophie zéro-copy, mais intégration Swift à vérifier.
- **Protocol Buffers** : mature, migration de champs solide, mais moins idéal pour gros blobs graphiques.
- **Format custom** : plus de contrôle, plus de travail.

Recommandation V1 :

- JSON pour manifestes.
- SQLite pour index/états.
- Binaire custom simple pour régions.
- Ne pas introduire trop tôt un gros framework de sérialisation.

---

## 9. Sauvegarde atomique et crash safety

### 9.1 Règles fondamentales

- Ne jamais écrire directement par-dessus un fichier critique sans backup ou journal.
- Écrire dans un fichier temporaire.
- Calculer checksum.
- Flush/sync si nécessaire.
- Renommer atomiquement.
- Mettre à jour le manifest en dernier.
- Garder N versions récentes.

### 9.2 Protocole de commit de sauvegarde

```text
1. Capture stable du monde.
2. Écriture dans tmp/save-transaction-XXXX/.
3. Écriture des fichiers région modifiés.
4. Écriture des blobs nouveaux.
5. Écriture SQLite transactionnelle.
6. Validation checksums.
7. Écriture transaction_manifest.json.
8. Rename atomique vers pending/.
9. Bascule du pointeur current_save_generation.
10. Nettoyage des anciennes transactions.
```

### 9.3 Manifest de génération

```json
{
  "slotID": "world-a9f2-main",
  "currentGeneration": 42,
  "previousGeneration": 41,
  "transactionID": "tx-2026-06-11-...",
  "status": "committed",
  "checksums": {
    "state.sqlite": "sha256:...",
    "regions/r.0.0.isoregion": "sha256:..."
  }
}
```

### 9.4 Récupération après crash

Au démarrage :

1. Lire manifest principal.
2. Vérifier génération courante.
3. Si génération courante incomplète, revenir à précédente.
4. Si SQLite WAL existe, laisser SQLite rejouer.
5. Vérifier checksums critiques.
6. Marquer fichiers suspects.
7. Proposer réparation ou restauration.

### 9.5 Backups automatiques

Conserver :

- Dernière sauvegarde manuelle.
- 3 autosaves récentes.
- Dernier checkpoint stable.
- Dernière sauvegarde avant migration.
- Dernière sauvegarde avant update moteur.

---

## 10. Autosave, quicksave, manual save, checkpoint

### 10.1 Manual save

Le joueur choisit explicitement. Sauvegarde complète du slot avec screenshot et résumé.

### 10.2 Quicksave

Sauvegarde rapide dans slot dédié. Doit être bloquée dans certains états :

- Cutscene critique.
- Transition de monde.
- Combat avec contrainte design si souhaité.
- État physique instable.
- Écriture déjà en cours.

### 10.3 Autosave

Déclencheurs :

- Intervalle temps réel.
- Entrée dans nouvelle région.
- Fin de quête.
- Repos/campement.
- Changement de biome majeur.
- Avant événement dangereux.
- Après changement d’équipement important.
- Après modification outil.

### 10.4 Checkpoint

Pour gameplay :

- Points sûrs.
- Entrée de donjon/structure.
- Début/fin mission.
- Avant boss.
- Après génération d’un monde réel.

### 10.5 Sauvegarde incrémentale

Éviter de réécrire tout :

- Capturer seulement systèmes dirty.
- Écrire seulement régions modifiées.
- Journaliser les événements entre snapshots.
- Compacter périodiquement.

---

## 11. Modèle snapshots + journal d’événements

### 11.1 Pourquoi combiner les deux ?

Un snapshot charge vite mais coûte à écrire. Un journal est léger mais coûte à rejouer. La combinaison optimale :

```text
Snapshot complet périodique + journal d’événements depuis le snapshot
```

Au chargement :

```text
État = dernier snapshot valide + replay journal jusqu’au tick sauvegardé
```

### 11.2 Journal d’événements

Événements possibles :

- PlayerMovedToRegion.
- PropDestroyed.
- ResourceHarvested.
- EntitySpawnedPersistent.
- EntityKilled.
- QuestStateChanged.
- FactionRelationChanged.
- TerrainModified.
- BuildingPlaced.
- WeatherStatePinned.
- CharacterAppearanceChanged.
- ToolGraphEdited.

Chaque événement doit avoir :

```json
{
  "eventID": 128392,
  "tick": 982334,
  "systemID": "WorldDeltaSystem",
  "type": "PropDestroyed",
  "payloadVersion": 3,
  "payload": { },
  "causalParent": 128391,
  "checksumAfterOptional": "..."
}
```

### 11.3 Compaction

Périodiquement :

- Fusionner événements en deltas de chunk.
- Supprimer événements déjà inclus dans snapshot.
- Conserver un historique debug optionnel.
- Réécrire fichiers région fragmentés.

---

## 12. Gestion des chunks et deltas spatiaux

### 12.1 Dirty tracking

Chaque chunk maintient :

- `terrainDirty`.
- `propsDirty`.
- `entitiesDirty`.
- `navDirty`.
- `materialsDirty`.
- `fxPersistentDirty`.
- `lastSavedTick`.
- `lastModifiedTick`.

### 12.2 Types de deltas terrain

- Déformation hauteur.
- Creusement local.
- Remblai.
- Érosion gameplay.
- Route créée.
- Traces persistantes.
- Neige compactée longue durée.
- Boue modifiée.
- Roche cassée.
- Pont naturel effondré.
- Grotte découverte.
- Entrée de cave ouverte.

### 12.3 Types de deltas props

- Prop supprimé.
- Prop déplacé.
- Prop récolté.
- Prop cassé.
- Prop brûlé.
- Prop mouillé/gelé/sali.
- Prop transformé.
- Variante figée.
- Props construits par joueur.
- Props attachés à bâtiment.

### 12.4 Types de deltas entités

- Spawn persistant.
- Mort persistante.
- État de santé.
- Inventaire entité.
- Relation avec joueur.
- Routine actuelle.
- Position si hors simulation.
- Migration vers autre région.

### 12.5 Deltas de navigation/collision

Ne pas sauvegarder la navmesh complète si elle est reconstruisible. Sauvegarder :

- Obstacles ajoutés.
- Liens off-mesh ajoutés.
- Escaliers/cordes construits.
- Ponts détruits.
- Zones interdites.
- Volumes de danger.
- Tags de surfaces modifiés.

Puis reconstruire les artefacts.

---

## 13. Entités persistantes et identités stables

### 13.1 PersistentEntityID

Forme recommandée :

```text
PEID = namespace + origin + deterministicKey + creationCounter
```

Exemples :

```text
npc:generated:worldSeed:region:chunk:archetype:ordinal
item:crafted:playerID:tick:counter
prop:terrain:region:chunk:featureID:propOrdinal
building:userplaced:slotID:tick:counter
```

### 13.2 Stable vs ephemeral

Ne pas sauvegarder tout ce qui existe pendant une frame.

**Éphémère :**

- Particules.
- Sons actifs.
- Projectiles non critiques.
- Animations temporaires.
- Petits animaux non rencontrés.
- Props purement décoratifs non modifiés.

**Persistant :**

- Objets inventaire.
- Entités nommées.
- Ressources récoltées.
- Coffres ouverts.
- Doors/levers.
- PNJ liés à quête.
- Animaux domestiqués.
- Constructions.
- Modifications terrain.

### 13.3 Promotion d’entité

Une entité générée peut devenir persistante quand :

- Le joueur l’observe/interagit.
- Elle entre dans une quête.
- Elle reçoit un nom.
- Elle subit une modification.
- Elle transporte un objet persistant.
- Elle change de région.

---

## 14. Sauvegarde des systèmes procéduraux

### 14.1 Terrain

Sauvegarder :

- Versions générateurs terrain.
- Paramètres monde.
- Deltas terrain.
- Features validées/figées si nécessaires.
- Points d’intérêt découverts.

Ne pas sauvegarder :

- Heightmaps générées non modifiées.
- Meshes terrain cache.
- Normales/tangentes recalculables.

### 14.2 Biomes

Sauvegarder :

- `BiomeDNA`.
- Versions des règles.
- Overrides locaux.
- Biomes figés pour zones visitées si le générateur change.
- États écologiques dynamiques.

### 14.3 Props

Sauvegarder :

- Prop IDs modifiés.
- Recette + paramètres pour props créés par gameplay.
- État matériel si dynamique.
- Destruction/récolte/transformation.

### 14.4 Characters

Sauvegarder :

- `CharacterDNA`.
- Morph targets persistants.
- État âge/corps/blessures.
- Tenues/accessoires.
- Voix/audio DNA.
- Anim state minimal.
- Inventaire.

Ne pas sauvegarder :

- Pose actuelle sauf si chargement exact en cutscene.
- Buffers skinning.
- Simulation cloth en détail, sauf état simplifié.

### 14.5 RPG

Sauvegarder :

- WorldRPGDNA.
- Règles actives.
- Factions.
- Quêtes.
- Storylets consommés.
- Variables narratives.
- Objectifs finaux.
- Réputation.
- Connaissances du joueur.

### 14.6 Audio

Sauvegarder :

- Paramètres d’ambiance monde.
- Thème musical actif.
- Seed des générateurs audio si nécessaire.
- État macro de musique interactive.

Ne pas sauvegarder :

- Phases oscillateurs exactes sauf replay/debug.
- Buffers audio.

### 14.7 UI/HUD

Sauvegarder :

- Thème UI généré pour le monde.
- Préférences joueur.
- Layout custom si applicable.
- États de menus/outils.

### 14.8 Buildings/settlements

Sauvegarder :

- SettlementDNA.
- Bâtiments visités/figés.
- Deltas construction/destruction.
- Occupants persistants.
- État économique local.
- Intérieurs générés et modifiés.

---

## 15. Sauvegarde des outils procéduraux

### 15.1 Source of truth vs cache

Pour chaque outil, séparer :

```text
Source authoring : graphe, paramètres, notes, règles
Preview cache : thumbnails, mesh previews, baked test outputs
Runtime export : version compacte pour le moteur
```

### 15.2 Graphes node-based

Sauvegarder en deux couches :

```text
GraphSemanticData
├── nodes
├── ports
├── edges
├── parameters
├── types
├── subgraphs
├── exposedInputs
├── exposedOutputs
└── validationRules

GraphEditorState
├── nodePositions
├── zoom
├── pan
├── selectedNodes
├── collapsedGroups
└── inspectorTabs
```

### 15.3 Versioning local des assets

Chaque save d’asset peut créer :

- Revision ID.
- Parent revision.
- Message optionnel.
- Author local.
- Timestamp.
- Hash source.
- Hash export runtime.

Cela permet :

- Retour en arrière.
- Comparaison.
- Reproduction d’un bug asset.
- Savoir quel asset a généré une entité.

### 15.4 Diffs d’assets

Diffs possibles :

- JSON semantic diff pour presets.
- Graph diff node/edge.
- Parameter diff.
- Binary hash diff pour blobs.
- Visual diff via thumbnails/previews.

### 15.5 Verrouillage et collaboration future

Pour la V1 solo : pas de locking complexe. Mais préparer :

- `assetLockOwner` optionnel.
- `revisionID`.
- `baseRevisionID`.
- `changeSet`.
- Opérations sémantiques de graphe.

Cela prépare une future sync ou collaboration.

---

## 16. Migrations et compatibilité

### 16.1 Versionner tout

Chaque fichier doit indiquer :

- format version.
- schema version.
- engine version.
- generator version.
- asset pack version.
- compression version.

### 16.2 MigrationManager

Responsabilités :

- Détecter versions anciennes.
- Construire un plan de migration.
- Backuper avant migration.
- Migrer par étapes.
- Valider après migration.
- Produire un rapport.

### 16.3 Migrations par système

Exemple :

```swift
struct TerrainSaveMigrationV3ToV4: SaveMigrationStep {
    let sourceVersion = 3
    let targetVersion = 4

    func migrate(_ blob: SystemSaveBlob) throws -> SystemSaveBlob {
        // Convert old terrain material weights to new layered material format.
    }
}
```

### 16.4 Compatibilité générateurs

Si un générateur change :

- Option A : garder ancienne version pour saves anciennes.
- Option B : migrer les deltas.
- Option C : figer les zones visitées.
- Option D : prévenir que le monde peut changer.

Pour une bonne expérience joueur :

- Figer les zones visitées importantes.
- Migrer les deltas.
- Régénérer seulement les zones non visitées.

### 16.5 Tests de migration

Obligatoires :

- Corpus de saves anciennes.
- Golden saves par version.
- Tests automatiques de chargement.
- Hashs d’état après migration.
- Tests de downgrade interdit clair.

---

## 17. Intégrité, checksums, validation

### 17.1 Checksums

Utiliser checksums pour :

- Manifestes.
- SQLite snapshots.
- Fichiers région.
- Blobs CAS.
- Journaux.

### 17.2 Validation logique

Exemples :

- Le joueur ne doit pas être dans un chunk inexistant.
- Un item inventaire doit référencer une définition valide.
- Une quête active doit référencer des entités valides ou régénérables.
- Un bâtiment construit doit avoir un terrain support valide.
- Un PNJ mort ne doit pas être dans une faction comme leader actif sauf règle spéciale.
- Une région modifiée doit correspondre au même world seed.

### 17.3 Repair tools

Outils à prévoir :

- Rebuild indexes.
- Recompute checksums.
- Remove orphan blobs.
- Restore previous generation.
- Rebuild caches.
- Reassign missing entity references.
- Export diagnostic bundle.

---

## 18. Cloud sync et conflits

### 18.1 Principe

Ne synchroniser que :

- Saves essentielles.
- Manifestes.
- State SQLite compacté.
- Fichiers région modifiés.
- Blobs source/outils nécessaires.

Ne pas synchroniser :

- Global cache.
- Previews rebuildables.
- Logs volumineux.
- Artefacts GPU.

### 18.2 Steam Cloud

Steam Cloud peut synchroniser des fichiers de sauvegarde entre machines. Pour IsoWorld, cela implique :

- Limiter taille de save cloud.
- Exclure caches.
- Écrire des fichiers stables avant fermeture.
- Gérer conflits local/cloud.
- Éviter des millions de petits fichiers.

### 18.3 iCloud/CloudKit

Pour une version Mac/iCloud future :

- Utiliser CloudKit pour métadonnées/profils ou documents utilisateur.
- Ne pas forcer les très gros mondes complets dans CloudKit sans stratégie.
- Préférer packages compacts et snapshots.

### 18.4 Résolution de conflits

Cas : même save modifiée sur deux machines.

Stratégie recommandée :

- Ne jamais merge automatiquement deux progressions de jeu complexes.
- Afficher deux versions : locale et cloud.
- Montrer dates, durée, screenshot, position.
- Permettre duplication d’un slot.
- Pour les outils, merger certains graphes/presets plus tard via change sets.

---

## 19. Sécurité, corruption, confidentialité

### 19.1 Anti-corruption

- Checksums.
- Backups.
- Transactions.
- WAL.
- Atomic rename.
- Crash injection tests.
- Fichiers temporaires isolés.

### 19.2 Anti-tamper optionnel

Pour un jeu solo, ne pas surinvestir. Options :

- Hash manifeste.
- Signature locale optionnelle.
- Détection de modifications pour debug.
- Marquer les saves modifiées comme “custom”.

### 19.3 Confidentialité

Les saves peuvent contenir :

- Noms de joueur.
- Seeds.
- Préférences.
- Logs de machine.

Diagnostics exportés doivent pouvoir anonymiser.

---

## 20. Performance et budgets

### 20.1 Objectifs de performance

- Autosave sans freeze perceptible.
- Capture sous budget frame via snapshots async.
- Écriture sur thread dédié.
- Compression hors thread principal.
- Pas d’allocation massive pendant rendu.
- Chargement progressif.

### 20.2 Budgets indicatifs

```text
Manual save capture target: < 100 ms de pause visible, idéalement 0 pause via snapshot async
Autosave incremental target: < 10-30 ms capture amortie
Region write target: async, batché
Manifest write: immédiat, atomique
Load menu summary: < 100 ms
Load playable world: dépend génération, avec phases de progress
```

### 20.3 Compression

Options :

- LZ4 pour vitesse.
- Zstandard pour bon ratio si disponible/intégrable.
- No compression pour petits blobs.
- Compression par chunk payload.

### 20.4 Batching

Écrire par batch :

- Regrouper chunks dirty par région.
- Regrouper blobs nouveaux.
- Éviter petites écritures répétées.
- Déclencher compaction quand fragmentation dépasse seuil.

---

## 21. Chargement progressif

### 21.1 Phases de load

```text
1. Read save manifest
2. Validate versions
3. Run migrations if needed
4. Load profile/player state
5. Init WorldDNA and generators
6. Load macro world/RPG state
7. Load region around player
8. Apply chunk deltas
9. Rebuild required caches near player
10. Spawn persistent entities
11. Warm renderer/audio/UI
12. Enter playable world
```

### 21.2 Loading bar

Chaque système expose :

- Nom phase.
- Progression 0..1.
- Poids estimé.
- Sous-tâche actuelle.
- Erreur récupérable.

### 21.3 Chargement autour du joueur

Ne pas charger tout le monde :

- Charger région courante + voisinage immédiat.
- Charger macro state global.
- Charger entités critiques globales.
- Streamer le reste.

---

## 22. API Swift proposée

### 22.1 SaveSlot

```swift
struct SaveSlotID: Hashable, Codable {
    let rawValue: String
}

struct SaveSlotSummary: Codable {
    let slotID: SaveSlotID
    let displayName: String
    let worldSeed: String
    let worldName: String
    let lastSavedAt: Date
    let playTimeSeconds: Double
    let engineVersion: String
    let saveSchemaVersion: Int
    let screenshotRelativePath: String?
    let playerRegion: SIMD2<Int32>
    let worldDescription: String
}
```

### 22.2 SaveCoordinator

```swift
actor SaveCoordinator {
    let registry: PersistenceRegistry
    let slotManager: SaveSlotManager
    let migrationManager: MigrationManager

    func createWorldSave(seed: WorldSeed, config: WorldCreationConfig) async throws -> SaveSlotID
    func save(slotID: SaveSlotID, reason: SaveReason) async throws -> SaveReport
    func load(slotID: SaveSlotID) async throws -> LoadedWorldSession
    func autosave(activeSession: WorldSession) async
    func validate(slotID: SaveSlotID) async throws -> SaveValidationReport
}
```

### 22.3 Persistent state capture

```swift
struct SaveCaptureContext {
    let slotID: SaveSlotID
    let worldSeed: WorldSeed
    let tick: UInt64
    let reason: SaveReason
    let dirtyRegions: [RegionCoord]
    let mode: SaveMode
}
```

### 22.4 Dirty tracking

```swift
protocol DirtyTrackableSystem {
    func dirtyScope(since tick: UInt64) -> DirtyScope
    func markSaved(upTo tick: UInt64)
}
```

### 22.5 Asset documents

```swift
struct IsoAssetManifest: Codable {
    let assetID: String
    let assetType: String
    let schemaVersion: Int
    let generatorVersion: String
    let displayName: String
    let tags: [String]
    let sourceGraphPath: String?
    let parameterPresetPath: String?
    let previewHash: String?
    let runtimeExportHash: String?
}
```

---

## 23. Schéma de base SQLite proposé

### 23.1 Tables runtime

```sql
CREATE TABLE save_metadata (
    key TEXT PRIMARY KEY,
    value BLOB NOT NULL
);

CREATE TABLE system_versions (
    system_id TEXT PRIMARY KEY,
    schema_version INTEGER NOT NULL,
    generator_hash TEXT,
    migrated_from INTEGER
);

CREATE TABLE persistent_entities (
    entity_id TEXT PRIMARY KEY,
    type_id TEXT NOT NULL,
    region_x INTEGER,
    region_z INTEGER,
    chunk_x INTEGER,
    chunk_z INTEGER,
    payload_version INTEGER NOT NULL,
    payload BLOB NOT NULL,
    last_modified_tick INTEGER NOT NULL
);

CREATE TABLE region_index (
    region_x INTEGER NOT NULL,
    region_z INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    checksum TEXT,
    last_modified_tick INTEGER,
    PRIMARY KEY(region_x, region_z)
);

CREATE TABLE world_events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    tick INTEGER NOT NULL,
    system_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload_version INTEGER NOT NULL,
    payload BLOB NOT NULL
);

CREATE TABLE asset_blob_refs (
    hash TEXT PRIMARY KEY,
    relative_path TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    ref_count INTEGER NOT NULL,
    content_type TEXT NOT NULL
);
```

### 23.2 Tables outils

```sql
CREATE TABLE tool_assets (
    asset_id TEXT PRIMARY KEY,
    asset_type TEXT NOT NULL,
    display_name TEXT NOT NULL,
    schema_version INTEGER NOT NULL,
    source_hash TEXT NOT NULL,
    runtime_export_hash TEXT,
    updated_at TEXT NOT NULL
);

CREATE TABLE graph_revisions (
    revision_id TEXT PRIMARY KEY,
    asset_id TEXT NOT NULL,
    parent_revision_id TEXT,
    graph_hash TEXT NOT NULL,
    editor_state_hash TEXT,
    message TEXT,
    created_at TEXT NOT NULL
);

CREATE TABLE tool_sessions (
    session_id TEXT PRIMARY KEY,
    opened_asset_id TEXT,
    layout_payload BLOB,
    updated_at TEXT NOT NULL
);
```

---

## 24. Liste longue des données à sauvegarder

### 24.1 Gameplay joueur

- Position.
- Rotation.
- Vitesse.
- Posture.
- État mouvement.
- Santé.
- Blessures.
- Fatigue.
- Sommeil.
- Faim.
- Soif.
- Température corporelle.
- Moral.
- Stress.
- Maladies.
- Poison.
- Effets temporaires.
- Buffs/debuffs.
- Inventaire.
- Équipement porté.
- Vêtements.
- Chaussures.
- Armes.
- Outils.
- Munitions.
- Argent/ressources.
- Compétences.
- XP.
- Talents.
- Perks.
- Réputation.
- Relations.
- Connaissances.
- Cartes découvertes.
- Notes personnelles.
- Journal de quête.
- Camp actuel.
- Monture/véhicule associé.
- Compagnons.

### 24.2 Apparence personnage

- CharacterDNA.
- Morphologie.
- Âge visuel.
- Poids.
- Musculature.
- Taille.
- Posture.
- Peau.
- Cicatrices.
- Tatouages.
- Saleté.
- Sang.
- Brûlures.
- Cheveux.
- Barbe.
- Couleur cheveux.
- Perte de cheveux.
- Membres perdus.
- Prothèses.
- Boiterie.
- États de fatigue visibles.
- Usure des vêtements.
- Couleurs custom.

### 24.3 Monde macro

- Seed.
- WorldDNA.
- Règles RPG.
- Époque.
- Niveau technologique.
- Magie/absence de magie.
- Hostilité générale.
- Calendrier.
- Temps du monde.
- Saison.
- Cycles lunaires/astronomiques.
- Météo macro.
- Catastrophes actives.
- Factions.
- Territoires.
- Guerre/paix.
- Commerce.
- Ressources globales.
- Mythes découverts.
- Objectif final.
- Conditions de victoire.
- Conditions d’échec.

### 24.4 Monde local

- Chunks visités.
- Chunks modifiés.
- Props récoltés.
- Rochers cassés.
- Arbres coupés.
- Feux éteints/allumés.
- Camps placés.
- Routes créées.
- Ponts détruits.
- Échelles/cordes posées.
- Portes ouvertes.
- Containers pillés.
- Pièges désactivés.
- Animaux chassés.
- Donjons visités.
- Zones sécurisées.
- Pollution locale.
- Feu propagé.
- Neige accumulée persistante.
- Eau détournée.

### 24.5 PNJ et créatures

- Identité.
- Faction.
- Position si persistante.
- Routine.
- Santé.
- Inventaire.
- Relations.
- Souvenirs importants.
- Objectifs.
- Peurs.
- Connaissances.
- État de dialogue.
- Quête liée.
- Mort/vivant.
- Corps/loot.
- Migration.
- Domestication.
- Reproduction si simulée.

### 24.6 Structures

- Settlement states.
- Bâtiments construits.
- Bâtiments détruits.
- Propriétaires.
- Intérieurs visités.
- Portes/coffres.
- Défenses.
- Production.
- Stockage.
- Population.
- Électricité/eau si époque moderne.
- Machines.
- Pollution.
- Incendies.
- Réparations.

### 24.7 Outils moteur

- Graphes procéduraux.
- Paramètres exposés.
- Presets.
- Variantes.
- Tests.
- Seeds de preview.
- Thumbnails.
- Exports runtime.
- Historique local.
- Notes.
- Tags.
- Collections.
- Layouts.
- Sélections.
- Bookmarks.
- Debug captures.

---

## 25. Stratégie de caches

### 25.1 Cache global

Contient :

- Shaders compilés si applicable.
- Meshes générés fréquemment.
- Textures procédurales baked.
- Navmesh chunks.
- Light probes.
- Preview thumbnails.
- Audio previews.

### 25.2 Règles cache

- Toujours rebuildable.
- Jamais source of truth.
- Peut être supprimé sans perte.
- Versionné par hash de générateur + inputs.
- Nettoyage LRU.
- Taille max configurable.

### 25.3 Cache key

```text
CacheKey = hash(generatorID + generatorVersion + inputParameters + platform + qualityLevel)
```

---

## 26. Debug tools indispensables

### 26.1 Save Inspector

Afficher :

- Slots.
- Taille par domaine.
- Nombre chunks modifiés.
- Entités persistantes.
- Journaux.
- Snapshots.
- Versions systèmes.
- Erreurs validation.
- Deltas par région.

### 26.2 Diff Viewer

Comparer :

- Deux saves.
- Deux snapshots.
- Deux graphes outils.
- Deux chunks.
- Deux manifests.

### 26.3 Replay Runner

Permettre :

- Charger seed + inputs.
- Rejouer jusqu’au tick.
- Comparer hash attendu.
- Stop au premier mismatch.
- Exporter diagnostic bundle.

### 26.4 Migration Lab

Permettre :

- Charger save ancienne.
- Voir plan migration.
- Exécuter étape par étape.
- Comparer avant/après.
- Générer rapport.

---

## 27. Intégration avec le flux app

### 27.1 Menu principal

Le menu doit lire rapidement :

- Profil.
- Liste des saves.
- Résumés.
- Screenshots.
- Dernière version.
- États de corruption/migration requise.

Il ne doit pas ouvrir les mondes complets.

### 27.2 Debug mode

Le debug world doit pouvoir :

- Sauvegarder/recharger rapidement.
- Reset un système.
- Reset un chunk.
- Capturer un replay.
- Exporter une seed de bug.
- Tester migrations.
- Visualiser dirty chunks.

### 27.3 Génération d’un monde réel

Phases :

1. Choix seed.
2. Génération `WorldDNA`.
3. Validation règles.
4. Création manifest.
5. Pré-calculs nécessaires.
6. Création slot.
7. Premier snapshot.
8. Ouverture world.

La barre de chargement doit refléter ces phases.

### 27.4 Hub outils

Les outils doivent :

- Ouvrir des projets document-based.
- Autosave les graphes.
- Gérer undo/redo séparé de save.
- Exporter runtime packages.
- Ne pas corrompre un asset si crash pendant export.

---

## 28. Undo/Redo vs Save

Ne pas confondre :

- **Undo/redo** : historique d’édition court, interactif, en mémoire ou journal local.
- **Save** : persistance durable.
- **Revision** : snapshot intentionnel d’un asset.
- **Migration** : transformation de schéma.

Côté outils, un graphe peut avoir :

```text
Live edit buffer -> autosave draft -> explicit save -> revision snapshot -> runtime export
```

---

## 29. Roadmap d’implémentation

### Phase 1 — Fondations simples mais propres

- `SaveSlotManager`.
- Manifest JSON.
- Profil global.
- Sauvegarde joueur minimale.
- Seed + WorldDNA + generator versions.
- Écriture atomique via tmp/rename.
- Liste de saves dans menu.
- Debug inspector minimal.

### Phase 2 — Deltas chunks

- Dirty tracking chunks.
- Fichiers région simples.
- Deltas props/terrain basiques.
- Entités persistantes simples.
- Autosave incrémentale.

### Phase 3 — SQLite + journaux

- `state.sqlite`.
- Tables entities/events/regions.
- WAL.
- Event journal.
- Snapshots.
- Validation.

### Phase 4 — Outils procéduraux

- `.isoproj` packages.
- `.isoasset` packages.
- `.isograph`.
- Presets.
- Historique local.
- Export runtime.

### Phase 5 — Migrations

- `MigrationManager`.
- Versions par système.
- Corpus de saves tests.
- Migration lab.
- Backup avant migration.

### Phase 6 — Cloud et robustesse avancée

- Exclusion caches.
- Conflict resolver.
- Steam Cloud profile.
- iCloud/CloudKit expérimental.
- Repair tools avancés.

### Phase 7 — Collaboration future outils

- Change sets sémantiques.
- Locking optionnel.
- Merge de graphes simples.
- CAS partagé.

---

## 30. Décisions recommandées pour IsoWorld

### 30.1 À faire

- Utiliser des packages `.isosave` et `.isoproj`.
- Stocker les manifests en JSON.
- Stocker l’état structuré en SQLite.
- Stocker les deltas spatiaux par fichiers région.
- Utiliser un blob store adressé par hash.
- Écrire atomiquement avec transactions.
- Versionner toutes les données.
- Sauvegarder seed + generator versions + deltas.
- Ne pas sauvegarder les caches comme source of truth.
- Construire un Save Inspector très tôt.

### 30.2 À éviter

- Dump mémoire complet.
- Un seul énorme JSON.
- Mélanger caches et données source.
- Sauvegarder les chunks générés non modifiés.
- Dépendre de noms de classes Swift comme format durable.
- Ignorer les migrations.
- Sauvegarder pendant un état incohérent.
- Autosave sans backup.
- Cloud sync de caches volumineux.

### 30.3 Position sur SwiftData/Core Data

- Bon pour certains outils, index app, préférences complexes.
- Pas recommandé comme format principal des saves runtime monde.
- SQLite direct donne plus de contrôle et portabilité.
- Document packages Apple très utiles pour les outils.

### 30.4 Position sur JSON

- Excellent pour manifests/debug/presets.
- Mauvais pour monde énorme.
- À combiner avec binaire/SQLite.

### 30.5 Position sur event sourcing

- Très utile pour debug/replay/deltas.
- Ne doit pas être l’unique source indéfiniment.
- À compacter en snapshots.

---

## 31. Exemple complet de manifest `.isosave`

```json
{
  "format": "IsoWorldSavePackage",
  "formatVersion": 1,
  "slotID": "world-a9f2-main",
  "displayName": "Monde A9F2 — Camp nord",
  "createdAt": "2026-06-11T10:00:00Z",
  "lastSavedAt": "2026-06-11T12:30:00Z",
  "engineVersion": "0.8.0",
  "saveSchemaVersion": 4,
  "world": {
    "seed": "A9F2-7781-CC20",
    "worldDNAHash": "sha256:...",
    "terrainGenerator": "terrain-v4:sha256:...",
    "biomeGenerator": "biome-v3:sha256:...",
    "propGenerator": "props-v7:sha256:...",
    "rpgGenerator": "rpg-v2:sha256:..."
  },
  "player": {
    "displayName": "Player",
    "region": [0, -1],
    "position": [128.4, 42.1, -312.0],
    "level": 7
  },
  "files": {
    "stateDB": "state.sqlite",
    "regionsPath": "regions/",
    "blobsPath": "blobs/",
    "snapshotsPath": "snapshots/"
  },
  "integrity": {
    "generation": 42,
    "manifestChecksum": "sha256:..."
  }
}
```

---

## 32. Exemple complet de manifest `.isoasset`

```json
{
  "format": "IsoWorldAssetPackage",
  "formatVersion": 1,
  "assetID": "asset-prop-tree-oak-generator",
  "assetType": "ProceduralPropGenerator",
  "displayName": "Oak Tree Generator",
  "schemaVersion": 5,
  "tags": ["prop", "tree", "forest", "temperate"],
  "source": {
    "graph": "graph.isograph",
    "parameters": "parameters.json",
    "variants": "variants.json"
  },
  "runtimeExport": {
    "hash": "sha256:...",
    "path": "exports/runtime.ipropgen"
  },
  "preview": {
    "thumbnail": "thumbnails/main.png",
    "previewSeeds": [1, 2, 3, 4]
  },
  "history": {
    "currentRevision": "rev-0018",
    "revisionDB": "history/revisions.sqlite"
  }
}
```

---

## 33. Tests indispensables

### 33.1 Tests unitaires

- Encode/decode chaque système.
- Migration chaque version.
- Checksums.
- Dirty tracking.
- Region file read/write.
- Blob CAS dedup.

### 33.2 Tests d’intégration

- Créer monde → sauvegarder → charger → comparer hash.
- Modifier terrain → sauvegarder → charger → vérifier delta.
- Détruire prop → sauvegarder → prop absent.
- Construire bâtiment → sauvegarder → bâtiment présent.
- Changer apparence joueur → sauvegarder → apparence identique.

### 33.3 Tests de crash

Injecter crash :

- Pendant écriture manifest.
- Pendant écriture région.
- Pendant transaction SQLite.
- Pendant compaction.
- Pendant migration.
- Pendant autosave.

Résultat attendu : dernier état valide récupérable.

### 33.4 Tests déterministes

- Même seed = même world hash.
- Même save + mêmes deltas = même hash.
- Replay inputs = mêmes hashes de ticks.
- Migration conserve invariants.

---

## 34. Conclusion

Le système de sauvegarde d’IsoWorld doit être considéré comme un pilier du moteur, au même niveau que le renderer, le terrain, les props ou le RPG. Dans un monde procédural déterministe, la sauvegarde n’est pas seulement une persistance : c’est le contrat qui garantit que la seed, les règles, les deltas, l’histoire du joueur et les outils restent cohérents malgré les mises à jour du moteur.

La meilleure architecture est hybride :

- **Seed + versions + deltas** pour le monde.
- **Packages documentaires** pour saves et outils.
- **SQLite/WAL** pour index, entités, événements et état structuré.
- **Fichiers région** pour deltas spatiaux.
- **Blob store par hash** pour gros assets/caches.
- **Snapshots + journaux** pour performance, debug et rollback.
- **Migrations explicites** pour durabilité.
- **Caches strictement rebuildables** pour éviter la corruption conceptuelle.

Cette architecture permet de commencer simple, puis d’évoluer vers un moteur très robuste, capable de gérer des mondes vastes, des outils complexes, des assets procéduraux et des systèmes RPG lourds sans bloquer la performance ni sacrifier la maintenabilité.

---

## 35. Sources et références utiles

- Apple — Using the file system effectively : https://developer.apple.com/documentation/foundation/using-the-file-system-effectively
- Apple — Codable : https://developer.apple.com/documentation/swift/codable
- Apple — Encoding and Decoding Custom Types : https://developer.apple.com/documentation/foundation/encoding-and-decoding-custom-types
- Apple — Building a document-based app with SwiftUI : https://developer.apple.com/documentation/swiftui/building-a-document-based-app-with-swiftui
- Apple — Developing a Document-Based App : https://developer.apple.com/documentation/AppKit/developing-a-document-based-app
- Apple — NSDocument autosavesInPlace : https://developer.apple.com/documentation/appkit/nsdocument/autosavesinplace
- Apple — SwiftData : https://developer.apple.com/documentation/swiftdata
- Apple — Core Data Model Versioning and Data Migration : https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/Introduction.html
- SQLite — Write-Ahead Logging : https://sqlite.org/wal.html
- SQLite — Atomic Commit : https://sqlite.org/atomiccommit.html
- SQLite — Home : https://sqlite.org/
- Unreal Engine — Saving and Loading Your Game : https://dev.epicgames.com/documentation/unreal-engine/saving-and-loading-your-game-in-unreal-engine
- Unity — Persistent data / saving game states : https://unity.com/blog/games/persistent-data-how-to-save-your-game-states-and-settings
- Godot — Saving games : https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html
- Steamworks — Steam Cloud : https://partner.steamgames.com/doc/features/cloud
- CloudKit : https://developer.apple.com/icloud/cloudkit/
- Git — Pack format : https://git-scm.com/docs/pack-format
- Git Book — Packfiles : https://git-scm.com/book/en/v2/Git-Internals-Packfiles
- Unreal Engine — Perforce source control : https://dev.epicgames.com/documentation/unreal-engine/using-perforce-as-source-control-for-unreal-engine
- OpenUSD FAQ : https://openusd.org/release/usdfaq.html
- SideFX — USD basics : https://www.sidefx.com/docs/houdini/solaris/usd.html
- Automerge : https://automerge.org/
