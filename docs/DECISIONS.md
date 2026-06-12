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

Consequence: les metriques debug exposent les signaux utiles au pipeline actif: frame time, generation de donnees chunk, upload, draw calls, textures terrain, chunks et props visibles.

Limites connues: generation synchrone, pas encore de LOD, pas encore de culling fin, pas encore de cache persistant; `visibleChunkCount` est actuellement equivalent aux chunks charges.

## 009 - Strategie texture terrain initiale

Decision historique: commencer avec un `TerrainMaterialDescriptor` pur dans `EngineCore` et une traduction simple vers un `SimpleMaterial` RealityKit par chunk.

Raison: differencier visuellement les biomes sans importer de grosses textures externes, sans multiplier excessivement les materiaux et sans toucher au streaming.

Consequence actuelle: les biomes exposent des materiaux semantiques simples (`grass`, `rock`, `dirt`, `sand`, `mud`, `snow` futur). Le rendu Metal utilise des couleurs vertex/material previews derivees de ces descriptors.

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

Limite actuelle: les poids 4 couches sont prets dans les donnees et le buffer GPU. Ils pilotent un premier catalogue texture preview cote Metal, mais pas encore de vraies textures artistiques.

## 023 - Debug par couche splat

Decision: ajouter le mode `splatLayerWeight` et `terrainSplatDebugLayerIndex` dans les options de debug de rendu.

Raison: avant de brancher des textures, il faut pouvoir verifier chaque canal de poids splat separement dans la scene.

Consequence: l'overlay expose un index de couche 0-3. Le shader Metal lit `splatWeights[layerIndex]` et affiche une heatmap 0..1 pour la couche selectionnee.

Garantie: l'index est borne dans `RenderDebugOptions`, et les tests couvrent le mode, le clamp et la serialisation JSON.

## 024 - TerrainTextureCatalog preview

Decision: ajouter un `TerrainTextureCatalog` cote app/Metal avec un texture array genere en memoire pour les materiaux terrain de base.

Raison: avant d'integrer de vraies textures externes, le renderer doit deja avoir la forme d'un pipeline texture: IDs materiaux, UV terrain, texture array, sampler et mix par poids splat.

Consequence: le terrain normal n'utilise plus seulement les vertex colors. Le shader Metal echantillonne une couche preview par materiau et melange jusqu'a 4 couches avec `splatWeights`. Les modes debug continuent d'afficher les couleurs/heatmaps pour inspecter les biomes et les poids.

Limite actuelle: les textures sont des motifs 2x2 generes en code, sans PBR, normal map, roughness map, atlas disque ni streaming texture. Elles valident l'architecture et preparent le remplacement par des assets reels.

Prochaine cible: introduire un vrai contrat de material/texture slots plus explicite, puis remplacer les previews generees par un atlas ou texture array charge depuis les assets du projet.

## 025 - Material et texture slots explicites

Decision: ajouter les contrats neutres `RenderMaterial` et `TerrainTextureSlot` dans `EngineCore/Rendering`.

Raison: les shaders ne doivent pas dependre d'IDs flottants implicites ou d'un ordre de materiaux cache cote app. Les slots texture doivent etre declaratifs, serialisables et testables avant l'arrivee d'atlas, texture arrays artistiques ou normal maps.

Consequence: chaque couche `TerrainMaterialSplatLayer` porte maintenant un `RenderMaterial` et expose un `TerrainTextureSlot` avec `textureLayerIndex`, `uvScale` et `debugName`. `TerrainTextureCatalog` construit son texture array preview depuis ces slots. Le vertex buffer Metal transporte `splatTextureLayerIndices` et `splatUVScales` au lieu de simples material IDs.

Garantie: les tests EngineCore verifient la stabilite des indices de couches texture, la presence des slots et leur transport dans les couches splat.

Limite actuelle: `RenderMaterial` reste minimal. Il decrit les slots PBR terrain de base, mais pas encore les variantes detaillees comme height, displacement, emission, detail maps ou masks de blending avances.

## 026 - Texture slots PBR preview

Decision: etendre les contrats terrain avec `TerrainTextureMap` et `TerrainPBRTextureSlots` pour `albedo`, `normal`, `roughness` et `metallicAmbientOcclusion`.

Raison: le renderer Metal doit se rapprocher d'un pipeline PBR sans attendre l'arrivee de vraies textures externes. Les maps doivent etre explicites dans les contrats, pas implicites dans le shader ou le catalogue GPU.

Consequence: chaque `RenderMaterial` terrain expose maintenant ses slots PBR preview. `TerrainTextureCatalog` cree quatre texture arrays generes en memoire: albedo colore, normal flat, roughness grayscale et metallic/AO neutre. L'overlay affiche le nombre d'arrays texture terrain et le nombre de layers.

Garantie: les tests EngineCore verifient que chaque materiau terrain possede les quatre maps PBR, avec des indices de couches stables et des echelles UV coherentes.

