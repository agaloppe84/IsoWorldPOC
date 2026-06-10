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

Decision: isoler le visuel joueur dans `CharacterVisual`, avec chargement optionnel d'un modele local depuis `IsoWorldPOC/IsoWorldPOC/Assets/Models/`, humanoide procedural simple par defaut, et pilule debug comme fallback.

Raison: remplacer progressivement la capsule sans coupler le `PlayerController` a RealityKit, sans dependance externe et sans telechargement automatique.

Consequence: les modeles `.usdz` ou `.reality` devront etre ajoutes manuellement au repo et verifies avant utilisation.

Sources possibles: Kenney CC0, Poly Haven CC0, Sketchfab Creative Commons uniquement avec verification explicite de la licence, de l'attribution requise et du droit d'utilisation dans le projet.

## 011 - Lumiere RealityKit initiale

Decision: utiliser une lumiere directionnelle principale type soleil, une seconde lumiere directionnelle faible comme remplissage ambiant, et des ombres directionnelles bornees par une distance courte.

Raison: ameliorer la lecture du terrain et des props sans viser un rendu final ni ajouter de dependance externe.

Consequence: les parametres `sunDirection`, `sunIntensity`, `ambientIntensity` et `shadowsEnabled` sont exposes dans l'overlay debug pour suivre le comportement courant.

Limites RealityKit connues: l'eclairage reste simple, le controle fin des ombres est limite, les ombres peuvent couter cher avec beaucoup de chunks/props, et l'ambient actuel est une approximation via lumiere de remplissage plutot qu'un vrai systeme global illumination.

Budget performance: garder une seule source avec ombres actives au depart, limiter la distance d'ombre, et desactiver ou reduire les ombres si le frame time augmente sur Mac M1.

## 012 - Choix progressif du backend de rendu

Decision: introduire `RendererMode` avec `realityKit` par defaut et `metalExperimental` comme option preparee mais non activee.

Raison: conserver le POC jouable pendant que l'architecture se prepare a recevoir un backend Metal. RealityKit reste temporairement le backend actif parce qu'il gere deja la scene, la camera, les chunks, les props, le debug visuel, la lumiere et les interactions actuelles.

Consequence: `GameRootView` choisit le backend via un mode explicite, l'overlay debug affiche le renderer actif, et le futur `MetalGameView` pourra etre injecte sans remplacer toute la scene RealityKit d'un seul coup.

Migration Metal: Metal sera ajoute progressivement pour reduire le risque technique, commencer par le terrain seul, mesurer les performances, puis migrer les chunks, materiaux, debug 3D et props par etapes.
