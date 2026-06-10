# Decisions

Ce fichier garde une trace courte des decisions structurantes du projet.

## 001 - Build Xcode via wrapper local

Decision: compiler avec `scripts/xcodebuild-safe.sh`.

Raison: fixer `DEVELOPER_DIR` pour la commande courante sans modifier la configuration globale de la machine.

Consequence: toute commande de build documentee doit utiliser le wrapper local.

## 002 - Projet Xcode imbrique

Decision: conserver le projet Xcode dans `IsoWorldPOC/IsoWorldPOC.xcodeproj`.

Raison: respecter la structure actuelle du repo.

Consequence: les commandes Xcode doivent toujours referencer ce chemin explicitement.

## 003 - Sources app dans IsoWorldPOC/IsoWorldPOC

Decision: conserver les sources de l'app macOS dans `IsoWorldPOC/IsoWorldPOC/`.

Raison: respecter la structure standard creee par Xcode et eviter les deplacements prematures.

Consequence: les changements UI, rendu et integration macOS commencent dans ce dossier.

## 004 - EngineCore comme Swift Package local

Decision: creer a terme un package local `EngineCore` a la racine du repo.

Raison: isoler la logique moteur de l'app macOS et rendre les regles testables.

Consequence: `EngineCore` ne doit pas importer SwiftUI ni RealityKit.

## 005 - RealityKit pour le rendu initial

Decision: utiliser RealityKit pour le premier rendu 3D.

Raison: rester dans l'ecosysteme Apple et avancer vite sur un prototype macOS.

Consequence: les types de rendu doivent rester separes des types purs du moteur.

## 006 - GameController pour la manette PS5

Decision: utiliser GameController pour l'integration manette.

Raison: s'appuyer sur le framework Apple dedie aux controllers.

Consequence: les entrees physiques doivent etre converties en intentions testables avant d'atteindre le moteur.

## 007 - Protection de l'environnement Ruby/Rails

Decision: ne pas modifier l'environnement global Ruby, shell, Homebrew ou Xcode.

Raison: proteger les projets Ruby/Rails existants sur la machine.

Consequence: les scripts et commandes doivent rester locaux au repo.

## 008 - Budget initial chunks et instrumentation

Decision: mesurer avant d'optimiser avec un budget initial de 9 chunks actifs.

Raison: `activeRadius = 1` charge le chunk joueur et ses 8 voisins, ce qui suffit pour valider terrain, biomes, props et suivi joueur avant la physique.

Consequence: les metriques debug exposent chunks actifs/visibles, triangles approximatifs, props approximatifs, frame time et moyennes de generation de chunk/mesh.

Limites connues: generation synchrone, pas encore de LOD, pas encore de culling fin, pas encore de cache persistant; `visibleChunkCount` est actuellement equivalent aux chunks charges.

## 009 - Strategie texture terrain initiale

Decision: commencer avec un `TerrainMaterialDescriptor` pur dans `EngineCore` et une traduction simple vers un `SimpleMaterial` RealityKit par chunk.

Raison: differencier visuellement les biomes sans importer de grosses textures externes, sans multiplier excessivement les materiaux et sans toucher au streaming.

Consequence: les biomes exposent des materiaux semantiques simples (`grass`, `rock`, `dirt`, `sand`, `wetValley`, `snow` futur), tandis que l'app garde la responsabilite de creer les materiaux RealityKit.

Objectif futur: introduire progressivement textures PBR, splat maps, triplanar mapping, normal maps, roughness maps et transitions douces entre biomes quand le terrain et le streaming seront stabilises.

## 010 - Strategie visuel personnage

Decision historique: le visuel joueur avait ete isole dans `CharacterVisual`, avec chargement optionnel d'un modele local depuis `IsoWorldPOC/IsoWorldPOC/Assets/Models/`, humanoide procedural simple par defaut, et pilule debug comme fallback.

Raison: remplacer progressivement la capsule sans coupler le `PlayerController` a RealityKit, sans dependance externe et sans telechargement automatique.

Consequence actuelle: `CharacterVisual` a ete supprime avec le code RealityKit legacy. Le prochain visuel personnage devra passer par des descriptors neutres et un adaptateur Metal.

Sources possibles: Kenney CC0, Poly Haven CC0, Sketchfab Creative Commons uniquement avec verification explicite de la licence, de l'attribution requise et du droit d'utilisation dans le projet.

## 011 - Lumiere RealityKit initiale

Decision: utiliser une lumiere directionnelle principale type soleil, une seconde lumiere directionnelle faible comme remplissage ambiant, et des ombres directionnelles bornees par une distance courte.

Raison: ameliorer la lecture du terrain et des props sans viser un rendu final ni ajouter de dependance externe.

Consequence: les parametres `sunDirection`, `sunIntensity`, `ambientIntensity` et `shadowsEnabled` sont exposes dans l'overlay debug pour suivre le comportement courant.

Limites RealityKit connues: l'eclairage reste simple, le controle fin des ombres est limite, les ombres peuvent couter cher avec beaucoup de chunks/props, et l'ambient actuel est une approximation via lumiere de remplissage plutot qu'un vrai systeme global illumination.

Budget performance: garder une seule source avec ombres actives au depart, limiter la distance d'ombre, et desactiver ou reduire les ombres si le frame time augmente sur Mac M1.

## 012 - Metal comme renderer actif unique

Decision: l'app demarre directement sur Metal. `GameRootView` instancie `MetalGameView` sans switch de backend et l'overlay affiche `Renderer: Metal`.

Raison: la direction du projet est Metal-only. Garder deux backends actifs complique l'architecture, masque les bugs Metal et retarde la separation avec RealityKit.

Consequence: RealityKit a ete retire du code app. Les prochains changements doivent renforcer les donnees procedurales neutres, les passes Metal et la testabilite du renderer.

Migration Metal: Metal devient la base du rendu. Les efforts suivants portent sur la testabilite du renderer, les contrats de rendu neutres, les passes de rendu et les ressources GPU.

## 013 - Donnees procedurales separees de RealityKit

Decision: extraire la generation des donnees de chunk dans `ProceduralChunkDataFactory`, cote app/simulation, sans import RealityKit ni Metal.

Raison: le backend Metal ne doit pas dependre d'un factory qui melange generation procedurale et rendu.

Consequence: `MetalChunkDataStreamer` genere ses chunks via `ProceduralChunkDataFactory`. L'ancien `ProceduralTerrainFactory` RealityKit a ete supprime.

Prochaine cible: deplacer davantage de logique runtime vers des types testables et reduire le role direct de `MetalRenderer`.

## 014 - Props rendus par Metal et suppression RealityKit legacy

Decision: rendre les props proceduraux a partir des `propVariants` dans le backend Metal, puis supprimer les anciens fichiers RealityKit legacy.

Raison: les props font partie du monde procedurale visible et doivent utiliser les memes donnees deterministes que le terrain. Garder les adaptateurs RealityKit apres le passage Metal-only entretiendrait une architecture ambigue.

Consequence: chaque chunk Metal bake un mesh de props simple depuis les descriptors abstraits (`PropGeometryDescriptor`, materiaux par slot, position monde). Les fichiers `RealityKitGameView`, `RealityKitGameRenderer`, `RealityKitTerrainAdapter`, `RealityKitPropAdapter`, `ChunkTerrainManager`, `DebugSceneFactory`, `CharacterVisual`, `CameraController`, `ChunkDebugVisualFactory`, `ProceduralTerrainFactory` et `SceneLightingSettings` ont ete retires.