Limite actuelle: les maps PBR sont encore des previews 2x2. Le shader reste volontairement simple et ne fait pas encore de normal mapping, BRDF PBR complete, image-based lighting ou texture streaming.

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

## 030 - Biome fields pondérés

Decision: deplacer les biomes dans `EngineCore/Biomes` et selectionner les biomes via des fields climatiques pondérés top-2.

Raison: les biomes doivent piloter terrain, materiaux, props et futurs ecotones sans rester un enum unique choisi par seuils ad hoc.

Consequence: `BiomeSystem` produit `ClimateSample`, `BiomeWeights`, `BiomeChunkData` et des valeurs de debug. Les 8 biomes V1 sont explicites: foret temperee, prairie, desert, montagne, marais, taiga, cote et eau douce.

Garantie: les tests verifient les 8 biomes, la normalisation top-2, le chunk data branche sur terrain, les ecotones et les debug layers.

## 031 - Materials/PBR terrain V1

Decision: introduire un contrat `EngineCore/Materials` et isoler les shaders/bindings terrain PBR cote Metal.

Raison: les materiaux doivent devenir des donnees moteur testables avant l'arrivee de textures artistiques, de variants d'etat de surface et d'un lighting plus avance.

Consequence: `SurfaceDescriptor`, `MaterialParameterBlock`, `SurfaceState` et `IsoMaterialRuntime` decrivent un `OpaquePBR` minimal. Le renderer Metal utilise une `MaterialBindingTable`, quatre texture arrays PBR preview, un shader terrain layeré avec triplanar sur pentes fortes, une lumiere directionnelle, un IBL sky simple, du tone mapping et des vues debug roughness/normal.

Garantie: les tests couvrent les bindings PBR terrain, l'application d'etats de surface, les nouveaux modes debug et la stabilite des indices Metal.

Limite actuelle: la normal map est encore une lecture preview et n'altere pas la normale monde. Les textures restent generees en memoire; les assets PBR reels, le streaming texture et une BRDF plus complete viendront dans une etape ulterieure.

## 032 - Baseline V1 propre apres Step 9-BIS

Decision: retirer les alias et patterns legacy du pipeline actif avant d'ouvrir les travaux LOD.

Raison: la V1 doit avancer sur une architecture unique. Les noms de transition, alias de coordonnees, alias de biomes et anciens generateurs rendaient le moteur plus difficile a tester et entretenaient deux vocabulaires.

Consequence: le code actif utilise les noms V1, les snapshots ne transportent plus d'option debug non consommee, l'overlay debug est recentre sur perf/world/render et le renderer Metal consomme le pipeline material/texture V1.

Garantie: les tests EngineCore et Xcode doivent couvrir la serialisation des snapshots, les biomes V1, les splats terrain, les slots PBR, les payloads Metal et le rendu app avant Step 10.

## 033 - LOD baseline chunks/terrain

Decision: introduire un LOD classique dans `EngineCore/LOD` et le brancher au streaming de chunks avant l'upload GPU.

Raison: avant d'ajouter davantage de props ou de densite visuelle, le moteur doit savoir distinguer chunks candidats, chunks visibles, chunks culles et niveau de detail. La V1 doit rester simple, deterministe et debuggable.

Consequence: `ChunkDataStreamer` utilise un rayon candidat de 2 chunks, applique `LODPolicy.chunkBaseline`, budgete les chunks visibles et expose `LODFrameStats`. `RenderChunk` transporte sa `LODSelection`, `RenderPayloadUploader` ignore les chunks non visibles et `MetalChunkBuffers` construit un index buffer terrain adapte au niveau LOD.

Garantie: les tests couvrent selection par distance, hysteresis, screen error, stats LOD et indices terrain edge-preserving.

Limite actuelle: pas encore de HLOD, occlusion culling GPU, meshlets, indirect draw, collision LOD avancee ou instancing GPU dedie.

## 034 - Props naturels V1 par PropSystem

Decision: introduire `EngineCore/Props` comme facade V1 pour les props naturels simples, branchee sur le pipeline chunk existant.

Raison: Step 11 doit augmenter la densite visible sans recreer une architecture parallele de rendu ou d'instancing. Les decisions de placement doivent utiliser le terrain et les biomes deja disponibles, rester deterministes et produire des donnees inspectables.

Consequence: `PropSystem` produit `PropChunkData` depuis `TerrainSampleGrid`, biome et seed. Le catalogue naturel V1 couvre rochers, cailloux, herbes, arbres, bois mort et cristaux. Les regles de placement scorent biome, slope, moisture et walkability. `ProceduralChunkDataFactory` consomme ce chunk data et le renderer Metal bake les shapes `box`, `capsule` et `cone` dans le buffer props de chunk existant.

Garantie: les tests couvrent catalogue naturel, determinisme, filtrage terrain, IDs stables, alignement sur le stride terrain et bake Metal des shapes naturelles.

