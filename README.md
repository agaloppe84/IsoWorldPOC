# IsoWorldPOC

IsoWorldPOC est un POC de jeu macOS en Swift.

L'objectif est de construire progressivement un monde 3D procedural avec une vue isometrique/orbitale, un terrain vertical, une generation par chunks autour du joueur et un support manette PS5, tout en gardant une architecture propre, testable et respectueuse de l'environnement de developpement local.

## Objectifs

- App macOS SwiftUI.
- Rendu 3D initial avec RealityKit.
- Controle manette avec GameController, cible PS5.
- Monde procedural genere par chunks autour du joueur.
- Terrain avec verticalite.
- Architecture decouplee et testable.
- Protection stricte de l'environnement Ruby/Rails existant.

## Structure

```text
.
├── IsoWorldPOC/
│   ├── IsoWorldPOC.xcodeproj
│   ├── IsoWorldPOC/
│   ├── IsoWorldPOCTests/
│   └── IsoWorldPOCUITests/
├── docs/
├── scripts/
│   └── xcodebuild-safe.sh
└── README.md
```

## Build

Toujours compiler avec le wrapper local:

```sh
./scripts/xcodebuild-safe.sh -project IsoWorldPOC/IsoWorldPOC.xcodeproj -scheme IsoWorldPOC -destination 'platform=macOS' build
```

Ce wrapper fixe `DEVELOPER_DIR` localement pour la commande et evite toute modification globale de l'environnement Xcode.

## Documentation

- [Roadmap](docs/ROADMAP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Regles Codex](docs/CODEX.md)
- [Decisions](docs/DECISIONS.md)

