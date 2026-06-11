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

Decision historique: commencer avec un `TerrainMaterialDescriptor` pur dans `EngineCore` et une traduction simple vers un `SimpleMaterial` RealityKit par chunk.

Raison: differencier visuellement les biomes sans importer de grosses textures externes, sans multiplier excessivement les materiaux et sans toucher au streaming.

Consequence actuelle: les biomes exposent des materiaux semantiques simples (`grass`, `rock`, `dirt`, `sand`, `wetValley`, `snow` futur). Le rendu Metal utilise d'abord des couleurs vertex/material placeholders derivees de ces descriptors.

Objectif futur: introduire progressivement textures PBR, splat maps, triplanar mapping, normal maps, roughness maps et transitions douces entre biomes quand le terrain et le streaming seront stabilises.

## 010 - Strategie visuel personnage

Decision historique: le visuel joueur avait ete isole dans `CharacterVisual`, avec chargement optionnel d'un modele local depuis `IsoWorldPOC/IsoWorldPOC/Assets/Models/`, humanoide procedural simple par defaut, et pilule debug comme fallback.

Raison: remplacer progressivement la capsule sans coupler le `PlayerController` a RealityKit, sans dependance externe et sans telechargement automatique.

Consequence actuelle: `CharacterVisual` a ete supprime avec le code RealityKit legacy. Le prochain visuel personnage devra passer par des descriptors neutres et un adaptateur Metal.

Sources possibles: Kenney CC0, Poly Haven CC0, Sketchfab Creative Commons uniquement avec verification explicite de la licence, de l'attribution requise et du droit d'utilisation dans le projet.

## 011 - Lumiere initiale

Decision historique: utiliser une lumiere directionnelle principale type soleil, une seconde lumiere directionnelle faible comme remplissage ambiant, et des ombres directionnelles bornees par une distance courte.

Raison: ameliorer la lecture du terrain et des props sans viser un rendu final ni ajouter de dependance externe.

Consequence actuelle: les parametres `sunDirection`, `sunIntensity`, `ambientIntensity` et `shadowsEnabled` sont portes par `LightingState`, envoyes au shader Metal et exposes dans l'overlay debug.

Limites historiques RealityKit: l'eclairage et le controle fin des ombres etaient limites pour notre trajectoire Metal-only.

Limite actuelle Metal: l'eclairage est volontairement simple, sans shadow map, sans BRDF avancee et sans correction colorimetrique fine. L'ambient reste une approximation controlee.

Budget performance: garder une seule source avec ombres actives au depart, limiter la distance d'ombre, et desactiver ou reduire les ombres si le frame time augmente sur Mac M1.

## 012 - Metal comme renderer actif unique

Decision: l'app demarre directement sur Metal. `GameRootView` instancie `MetalGameView` sans switch de backend et l'overlay affiche `Renderer: Metal`.

Raison: la direction du projet est Metal-only. Garder deux backends actifs complique l'architecture, masque les bugs Metal et retarde la separation avec RealityKit.

Consequence: RealityKit a ete retire du code app. Les prochains changements doivent renforcer les donnees procedurales neutres, les passes Metal et la testabilite du renderer.

Migration Metal: Metal devient la base du rendu. Les efforts suivants portent sur la testabilite du renderer, les contrats de rendu neutres, les passes de rendu et les ressources GPU.

## 013 - Donnees procedurales separees de RealityKit

Decision: extraire la generation des donnees de chunk dans `ProceduralChunkDataFactory`, cote app/simulation, sans import RealityKit ni Metal.

Raison: le backend Metal ne doit pas dependre d'un factory qui melange generation procedurale et rendu.

Consequence: `ChunkDataStreamer` genere ses chunks via `ProceduralChunkDataFactory`. L'ancien `ProceduralTerrainFactory` RealityKit a ete supprime.

Prochaine cible: deplacer davantage de logique runtime vers des types testables et reduire le role direct de `MetalRenderer`.

## 014 - Props rendus par Metal et suppression RealityKit legacy

Decision: rendre les props proceduraux a partir des `propVariants` dans le backend Metal, puis supprimer les anciens fichiers RealityKit legacy.

Raison: les props font partie du monde procedurale visible et doivent utiliser les memes donnees deterministes que le terrain. Garder les adaptateurs RealityKit apres le passage Metal-only entretiendrait une architecture ambigue.