Limite actuelle: pas encore de GPU instancing dedie, prop LOD par instance, imposteurs, billboards, collisions detaillees, animation de vegetation ou debug placement interactif.

## 035 - WorldPreparePipeline reel avant ouverture monde

Decision: introduire un `WorldPreparePipeline` V1 progressif, pondere et annulable qui produit une `WorldSession` complete avant de passer en mode `realWorld`.

Raison: le bouton de generation ne doit pas afficher un faux loading ni ouvrir un monde froid. La V1 doit garantir que le seed utilisateur, le `WorldDNA`, les regles V1 et les chunks initiaux sont prets avant la premiere frame.

Consequence: les types `WorldPrepareRequest`, `LoadingProgress`, `WorldPreparePhase`, `WorldOpenRequirements` et `WorldPreparePipeline` vivent dans `GameRuntime/WorldPrepare`. `WorldSession` transporte `worldSeed`, `WorldDNA`, `spawnPosition`, `initialChunks` et les exigences d'ouverture. `ChunkDataStreamer`, `WorldRuntime`, `GameRootView`, `MetalGameView` et `MetalRenderer` acceptent maintenant cette session pour demarrer depuis les donnees preparees.

Garantie: les tests Xcode couvrent la creation d'une session preparee, les exigences d'ouverture, la progression jusqu'a `openSession` et le demarrage du runtime depuis le seed/chunks de session.

Limite actuelle: le warmup renderer valide les payloads CPU critiques, mais la precompilation explicite de pipelines GPU Metal reste dans `MetalRenderer` et sera traitee plus tard.

## 036 - Perf baseline et isolation debug Step 12-BIS

Decision: separer les profils `realWorld` et `debugWorld`, puis faire passer les toggles d'isolation par le pipeline V1 complet.

Raison: une chute a 15 FPS sans outils d'isolation fiables est trop floue pour avancer proprement. Le vrai monde ne doit pas afficher d'outils debug, tandis que le monde debug doit permettre de couper terrain, props, player, bounds, simulation, streaming et LOD pour localiser le cout.

Consequence: `DebugMetrics` porte les toggles et timings utiles, `RenderSnapshotBuilder` les convertit en `RenderDebugOptions`, `FrameGraph` active les passes selon les couches rendues, `RenderPayloadUploader` evite les uploads chunks quand ils ne sont pas necessaires et `MetalRenderer` publie les couts simulation/snapshot/sync/encode et les estimations memoire.

Garantie: les tests verifient les flags `RenderDebugOptions`, le profil Real World sans chunk bounds et les flags terrain/props envoyes aux uniforms Metal.

Limite actuelle: les mesures restent CPU-side et approximatives pour la memoire GPU. Un profiling Metal plus fin pourra arriver quand les passes seront plus nombreuses.

## 037 - Diagnostic MTKView/SwiftUI Step 12-TER

Decision: mesurer la boucle complete de rendu et le detail du snapshot avant toute optimisation renderer.

Raison: les tests manuels montrent une chute FPS alors que `buffer sync` et `encode` restent tres bas. Il faut distinguer cout reel de `draw(in:)`, intervalle entre callbacks MTKView, publication `@Published`, scheduling main thread et reconstruction snapshot.

Consequence: l'overlay affiche `frame raw`, `draw`, `gap`, `publish`, `unaccounted` et le detail `snapshot active/chunks/props/sample`. Un toggle `pause metrics publish` permet de figer les updates SwiftUI. `render props` coupe maintenant la conversion des props dans le snapshot pour isoler ce cout en amont du renderer.

Garantie: les tests Xcode couvrent le stockage des metriques de boucle et l'absence de props dans le snapshot quand `renderProps` est desactive.

Limite actuelle: les mesures restent faites sur le main thread de l'app. Elles isolent la zone du probleme, mais ne remplacent pas encore un profil Instruments/Metal System Trace.

## 038 - Telemetry SwiftUI decouplee Step 12-QUATER

Decision: publier une seule structure `DebugTelemetry` par tick debug au lieu de publier chaque metrique haute frequence individuellement.

Raison: les tests manuels ont montre que `pause metrics publish` rendait le monde nettement plus fluide, avec un cout `publish` autour de 70 ms alors que le rendu Metal restait faible. Le renderer ne doit pas etre ralenti par une rafale de mutations `@Published` SwiftUI pendant la frame.

Consequence: `DebugMetrics` separe les controles utilisateur, qui restent `@Published`, des champs de telemetry de frame, qui deviennent des valeurs de staging. `MetalRenderer` appelle `publishTelemetry()` une seule fois apres avoir renseigne les timings et compteurs. `DebugOverlayView` lit `metrics.telemetry` pour l'affichage.

Garantie: les tests Xcode verifient que les timings de boucle sont exposes via `DebugTelemetry` apres publication explicite.

