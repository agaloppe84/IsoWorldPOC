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
- Orchestrer les passes Metal.
- Mettre a jour les metriques debug liees au renderer.
- Ne pas piloter directement la simulation, les inputs gameplay ou le streaming logique.

`MetalGameView` reste un host macOS/SwiftUI: elle cree le `MTKView`, transmet les evenements clavier et laisse le backend renderer gerer le rendu.

Les contrats de rendu purs vivent dans `EngineCore/Rendering` et ne doivent importer ni RealityKit ni Metal.

### Passes Metal

Le rendu Metal est organise en passes legeres, sans RenderGraph complet pour l'instant:

- `MetalTerrainPass`: dessine les chunks terrain visibles.
- `MetalPropPass`: dessine les props proceduraux bakes dans les buffers de chunk.
- `MetalPlayerPass`: dessine le preview joueur.
- `MetalDebugPass`: dessine les helpers debug 3D comme les bounds de chunks.

`MetalFrameContext` transporte l'etat necessaire a une frame:

- `RenderWorldSnapshot`;
- buffers GPU par chunk;
- buffers joueur;
- position joueur;
- matrice view-projection.
- uniforms de lumiere derives de `LightingState`.
- uniforms debug derives de `RenderDebugOptions`.

Chaque passe retourne des metriques de draw simples. L'overlay expose les draw calls, buffers GPU, chunks dessines et props dessines. Cette structure prepare les futures passes lighting/shadow/material sans imposer encore un graphe de rendu complexe.

### Materiaux Metal initiaux

Le rendu Metal utilise un payload materiau par vertex:

- couleur de base;
- roughness scalaire;
- identifiant numerique simple de type materiau;
- indices de couches texture terrain explicites;
- echelles UV par couche terrain.

Pour le terrain, `BiomeSampler` produit maintenant un `TerrainVertexMaterial` par sample/vertex. Ces materiaux restent deterministes par seed, chunk et coordonnee locale. Les bords utilisent les memes coordonnees monde que la generation de biome, ce qui permet aux chunks voisins de partager les memes couleurs/materiaux sur leurs frontieres.

Chaque sample peut porter un materiau primaire, un materiau secondaire et un poids de transition. Ces donnees restent disponibles pour les vues debug, tandis que le rendu normal utilise les couches splat PBR preview dans le fragment shader.

Les donnees de sample preparent aussi un modele splat: `TerrainMaterialSplat` contient jusqu'a 4 couches de materiaux normalisees. Chaque couche porte un `RenderMaterial` et des `TerrainPBRTextureSlots` neutres pour `albedo`, `normal`, `roughness` et `metallicAmbientOcclusion`. Ces slots declarent `textureLayerIndex`, `uvScale` et `debugName` sans importer Metal. Le vertex buffer Metal transporte `splatWeights`, `splatTextureLayerIndices`, `splatUVScales` et les coordonnees UV terrain.

Le rendu normal du terrain utilise un `TerrainTextureCatalog` preview cote Metal. Ce catalogue genere en memoire quatre petits texture arrays 2x2 par materiau (`grass`, `rock`, `dirt`, `sand`, `mud`, `snow`): albedo, normal flat, roughness grayscale et metallic/ambient-occlusion neutre. Le fragment shader echantillonne ces couches et les melange avec les 4 poids splat. C'est volontairement simple, mais l'architecture est deja proche d'un futur atlas ou texture array de vraies textures.

L'overlay peut basculer le debug terrain entre rendu normal, biome primaire, biome secondaire, heatmap du poids de transition et heatmap d'une couche splat specifique. Le mode et l'index de couche splat sont stockes dans `RenderDebugOptions`, passes au shader par uniform, et ne s'appliquent qu'aux vertices terrain.

Cette approche garde les props et terrains batchables par chunk. Elle evite de multiplier les draw calls par biome ou materiau. Le shader utilise actuellement la roughness pour adoucir la reponse diffuse des materiaux rugueux.

### LOD baseline

Le LOD V1 est un systeme classique et explicite, avant tout HLOD ou virtual geometry.

Responsabilites:

- `EngineCore/LOD` definit `LODPolicy`, `LODSelection`, `ScreenError`, `Hysteresis` et `LODBudget`.
- `ChunkDataStreamer` garde un rayon de chunks candidats, calcule une selection LOD deterministe depuis la position joueur et applique un budget de chunks visibles et de props rendus.
- `RenderChunk` transporte sa `LODSelection`, afin que le renderer ne reinvente pas la decision.
- `RenderPayloadUploader` charge uniquement les chunks visibles.
- `MetalChunkBuffers` genere l'index buffer terrain selon le niveau LOD selectionne, avec des bords de chunk conserves en pleine resolution.

Cette baseline ne fait pas encore de meshlets, HLOD, visibility buffer, occlusion culling GPU ou collision LOD avancee.

### Lumiere

La lumiere de base est portee par `LightingState` dans les contrats `EngineCore/Rendering`.

Responsabilites:

- Decrire une lumiere directionnelle principale.
- Exposer intensite solaire, intensite ambiante et activation future des ombres.
- Rester independante de Metal, RealityKit et SwiftUI.

Le shader Metal consomme ces valeurs via un uniform dedie. Les ombres ne sont pas encore calculees: `shadowsEnabled` est conserve dans le contrat pour preparer une future `MetalShadowPass`.

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
- options de debug chunk bounds et modes materiaux terrain.

Le renderer Metal ne doit donc pas construire le monde ni decider quels chunks existent. Il recoit un snapshot, synchronise les buffers GPU manquants, puis dessine.

### Donnees de chunks procedurales

`ProceduralChunkDataFactory` produit les donnees de chunks neutres consommees par Metal:

- geometrie terrain issue d'`EngineCore`;
- biome dominant;
- materiau terrain abstrait;
- materiaux terrain par vertex/sample issus du biome;
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