Consequence: chaque chunk Metal bake un mesh de props simple depuis les descriptors abstraits (`PropGeometryDescriptor`, materiaux par slot, position monde). Les fichiers `RealityKitGameView`, `RealityKitGameRenderer`, `RealityKitTerrainAdapter`, `RealityKitPropAdapter`, `ChunkTerrainManager`, `DebugSceneFactory`, `CharacterVisual`, `CameraController`, `ChunkDebugVisualFactory`, `ProceduralTerrainFactory` et `SceneLightingSettings` ont ete retires.

## 015 - WorldRuntime et RenderSnapshotBuilder

Decision: extraire une couche `WorldRuntime` et un `RenderSnapshotBuilder` pour produire `RenderWorldSnapshot` avant le rendu Metal.

Raison: `MetalRenderer` doit rester responsable des ressources GPU, des pipelines et du dessin. La simulation joueur, le streaming logique de chunks, le grounding et la camera ne doivent pas etre pilotes directement par le renderer.

Consequence: `WorldRuntime` orchestre input, joueur, camera, grounding et `ChunkDataStreamer`. `RenderSnapshotBuilder` transforme les donnees runtime en contrats neutres (`RenderChunk`, `RenderProp`, `CameraRenderState`). `MetalRenderer` consomme uniquement le snapshot courant, synchronise les buffers Metal et met a jour les metriques renderer.

Limite actuelle: `WorldRuntime` vit encore cote app. Une future etape pourra deplacer davantage de logique pure vers `EngineCore`, tant que celui-ci reste independant de SwiftUI, RealityKit et Metal.

## 016 - Passes Metal legeres avant RenderGraph complet

Decision: organiser le rendu Metal en passes simples (`MetalTerrainPass`, `MetalPropPass`, `MetalPlayerPass`, `MetalDebugPass`) pilotees par `MetalRenderer`.

Raison: le renderer doit rester extensible pour lighting, shadows et materiaux sans devenir un fichier monolithique, mais un RenderGraph complet serait premature a ce stade.

Consequence: `MetalRenderer` prepare `MetalFrameContext`, lance les passes, synchronise les buffers GPU et expose des metriques de draw. Chaque passe reste petite, specialisee et mesurable.

Validation actuelle: l'overlay expose les draw calls totaux et par passe, le nombre de buffers GPU, les chunks dessines et les props dessines.

Prochaine cible: introduire une vraie strategie de materiaux/lighting en s'appuyant sur ces passes, puis seulement ajouter un RenderGraph si les dependances entre passes le justifient.

## 017 - LightingState neutre pour Metal

Decision: ajouter `LightingState` dans les contrats `EngineCore/Rendering` et le transporter via `RenderWorldSnapshot`.

Raison: la lumiere ne doit pas etre hardcodee dans le shader Metal. Elle fait partie de l'etat de rendu du monde, doit etre testable et doit rester independante du backend.

Consequence: `WorldRuntime` produit un snapshot avec une lumiere directionnelle par defaut. `MetalRenderer` convertit cette lumiere en uniforms GPU, et le shader applique une premiere lumiere diffuse + ambiante. Les ombres restent desactivees et reservees a une future passe dediee.

Validation actuelle: les tests `EngineCore` couvrent la stabilite du `LightingState` par defaut et le stockage dans `RenderWorldSnapshot`.

## 018 - Payload materiau par vertex

Decision: transporter un payload materiau minimal dans `MetalTerrainVertex`: roughness et identifiant numerique de type materiau.

Raison: le terrain et les props doivent commencer a exploiter les descriptors materiaux sans creer un draw call par materiau ni multiplier les pipelines trop tot.

Consequence: les vertices terrain recoivent la roughness et le type issus de `TerrainMaterialDescriptor`; les vertices de props recoivent la roughness de leur `PropMaterialDescriptor`. Le shader utilise la roughness pour adoucir la lumiere diffuse.

Limite actuelle: il ne s'agit pas encore d'un systeme PBR. Les ids materiaux preparent le debug et les futures textures/atlas/splat maps, mais ne pilotent pas encore des textures.

## 019 - Materiaux terrain par sample

Decision: ajouter un `TerrainVertexMaterial` par sample/vertex terrain et le transporter jusque dans `RenderChunk`.

Raison: une couleur/matiere unique par chunk rend les biomes trop plats et provoque des transitions visuelles grossieres. Le terrain doit deja pouvoir exprimer des variations locales sans creer un draw call par biome.