Limite actuelle: la telemetry reste publiee depuis le main thread car le renderer macOS vit encore dans la boucle MTKView/SwiftUI. Un profil Instruments reste utile si la cadence reste basse apres ce decouplage.

## 039 - Store dedie pour telemetry debug Step 12-QUINQUIES

Decision: deplacer la publication de telemetry dans un `DebugTelemetryStore` separe de `DebugMetrics`.

Raison: apres le premier decouplage, les tests manuels montraient encore environ 70 ms de cout `publish` avec l'overlay visible. La cause probable etait l'invalidation SwiftUI de `GameRootView`, de `MetalGameView` et du panneau complet a chaque update de chiffres.

Consequence: `DebugMetrics` reste l'objet observable des controles utilisateur, tandis que `DebugTelemetryStore` est observe uniquement par les vues texte de telemetry. L'overlay rend les valeurs dynamiques sous forme de blocs texte monospaced pour reduire le nombre de sous-vues SwiftUI reconstruites par tick.

Garantie: le build Xcode valide le split SwiftUI et les tests continuent de verifier que la telemetry publiee expose les timings de frame.

Limite actuelle: si le cout `publish` reste eleve, le prochain niveau sera de rendre le debug HUD hors SwiftUI, par exemple via AppKit leger ou via une passe Metal/HUD dediee.

## 040 - Cache snapshot chunks Step 12-SNAPSHOT-CACHE

Decision: rendre `RenderSnapshotBuilder` stateful et cacher les `RenderChunk` stables entre deux frames.

Raison: les mesures manuelles montrent que la chute FPS existe aussi en Real World sans overlay debug. Le cout suspect est donc partage par le runtime monde et le debug. Le snapshot reconstruisait les chunks actifs et leurs props a chaque frame, y compris des chunks non visibles, alors que la plupart des payloads terrain/props restent identiques entre deux frames.

Consequence: `RenderSnapshotBuilder` devient une classe `@MainActor` avec un cache par `ChunkCoordinate`. La signature de cache inclut les donnees qui changent le payload de rendu: etat debug du chunk, visibilite, niveau LOD, rendu des props et chunk bounds. Le snapshot emis ne transporte que les chunks visibles necessaires au rendu courant, et les props invisibles ne sont plus samplees.

Garantie: les tests Xcode verifient qu'une frame stable reutilise le cache, que le snapshot ne contient que des chunks visibles et que la conversion props retombe a zero sur la frame cachee.

## 041 - Frame driver explicite Step 12-FRAME-DRIVER

Decision: separer le profil Real World du profil Debug World et ne plus laisser la boucle interne de `MTKView` etre l'unique source de cadence continue.

Raison: les mesures manuelles montrent `draw(in:)` autour de quelques millisecondes, alors que `frame raw` et `gap` montent fortement. Le renderer n'est donc pas sature; le probleme vient du scheduling main thread, de la publication SwiftUI ou de la maniere dont la `MTKView` est reveillee.

Consequence: `GameRootView` desactive la publication debug quand il n'affiche pas l'overlay. `MetalRenderer` ignore completement `updateDebugMetrics()` dans ce profil. `DebugCadenceController` garde la `MTKView` pausee et planifie les frames explicitement pour les modes continus, ce qui rend le comportement identique entre redraw clavier, redraw on-demand et live gameplay.

Garantie: les tests unitaires verifient que le Real World ne publie pas de telemetry debug par defaut. Les validations automatiques doivent eviter la suite UI Xcode complete tant qu'elle ne teste que les lancements de l'interface de base.

## 042 - Debug overlay compact Step 12-DEBUG-LEAN

Decision: faire du Debug World un outil leger par defaut, avec details opt-in.

Raison: les tests manuels confirment que Real World devient nettement plus fluide sans publication debug, tandis que Debug World reste plus lourd meme quand le moteur est peu couteux. L'overlay SwiftUI, le layout de nombreuses lignes de telemetry et les chunk bounds doivent donc etre traites comme du debug couteux.

Consequence: `DebugMetrics` demarre avec `showChunkBounds` et `showDebugDetails` a `false`. `DebugOverlayView` affiche un bloc perf compact et garde les details snapshot/player/chunks derriere un toggle. La cadence de publication telemetry descend a 2 Hz en debug live/slow et 1 Hz en benchmark.

Garantie: les tests unitaires verrouillent les defaults lean et la cadence de refresh debug.

## 043 - Tools Hub minimal Step 13

Decision: creer le `Tools Hub` comme surface data-driven separee du monde runtime.

Raison: les generateurs V1 doivent pouvoir etre inspectes sans ouvrir un vrai monde, sans demarrer `WorldRuntime` et sans ajouter de dependance debug au renderer principal.

Consequence: `ToolRegistry.v1` declare les outils initiaux, `ToolDocument` porte les parametres de travail, la validation reste locale au hub et les previews produisent un `ToolPreviewSnapshot` EngineCore deterministe sans payload monde.

