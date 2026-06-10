# Architecture

## Cible

Le projet vise une separation nette entre l'application macOS, le rendu, les entrees utilisateur et le moteur de jeu.

```text
IsoWorldPOC macOS app
├── SwiftUI
├── RealityKit
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
- Integration RealityKit.
- Integration GameController.
- Adaptation entre l'etat moteur et le rendu.

L'app peut importer SwiftUI, RealityKit, GameController et EngineCore.

## Rendu 3D

RealityKit est le moteur de rendu initial.

Responsabilites:

- Scene 3D.
- Camera isometrique/orbitale.
- Entites visibles.
- Materiaux et lumieres.
- Synchronisation avec les donnees produites par le moteur.

RealityKit doit rester cote application ou dans un module de presentation dedie. Il ne doit pas entrer dans `EngineCore`.

### Backend actif

Le backend actif temporaire est `RealityKitGameRenderer`.

Responsabilites:

- Configurer la scene RealityKit.
- Posseder la camera RealityKit active.
- Connecter les chunks streamés aux entites RealityKit.
- Mettre a jour le joueur visible, les lumieres et les metriques debug.
- Garder le comportement actuel du POC pendant la migration progressive.

`RealityKitGameView` reste un host macOS/SwiftUI: elle cree l'`ARView`, transmet les evenements clavier et laisse le backend renderer gerer la scene.

La prochaine cible est d'introduire un backend parallele `MetalGameRenderer` sans supprimer RealityKit. Les contrats de rendu purs vivent dans `EngineCore/Rendering` et ne doivent importer ni RealityKit ni Metal.

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
EngineCore
        ↓
Etat monde / chunks / deltas
        ↓
Adaptateur de rendu
        ↓
RealityKit
```

## Build

La compilation doit toujours passer par:

```sh
./scripts/xcodebuild-safe.sh -project IsoWorldPOC/IsoWorldPOC.xcodeproj -scheme IsoWorldPOC -destination 'platform=macOS' build
```