Consequence: `BiomeSampler` derive un materiau terrain pour chaque sample a partir des coordonnees monde implicites du chunk. `ProceduralChunkDataFactory` stocke ces materiaux avec la geometrie, `RenderSnapshotBuilder` les expose dans `RenderChunk`, et `MetalRenderer` bake couleur + payload materiau dans le vertex buffer terrain.

Garantie: les tests EngineCore verifient que deux chunks voisins produisent les memes materiaux sur leurs bords partages, y compris avec des coordonnees negatives.

Limite actuelle: le rendu reste en vertex colors et payloads simples. Les transitions entre biomes peuvent encore etre franches; le prochain niveau sera d'introduire des poids de materiaux/splat data deterministes avant d'ajouter textures ou atlas.

## 020 - Transitions douces de materiaux terrain

Decision: enrichir `TerrainVertexMaterial` avec un materiau primaire, un materiau secondaire et un `blendWeight` par sample.

Raison: les transitions de biomes ne doivent pas rester des aplats durs. Une transition par vertex donne un premier lissage visuel tout en gardant un seul draw call terrain par chunk.

Consequence: `BiomeSampler` echantillonne un voisinage deterministic autour de chaque position monde pour choisir un biome secondaire et un poids borne. Le vertex buffer Metal transporte une couleur secondaire et le shader mixe couleur + roughness.

Garantie: les poids restent normalises (`primaryWeight + secondaryWeight = 1`) et les tests verifient determinisme, existence de transitions et raccord exact des bords entre chunks.

Limite actuelle: le mix se fait en vertex color. Ce n'est pas encore une splat map ni un vrai systeme de textures; les prochains travaux devront introduire des poids de materiaux plus explicites, puis des texture arrays/atlas.

## 021 - Debug visuel des materiaux terrain

Decision: ajouter `TerrainMaterialDebugMode` dans `RenderDebugOptions` avec les modes `normal`, `primaryBiome`, `secondaryBiome` et `blendWeight`.

Raison: les transitions de biomes doivent etre inspectables dans le jeu avant d'investir dans des textures, splat maps ou regles plus complexes.

Consequence: l'overlay expose un picker de mode terrain. `WorldRuntime` transporte ce mode dans le snapshot, `MetalFrameContext` le convertit en uniform, et le shader Metal applique le debug seulement aux materiaux terrain.

Limite actuelle: le mode `blendWeight` est une heatmap de debug et non un rendu artistique. Il sert a verifier ou les transitions existent, pas a representer le style final.

## 022 - Preparation des splat weights terrain

Decision: introduire `TerrainMaterialSplat` et `TerrainMaterialSplatLayer` dans les contrats EngineCore.

Raison: le modele primaire/secondaire suffit pour une premiere transition visuelle, mais il ne sera pas assez riche pour des texture arrays, atlas, splat maps ou transitions multi-materiaux.

Consequence: chaque sample terrain peut maintenant transporter jusqu'a 4 couches de materiaux normalisees. `BiomeSampler` derive ces couches de maniere deterministe depuis le voisinage biome en coordonnees monde. Le vertex buffer Metal transporte `splatWeights`, des indices de couches texture et des echelles UV.

Garantie: les tests verifient determinisme, normalisation, limite a 4 couches et raccord exact des splats entre chunks voisins.

Limite actuelle: les poids 4 couches sont prets dans les donnees et le buffer GPU. Ils pilotent un premier catalogue texture placeholder cote Metal, mais pas encore de vraies textures artistiques.

## 023 - Debug par couche splat

Decision: ajouter le mode `splatLayerWeight` et `terrainSplatDebugLayerIndex` dans les options de debug de rendu.

Raison: avant de brancher des textures, il faut pouvoir verifier chaque canal de poids splat separement dans la scene.

Consequence: l'overlay expose un index de couche 0-3. Le shader Metal lit `splatWeights[layerIndex]` et affiche une heatmap 0..1 pour la couche selectionnee.

Garantie: l'index est borne dans `RenderDebugOptions`, et les tests couvrent le mode, le clamp et la serialisation JSON.

## 024 - TerrainTextureCatalog placeholder

Decision: ajouter un `TerrainTextureCatalog` cote app/Metal avec un texture array genere en memoire pour les materiaux terrain de base.

Raison: avant d'integrer de vraies textures externes, le renderer doit deja avoir la forme d'un pipeline texture: IDs materiaux, UV terrain, texture array, sampler et mix par poids splat.