Garantie: les tests verifient l'inventaire des outils Step 13, la preview deterministe et la transition AppStore avec `ToolSession` mais sans `WorldSession`.

## 044 - Terrain FeatureGraph et hydrologie V1

Decision: ajouter un `TerrainFeatureGraph` deterministe dans `EngineCore` et le faire consommer par `DefaultTerrainFieldProvider`.

Raison: le terrain V1 ne doit plus etre uniquement une somme de bruits. Il doit commencer a exprimer des structures lisibles: ranges de montagne, rivieres continues, lacs, falaises, masques d'eau et materiaux de berge.

Consequence: les features restent des donnees moteur pures, queryables par chunk et independantes de Metal/SwiftUI. Les samples terrain transportent `waterDepth` et `TerrainFeatureMasks`, puis les masks influencent hauteur, humidite, walkability, climbability et splats de materiaux shore.

Garantie: les tests EngineCore couvrent familles de features, determinisme, query chunk, carving de riviere, masks hydrologie, continuite aux bords de chunks, debug layers et coverage validation.

## 045 - Verticalite gameplay V1

Decision: ajouter une couche `EngineCore/Traversal` pure pour classifier les surfaces et produire les premieres affordances verticales.

Raison: le terrain feature-driven doit devenir lisible par le gameplay avant d'ajouter escalade, cordes ou escaliers reels. Les regles de marche, danger, paroi et attachement ne doivent pas etre hardcodees dans le renderer ou dans le player.

Consequence: chaque `TerrainSampleGrid` peut produire un `TraversalChunkData` contenant `ClimbabilityMap`, surface classes, ledges, anchors de corde, attaches d'escalier et routes verticales candidates. `ProceduralChunkData` transporte cette data jusqu'au runtime, et le grounding joueur utilise `TraversalSurfaceClass` quand elle est disponible.

Garantie: les tests EngineCore couvrent classification, candidats verticaux, determinisme, continuite de classes aux bords de chunks, debug layers et validation report. Un test app verifie que le grounding respecte une surface `blocked`.

## 046 - Base personnage procedurale V1

Decision: ajouter `EngineCore/Characters` comme contrat pur pour generer, personnaliser et sauvegarder un personnage V1.

Raison: le joueur ne doit pas rester un cube hardcode cote app pendant que le moteur V1 avance. Il faut un ADN deterministe, une morphologie canonique, des sockets, des slots d'equipement et un etat runtime avant de brancher animation, vetements et gameplay corps.

Consequence: `CharacterDNA` derive depuis `WorldSeed`, `GeneratorVersionTable` et le domaine `.characters`. La morphologie expose skeleton, sockets, capsule collision et vitesse naturelle. L'apparence et l'equipement portent des materiaux PBR neutres. `CharacterRuntimeState` separe l'etat vivant de l'ADN regenerable, et `CharacterCustomizationSave` peut etre stocke dans `PlayerProfile`.

Garantie: les tests EngineCore couvrent determinisme/versioning, clamping morphologique, skeleton/sockets, remplacement d'equipement, LOD, roundtrip de sauvegarde et conservation dans le profil joueur. Un test app verifie que `WorldRuntime` cree la DNA joueur depuis le seed de session preparee.

Limite actuelle: le renderer affiche encore le preview joueur simple. Le mesh skinned, les vetements visibles et l'animation complete doivent consommer ces contrats dans les steps suivants.

## 047 - Animation contact terrain V1

Decision: ajouter `EngineCore/Animation` comme couche IsoMotion V1 pure, branchee sur terrain, traversal et personnage.

Raison: les futurs FX/audio/HUD et le rendu personnage ont besoin d'evenements et de contacts stables. Le joueur ne doit pas seulement suivre une hauteur terrain; il doit produire une pose, des appuis, une friction, une wetness, un verrouillage de pied et des events de pas depuis les donnees moteur V1.

Consequence: `TerrainSampleGrid` est conserve dans le chunk runtime. `SurfaceContactResolver` transforme les samples terrain en `ContactPatch`. `AnimationSampler`, `FootIKSolver`, `CharacterMotor` et `FootstepEventEmitter` fournissent les contrats minimums pour locomotion, foot IK, motor capsule et events materiau-aware. `PlayerController` met a jour ces donnees sans les rendre encore visuellement.

Garantie: les tests EngineCore couvrent sampler, contacts materiaux, foot IK, motor et footstep events. Un test app verifie que `WorldRuntime` produit des contacts animation joueur depuis un terrain prepare.

Limite actuelle: pas encore de mesh skinned anime, de debug draw animation, de footstep planner avance, d'audio ou de FX. Ces couches doivent consommer les contracts Step 17 au lieu de recalculer les surfaces.

## 048 - FX data-driven V1

Decision: ajouter `EngineCore/FX` comme contrat pur pour les effets de contact et faire transiter les FX par `RenderWorldSnapshot`.

