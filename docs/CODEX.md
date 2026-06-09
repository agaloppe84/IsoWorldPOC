# Regles Codex

Ce document definit les regles a respecter par Codex ou tout agent automatique intervenant sur ce repo.

## Regles strictes

- Ne jamais utiliser `sudo`.
- Ne jamais utiliser `xcode-select`.
- Ne jamais utiliser `brew update`, `brew upgrade` ou `brew install`.
- Ne jamais utiliser `gem install`, `gem update`, `bundle update`.
- Ne jamais modifier `~/.zshrc`, `~/.bashrc`, `~/.profile`, `~/.rbenv`, `~/.rvm`, `~/.asdf`, `/opt/homebrew`, `/usr/local`, `/Library/Developer`.
- Ne jamais utiliser `swift test --package-path EngineCore`.
- Toujours tester `EngineCore` avec:

```sh
./scripts/swift-test-engine-safe.sh
```

- Toujours compiler l'app Xcode avec:

```sh
./scripts/xcodebuild-safe.sh -project IsoWorldPOC/IsoWorldPOC.xcodeproj -scheme IsoWorldPOC -destination 'platform=macOS' build
```

## Raison des scripts safe

La commande brute `swift test --package-path EngineCore` echoue volontairement sur cette machine parce que `xcode-select` reste pointe vers CommandLineTools afin de proteger l'environnement Ruby/Rails existant.

Les scripts locaux utilisent Xcode complet uniquement via `DEVELOPER_DIR`, sans modifier l'environnement global, sans changer `xcode-select` et sans toucher aux outils Ruby/Rails.

## Perimetre du repo

- Le projet Xcode est dans `IsoWorldPOC/IsoWorldPOC.xcodeproj`.
- Les sources de l'app sont dans `IsoWorldPOC/IsoWorldPOC/`.
- La documentation vit dans `docs/`.
- Les scripts locaux vivent dans `scripts/`.

## Contraintes d'architecture

- L'app macOS est une app SwiftUI.
- RealityKit est utilise pour le rendu 3D initial.
- GameController est utilise pour la manette PS5.
- `EngineCore` doit etre un Swift Package local a la racine du repo.
- `EngineCore` ne doit pas importer SwiftUI.
- `EngineCore` ne doit pas importer RealityKit.

## Hygiene d'intervention

- Ne pas modifier le code Swift sans demande explicite.
- Ne pas modifier l'environnement global.
- Ne pas installer de dependances globales.
- Preferer des changements petits, lisibles et testables.
- Verifier les chemins imbriques avant toute commande Xcode.
