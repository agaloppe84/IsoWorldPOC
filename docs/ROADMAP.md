# Roadmap

Cette roadmap sert de fil conducteur pour le POC. Elle doit rester simple, concrete et ajustable.

## Phase 0 - Base projet

- Documenter le projet.
- Stabiliser la commande de build locale.
- Definir les contraintes de securite de l'environnement.
- Garder le code Swift existant intact tant que l'architecture cible n'est pas posee.

## Phase 1 - Socle application

- Conserver une app macOS SwiftUI dans `IsoWorldPOC/IsoWorldPOC/`.
- Ajouter un point d'integration clair pour la vue 3D.
- Utiliser Metal comme renderer actif.
- Afficher une scene simple verifiable: camera, terrain, props proceduraux simples, joueur et debug overlay.

## Phase 2 - EngineCore

- Creer un Swift Package local `EngineCore` a la racine du repo.
- Deplacer la logique pure de jeu dans `EngineCore`.
- Interdire les imports SwiftUI, RealityKit et Metal dans `EngineCore`.
- Couvrir les premieres regles moteur par des tests unitaires.

## Phase 3 - Monde procedural

- Definir les types de base: coordonnees, chunks, seed, hauteur, materiaux.
- Generer les chunks autour du joueur.
- Charger et decharger les chunks selon la position.
- Ajouter une premiere verticalite lisible du terrain.

## Phase 4 - Camera et navigation

- Implementer une camera isometrique/orbitale.
- Ajouter zoom, rotation et deplacement.
- Garder une separation claire entre input, simulation et rendu.

## Phase 5 - Manette PS5

- Ajouter GameController cote app.
- Mapper les controles essentiels: deplacement, camera, actions.
- Prevoir une couche d'abstraction pour tester les intentions d'input sans manette physique.

## Phase 6 - Iteration gameplay

- Ajouter les premieres interactions avec le terrain.
- Mesurer les performances de generation et rendu.
- Identifier les limites du POC avant industrialisation.