Raison: la poussiere, les splashs, les sparks et les decals doivent venir des memes donnees que locomotion, terrain et materiaux. Le renderer ne doit pas inventer les surfaces ni adapter des patterns legacy; il doit consommer des events/particules/decals budgetes par le pipeline V1.

Consequence: `FXRecipe` convertit les `FootstepEvent` et impacts en `FXEvent`, `FXBillboardParticle` et `FXDecal` depuis `TerrainMaterialKind`, wetness, friction et `WorldSeed`. `FXBudget` plafonne events, particules et decals. `WorldRuntime` garde un `FXFrameState`, avance les lifetimes, puis injecte un `FXFrameSnapshot` dans `RenderWorldSnapshot`. `FrameGraph` contient maintenant `DecalPass` et `BillboardParticlePass` entre opaque et debug overlay.

Garantie: les tests EngineCore couvrent determinisme, dust/splash, sparks, budget et expiration. Les tests app verrouillent l'ordre du frame graph et l'activation des passes FX depuis le snapshot.

Limite actuelle: le rendu FX est une V1 legere avec quads alpha sur le shader opaque. Les prochaines passes pourront ajouter instancing, atlas sprites, decals projetes et compute particles sans changer le contrat EngineCore.

## 049 - Audio procedural V1

Decision: ajouter `EngineCore/Audio` comme contrat pur et garder la sortie audio systeme hors scope du Step 19.

Raison: l'audio doit consommer les memes contacts, materiaux et seeds que l'animation et les FX, sans recalculer de surface dans le renderer ou dans SwiftUI. Brancher trop tot une sortie bas niveau melangerait scheduling audio, AVAudioEngine/CoreAudio et contrats moteur avant que les recipes soient stabilisees.

Consequence: `AudioRecipeResolver` transforme les `FootstepEvent` en `IsoAudioEvent` materiau-aware. `AudioRuntime` fournit queue priorisee, sample player procedural, noise synth deterministe, bus meters et `IsoAudioEngine`. `WorldRuntime` poste les events audio apres la simulation/FX et conserve un `AudioRuntimeSnapshot` interne.

Garantie: les tests EngineCore couvrent determinisme, switching materiau, surfaces wet/squish, parametres et mix bus. Les tests app couvrent queue, synthese deterministe et meters par bus.

Limite actuelle: aucun son n'est encore joue par macOS. La prochaine passe audio pourra ajouter une sortie temps reel en gardant les contrats Step 19 intacts.

## 050 - UI/HUD procedural minimal V1

Decision: ajouter un modele UI pur dans `EngineCore` et rendre le HUD in-game via une passe Metal dediee.

Raison: SwiftUI reste excellent pour menus, tools et debug, mais les tests perf precedents ont montre que les publications et layouts SwiftUI peuvent perturber la cadence du monde. Le HUD gameplay doit consommer le meme pipeline V1 que le renderer: snapshot stable, draw commands batchables, aucune requete directe aux systemes runtime.

Consequence: `UIFrameSnapshot` transporte player health/stamina, biome, meteo et prompt terrain. `UIWorldDNA` choisit un theme deterministe parmi neutral, parchment et sci-fi. `RenderWorldSnapshot` expose cette data au `FrameGraph`, puis `HUDOverlayPass` encode panels, labels, icones et progress bars via `UIMetalRenderer`.

Garantie: les tests EngineCore couvrent determinisme UI, themes et snapshot HUD. Les tests app couvrent l'activation du pass HUD, le batching de commandes et la production du snapshot UI depuis une session monde preparee.

Limite actuelle: le HUD est volontairement minimal: quads, atlas icones 5x5 et labels bitmap. Pas encore de retained UI, input routing in-game, layout editor, atlas texture ou typographie avancee.

## 051 - RPG DNA comme constitution de monde

Decision: remplacer le `WorldRPGDNA` minimal historique par un module `EngineCore/RPG` pur et versionne.

Raison: le seed doit definir autre chose que terrain, props et rendu. Avant d'ajouter settlements, NPCs, quetes ou director, le moteur a besoin d'un contrat central qui dit quel type de monde existe: archetype, epoque, tech, magie, menace, ennemis, objectif, progression, factions et tags gameplay.

Consequence: `WorldDNA.rpg` consomme le nouveau `WorldRPGDNA`. `WorldRuleset` derive les systemes actifs, la politique de violence, l'objectif primaire, les factions et les quest seeds. Les sous-domaines RPG ont leurs seeds/versioning propres pour eviter les cascades instables.

Garantie: les tests EngineCore couvrent determinisme, roundtrip Codable, versioning RPG, ruleset executable, mondes sans ennemis, ledger compact et 20 seeds de reference RPG jouables.

Limite actuelle: pas encore de runtime story director, NPCs, settlements reels, storylets ou sauvegarde gameplay complete. Ces systemes devront consommer le ruleset et le ledger au lieu de dupliquer les decisions de monde.

## 052 - Settlements V1 terrain-aware

