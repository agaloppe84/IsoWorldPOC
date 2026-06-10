# Architecture

## Cible

Le projet vise une separation nette entre l'application macOS, le rendu, les entrees utilisateur et le moteur de jeu.

```text
IsoWorldPOC macOS app
├── SwiftUI
├── Metal
├── GameController
└── EngineCore
    ├── simulation
    ├── generation procedurale
    ├── chunks
    ├── coordonnees monde
    └── regles testables
```

## App macOS

Les sources de l'app vivent dans:

```text
IsoWorldPOC/IsoWorldPOC/
```

Responsabilites:

- Composition SwiftUI.
- Cycle de vie macOS.
- Integration Metal.
- Integration GameController.
- Adaptation entre l'etat moteur et le rendu.

L'app peut importer SwiftUI, MetalKit, GameController et EngineCore. RealityKit a ete retire du code app et ne doit pas etre reintroduit.

## Rendu 3D

Metal est le renderer actif du projet.

Responsabilites:

- Scene 3D.
- Camera isometrique/orbitale.
- Entites visibles.
- Materiaux et lumieres.
- Synchronisation GPU avec les snapshots de rendu produits par la simulation.

RealityKit ne fait plus partie du chemin de rendu. Il ne doit pas entrer dans `EngineCore`.

### Backend actif

Le backend actif unique est `MetalRenderer`, heberge par `MetalGameView`.

Responsabilites:

- Configurer `MTKView`.
- Posseder les ressources GPU Metal.
- Consommer `RenderWorldSnapshot`.
- Dessiner le terrain, les props placeholders, le joueur placeholder et le debug 3D.
- Mettre a jour les metriques debug liees au renderer.
- Ne pas piloter directement la simulation, les inputs gameplay ou le streaming logique.

`MetalGameView` reste un host macOS/SwiftUI: elle cree le `MTKView`, transmet les evenements clavier et laisse le backend renderer gerer le rendu.

Les contrats de rendu purs vivent dans `EngineCore/Rendering` et ne doivent importer ni RealityKit ni Metal.

### Runtime monde et snapshots

`WorldRuntime` est la couche runtime de l'app. Elle orchestre les systemes gameplay encore cote app:

- `InputManager`;
- `PlayerController`;
- `PlayerGrounding`;
- `OrbitCameraController`;
- `ChunkDataStreamer`;
- `RenderSnapshotBuilder`.

Responsabilites:

- Avancer la simulation a chaque frame.
- Mettre a jour le streaming de chunks autour du joueur.
- Resoudre le suivi terrain du joueur.
- Produire le `RenderWorldSnapshot` courant.
- Remplir les metriques debug gameplay/monde.

`RenderSnapshotBuilder` convertit l'etat runtime en contrats de rendu neutres:

- `RenderWorldSnapshot`;
- `RenderChunk`;
- `RenderProp`;
- `CameraRenderState`;
- options de debug chunk bounds/labels.

Le renderer Metal ne doit donc pas construire le monde ni decider quels chunks existent. Il recoit un snapshot, synchronise les buffers GPU manquants, puis dessine.

### Donnees de chunks procedurales

`ProceduralChunkDataFactory` produit les donnees de chunks neutres consommees par Metal:

- geometrie terrain issue d'`EngineCore`;
- biome dominant;
- materiau terrain abstrait;
- placements et variants de props;
- origine monde du chunk;
- metriques simples de generation.

Ce factory ne doit pas importer RealityKit ni Metal. Il remplace l'ancien melange entre generation de donnees et rendu RealityKit.

## Input

GameController est utilise pour le support manette PS5.

Responsabilites:

- Detection de la manette.
- Lecture des axes et boutons.
- Conversion en intentions de jeu.

Les intentions de jeu doivent etre des types simples que le moteur peut consommer sans dependre de GameController.

## EngineCore

`EngineCore` sera un Swift Package local a la racine du repo.

Responsabilites:

- Generation procedurale.
- Gestion des chunks.
- Coordonnees monde, positions et hauteurs.
- Simulation et regles de gameplay.
- Types purs testables.

Contraintes:

- Ne doit pas importer SwiftUI.
- Ne doit pas importer RealityKit.
- Ne doit pas dependre du cycle de vie macOS.
- Doit etre testable par des tests unitaires rapides.

## Flux de donnees

```text
Controller / clavier
        ↓
Intentions d'input
        ↓
WorldRuntime
        ↓
Simulation joueur / camera / streaming
        ↓
RenderSnapshotBuilder
        ↓
RenderWorldSnapshot
        ↓
Metal
```

## Build

La compilation doit toujours passer par:

```sh
./scripts/xcodebuild-safe.sh -project IsoWorldPOC/IsoWorldPOC.xcodeproj -scheme IsoWorldPOC -destination 'platform=macOS' build
```