Consequence: le terrain normal n'utilise plus seulement les vertex colors. Le shader Metal echantillonne une couche placeholder par materiau et melange jusqu'a 4 couches avec `splatWeights`. Les modes debug continuent d'afficher les couleurs/heatmaps pour inspecter les biomes et les poids.

Limite actuelle: les textures sont des motifs 2x2 generes en code, sans PBR, normal map, roughness map, atlas disque ni streaming texture. Elles valident l'architecture et preparent le remplacement par des assets reels.

Prochaine cible: introduire un vrai contrat de material/texture slots plus explicite, puis remplacer les placeholders par un atlas ou texture array charge depuis les assets du projet.

## 025 - Material et texture slots explicites

Decision: ajouter les contrats neutres `RenderMaterial` et `TerrainTextureSlot` dans `EngineCore/Rendering`.

Raison: les shaders ne doivent pas dependre d'IDs flottants implicites ou d'un ordre de materiaux cache cote app. Les slots texture doivent etre declaratifs, serialisables et testables avant l'arrivee d'atlas, texture arrays artistiques ou normal maps.

Consequence: chaque couche `TerrainMaterialSplatLayer` porte maintenant un `RenderMaterial` et expose un `TerrainTextureSlot` avec `textureLayerIndex`, `uvScale` et `debugName`. `TerrainTextureCatalog` construit son texture array placeholder depuis ces slots. Le vertex buffer Metal transporte `splatTextureLayerIndices` et `splatUVScales` au lieu de simples material IDs.

Garantie: les tests EngineCore verifient la stabilite des indices de couches texture, la presence des slots et leur transport dans les couches splat.

Limite actuelle: `RenderMaterial` reste minimal. Il decrit les slots PBR terrain de base, mais pas encore les variantes detaillees comme height, displacement, emission, detail maps ou masks de blending avances.

## 026 - Texture slots PBR placeholders

Decision: etendre les contrats terrain avec `TerrainTextureMap` et `TerrainPBRTextureSlots` pour `albedo`, `normal`, `roughness` et `metallicAmbientOcclusion`.

Raison: le renderer Metal doit se rapprocher d'un pipeline PBR sans attendre l'arrivee de vraies textures externes. Les maps doivent etre explicites dans les contrats, pas implicites dans le shader ou le catalogue GPU.

Consequence: chaque `RenderMaterial` terrain expose maintenant ses slots PBR placeholders. `TerrainTextureCatalog` cree quatre texture arrays generes en memoire: albedo colore, normal flat, roughness grayscale et metallic/AO neutre. L'overlay affiche le nombre d'arrays texture terrain et le nombre de layers.

Garantie: les tests EngineCore verifient que chaque materiau terrain possede les quatre maps PBR, avec des indices de couches stables et des echelles UV coherentes.

Limite actuelle: les maps PBR sont encore des placeholders 2x2. Le shader reste volontairement simple et ne fait pas encore de normal mapping, BRDF PBR complete, image-based lighting ou texture streaming.

## 027 - DS_Store hors suivi Git

Decision: retirer `.DS_Store` de l'index Git et le laisser ignore par `.gitignore`.

Raison: le fichier est un etat local Finder/macOS qui change hors du projet et pollue `git status`.

Consequence: chaque clone peut garder son `.DS_Store` local sans le publier ni le voir comme changement versionne.

## 028 - Cadence debug explicite

Decision: le viewport Metal de debug demarre en `slowInspection` a 15 FPS, avec modes explicites `pausedInspection`, `liveGameplay` et `benchmark`.

Raison: le rendu debug a 60 Hz par defaut fausse les mesures et provoque des publications SwiftUI trop frequentes.

Consequence: le 60 Hz reste disponible, mais uniquement via `liveGameplay` ou `benchmark`; les metriques debug sont publiees a cadence reduite.

## 029 - AppShell comme entree applicative

Decision: l'app demarre sur `AppShellView` et une state machine `AppMode`, avec menu principal, debug world, loading mocke, real world et tools hub.

Raison: le renderer Metal ne doit pas etre actif dans le menu, le loading ou les outils. Les futurs systemes moteur doivent etre ouverts via des transitions explicites plutot que par un demarrage direct dans le monde.

Consequence: `GameRootView` reste le viewport monde, mais il est monte seulement depuis les modes runtime. Les prochaines etapes peuvent brancher `EngineCore`, save, jobs et generation reelle derriere le shell sans casser l'entree app.