Decision: ajouter `EngineCore/Settlements` comme pipeline pur pour generer des plans de settlements et buildings adaptes au terrain.

Raison: les structures ne doivent pas etre posees sur un carre plat ni contourner le RPG DNA. Le moteur a besoin d'un contrat intermediaire entre terrain/biome/RPG et rendu: site, recipe, intent, footprint, support terrain, massing et instance render.

Consequence: `SettlementSystem` consomme `TerrainSampleGrid` et `WorldRuleset`, derive une `TerrainSupportMap`, choisit une `SettlementRecipe`, selectionne un site, genere `BuildingIntent`, `BuildingFootprint`, `BuildingMassing`, chemins simples et `StructureRenderInstance`. Les sous-domaines settlements ont leur propre versioning.

Garantie: les tests EngineCore couvrent determinisme, roundtrip Codable, classification support terrain, selection de site, footprints bornes au chunk, massing renderable, influence RPG, versioning et seeds de reference.

Limite actuelle: les plans de settlements ne sont pas encore injectes dans le runtime monde ni rendus par Metal. Ce branchement doit consommer les instances V1, pas recalculer une logique de placement cote app.

## 053 - Save avancee V2 par contrats purs

Decision: ajouter les contrats de sauvegarde avancee dans `EngineCore/Persistence` avant de brancher un writer disque complet.

Raison: le monde vivant, les outils et les assets edits ne doivent pas etre persistes en serialisant des caches de rendu ou des objets app. Le moteur a besoin d'un format stable: chunks sales, deltas regionaux, entites persistantes, journal, snapshots, migrations et packages outils/assets/graphs.

Consequence: `SaveVersion.current` passe en schema 2. `DirtyTracker`, `RegionDeltaStore`, `EntityStateStore`, `EventJournal`, `SnapshotStore`, `MigrationManager`, `ToolProjectPackage`, `AssetPackage` et `GraphPackage` deviennent les contrats sources. Les chemins cibles restent declaratifs (`.isoregion`, `.isosnapshot`, `.isoproj`, `.isoasset`, `.isograph`), sans dependance SwiftUI, Metal ou SQLite.

Garantie: les tests EngineCore couvrent grouping de dirty chunks, merge de deltas, tombstones d'entites, journal compactable, retention snapshots, migration schema 1 vers 2 et roundtrip des packages outils/assets/graphs.

Limite actuelle: pas encore d'autosave incremental branche au runtime, pas de WAL, pas de SQLite et pas de stockage disque des deltas. Ces couches doivent consommer les contrats Step 23 sans changer leur forme.

## 054 - Tools Hub production spine V2

Decision: faire demarrer la V2 par un Tools Hub package-backed, sans ouvrir de `WorldRuntime`.

Raison: les futurs editeurs V2 doivent modifier, valider et persister des recettes, graphs et assets sans polluer le vrai monde ni serialiser des caches de rendu. Le hub doit donc posseder un workspace propre avant les editeurs specialises.

Consequence: `ToolRegistry.v2` expose les 15 outils du Step 24. `ToolWorkspace` porte la selection, les documents par outil, les recents, le dirty state, les snapshots de revision et le diagnostic export. `ToolDocumentStore` convertit les documents en `ToolProjectPackage`, `GraphPackage` et `AssetPackage`, puis les sauvegarde/lit via `AtomicFileWriter`.

Garantie: les tests app couvrent le registry V2, le workspace dirty/recent/diagnostic, l'ouverture du hub sans session monde, l'isolation preview et le roundtrip `.isoproj` / `.isoasset` / `.isograph`.

Limite actuelle: les 15 outils sont branches comme surfaces production generiques avec preview/validation/packages. Les vrais editeurs specialises (terrain graph authoring, material editing, save inspector connecte, seed lab complet, etc.) restent a livrer dans Step 24-B et suivants.

## 055 - Rapports specialises prioritaires Step 24-B

Decision: introduire `ToolSpecializedPreviewReport` comme couche app-side pour les premiers inspectors metier du Tools Hub V2.

Raison: les outils prioritaires doivent afficher des donnees utiles sans ouvrir de `WorldRuntime` et sans inventer un format parallele. Le hub peut consommer les contrats purs existants et les presenter comme sections/metriques codables avant de livrer les editeurs interactifs complets.

Consequence: Terrain Recipe Editor, Biome Graph Viewer, Prop Gallery, Material Viewer, LOD Debugger, Save Inspector et Seed Gallery ont des rapports specialises. Ces rapports lisent `TerrainFeatureGraph`, biomes/ecotones/sub-biomes, `PropCatalog`, materiaux/surfaces PBR, `LODPolicy`, packages Step 23 et `GoldenWorldSeeds`. Les autres outils restent en fallback generique explicite jusqu'au Step 24-C.

Garantie: les tests app verifient la couverture des outils prioritaires, les metriques terrain issues du `TerrainFeatureGraph`, les chemins/validations `.isoproj` / `.isograph` / `.isoasset` du Save Inspector et le corpus `GoldenWorldSeeds`.

Limite actuelle: les rapports sont consultatifs. Ils ne modifient pas encore les graphs, recettes ou packages; les vrais controls d'edition, validators metier profonds et runners golden seeds arrivent ensuite.

## 056 - Couverture specialisee complete Step 24-C

Decision: couvrir les 15 outils Step 24 avec des rapports specialises et brancher un premier runner golden seeds.

Raison: avant d'ouvrir des graph editors plus lourds, le Tools Hub doit prouver que chaque domaine majeur sait lire ses vrais contrats V2 sans ouvrir de `WorldRuntime`. Les outils restants avaient encore un fallback generique; cela masquait les dependances reelles et retardait la validation cross-domain.

Consequence: Character Customization Lab, Animation Contact Lab, FX Preview Editor, Audio Graph Preview, RPG World DNA Browser, Settlement Viewer, Performance HUD et Snapshot Diff consomment maintenant leurs contrats metier. `ToolGoldenSeedValidationRunner` verifie le corpus `GoldenWorldSeeds` sur terrain, personnages, animation, FX, audio, RPG, settlements et LOD. `ToolRegistry.validate` branche ce runner pour Seed Gallery.

Garantie: les tests app verifient que tous les descriptors `ToolRegistry.v2` ont un rapport specialise, que les outils restants exposent des metriques issues des vrais contrats, que le runner golden seeds est vert et que Seed Gallery remonte le hook de validation.

Limite actuelle: les rapports restent consultatifs et legers. Ils ne remplacent pas encore des editeurs interactifs de graph, des previews Metal dediees ni des validators profonds par domaine. La prochaine couche doit brancher la persistence production avant d'alourdir les outils.

## 057 - Spine persistence production Step 24-BIS

Decision: introduire une couche d'orchestration persistence dans `EngineCore/Persistence` sans attendre SQLite ni le branchement runtime complet.

Raison: les contrats Step 23 etaient propres mais encore passifs. La V2 a besoin d'un chemin de commit testable qui ecrit les deltas regionaux, le journal et les snapshots avec une autorite claire, sans serialiser des caches de rendu ni coupler SwiftUI au moteur.

Consequence: `PersistenceRegistry.productionV2` declare les domaines autoritatifs et rebuildables. `RegionDeltaFileStore` fournit le writer/reader `.isoregion`. `SaveCoordinator` est un acteur qui orchestre save manuel et autosave incremental budgete: ecriture des regions, journalisation, snapshot retention/index, puis manifest final. `SaveFilesManifest` expose les chemins V2 production, dont `events/journal.json`.

Garantie: les tests EngineCore couvrent le registry, le roundtrip `.isoregion`, le dirty tracking de scope partiel, le chemin manuel manifest-last et l'autosave debounced/budgete. Le build Xcode macOS compile l'app avec ces contrats.

Limite actuelle: la tranche core ne branchait pas encore `state.sqlite`, WAL, CAS blob store, tests crash/recovery, Save Inspector connecte aux vraies donnees disque ni integration save/load runtime. Ces sujets composent la tranche 24-BIS-B et le branchement runtime suivant.

## 058 - SQLite WAL, CAS et recovery comme index rebuildable

Decision: ajouter `state.sqlite`, WAL, CAS blob store, recovery scanner et Save Inspector reel sans faire de SQLite la source de verite du monde.

Raison: la sauvegarde V2 doit pouvoir interroger vite entities/events/regions/snapshots/blobs et diagnostiquer les saves, mais le format durable doit rester lisible et reconstructible: manifest, deltas regionaux, journal, snapshots et blobs. SQLite est donc un index rebuildable, pas le coeur de la save.

Consequence: `EngineCore` depend d'un petit target C `CSQLite` lie a `sqlite3`. `SQLiteStateIndexStore` cree `state.sqlite`, active WAL, ecrit dans une transaction et expose un summary. `CASBlobStore` stocke les payloads par hash stable. `SaveCoordinator` ecrit regions, CAS, snapshots, journal et SQLite avant `manifest.json`. `SaveRecoveryScanner` detecte les artefacts non commit et peut les nettoyer. `SaveInspector` lit un vrai dossier de save, et le Save Inspector du Tools Hub consomme ces donnees via une reference `saveRoot:/chemin`.

Garantie: les tests EngineCore couvrent CAS, SQLite/WAL, crash injecte avant commit manifest, rollback des artefacts non commit et migration lab. Le build Xcode `build-for-testing` compile app + tests avec SQLite sans executer l'UI.

Limite actuelle: le vrai `WorldRuntime` ne collecte pas encore ses deltas vers `SaveCoordinator` et ne recharge pas encore un slot complet. La prochaine tranche doit brancher ce roundtrip gameplay avant d'attaquer les surfaces/lighting Step 25.
