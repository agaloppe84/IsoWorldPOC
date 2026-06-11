# Baseline moteur V1

Ce document fixe la base active apres le Step 9-BIS. Il ne remplace pas les docs de recherche dans `docs/IsoWorld-Research-Lab/`; ces fichiers restent la vision long terme.

## Objectif

Construire la V1 sur un pipeline unique, testable et lisible:

```text
EngineCore data contracts
    -> WorldRuntime / RenderSnapshotBuilder
    -> RenderWorldSnapshot
    -> Metal buffers
    -> terrain PBR preview pipeline
```

Le code actif ne doit plus adapter ses noms, alias ou tests a l'ancien pipeline. Les compatibilites temporaires doivent etre retirees avant d'ajouter de nouvelles couches moteur.

## Contrats actifs

- `BiomeType` contient uniquement les biomes V1: `temperateForest`, `grassland`, `desert`, `mountain`, `marsh`, `taiga`, `coast`, `freshwater`.
- `TerrainMaterialKind` contient les materiaux terrain V1: `grass`, `rock`, `dirt`, `sand`, `mud`, `snow`.
- `PropType` contient les types de props V1: `rock`, `pebble`, `grass`, `tree`, `deadwood`, `crystal`.
- `StableRNG` est le generateur deterministe public du moteur.
- `LODPolicy` et `LODSelection` decrivent la visibilite et le niveau de detail des chunks avant upload GPU.
- `PropSystem` decrit les props naturels V1 depuis terrain, biome, seed, catalogue et regles de placement.
- `RenderWorldSnapshot` transporte les donnees neutres consommees par le renderer, sans dependance Metal ni option debug non consommee.
- `TerrainTextureCatalog.makePreview` genere les texture arrays temporaires de preview pour valider le pipeline PBR.

## Regles de hygiene

- Ne pas reintroduire d'alias legacy dans `EngineCore`.
- Ne pas ajouter de regle hardcodee cote renderer pour compenser un contrat moteur flou.
- Garder `EngineCore` independant de SwiftUI, RealityKit et Metal.
- Les tests doivent viser les contrats V1, pas les anciens noms.
- Les nouvelles metriques debug doivent avoir un consommateur clair dans l'overlay ou dans un snapshot.

## Plan d'action avant Step 10

- Verifier que les tests EngineCore couvrent les contrats V1 critiques.
- Verifier que le build et les tests Xcode passent via les wrappers safe.
- Garder l'overlay debug court: perf, jobs chunks, rendu Metal et position joueur.
- Ajouter les prochains travaux LOD au-dessus de `RenderWorldSnapshot` et des donnees chunk existantes, sans creer un chemin de rendu parallele.

## Step 10 livre

Step 10 introduit un LOD terrain/chunks baseline en gardant le meme flux:

```text
chunk data V1 -> snapshot V1 -> upload GPU -> passes Metal
```

La selection LOD reste deterministe et testable dans `EngineCore`. Le streamer applique un budget de chunks visibles et de props rendus, le snapshot transporte la selection, le renderer upload uniquement les chunks visibles et l'index buffer terrain suit le niveau LOD choisi.

## Step 11 livre

Step 11 ajoute les props naturels simples au-dessus du budget LOD:

- `EngineCore/Props` porte `PropSystem`, `PropCatalog`, `PropContext`, `PropPlacementRule`, `PropRecipe`, `PropVariantGenome` et `PropChunkData`.
- `PropCatalog.naturalV1` couvre rochers, cailloux, herbes, arbres, bois mort et cristaux.
- Le placement utilise biome, slope, moisture et walkability depuis `TerrainSampleGrid`.
- Les IDs de props sont stables via `StableID.prop`.
- Le renderer Metal bake `box`, `capsule` et `cone` dans le buffer props du chunk existant.

La V1 ne cree pas encore de GPU instancing dedie, d'imposteurs, de prop LOD par instance ou de debug placement interactif.

## Prochaine cible

## Step 12 livre

Step 12 remplace le loading cosmetique par un `WorldPreparePipeline` reel:

- `GameRuntime/WorldPrepare` contient `WorldPrepareRequest`, `WorldPreparePhase`, `LoadingProgress`, `WorldOpenRequirements` et `WorldPreparePipeline`.
- Le pipeline normalise le seed, genere `WorldDNA`, initialise les regles V1 et prepare terrain/biomes autour du spawn.
- Le spawn joueur est resolu depuis les samples terrain/biome.
- Les chunks initiaux sont generes avant ouverture avec le `WorldSeed` de la session.
- `WorldSession` transporte seed, `WorldDNA`, spawn, chunks initiaux et exigences d'ouverture.
- `WorldRuntime` et `ChunkDataStreamer` demarrent depuis la session preparee au lieu de refaire un demarrage froid avec le seed debug.
- La progression de loading est determinee par phases ponderees et l'annulation reste cooperative.

La V1 ne precompile pas encore les pipelines GPU Metal hors renderer. Le warmup Step 12 valide les payloads CPU critiques avant premiere frame.

## Prochaine cible

Step 13 peut ouvrir le `Tools Hub` minimal. Il doit rester data-driven et consommer les systemes V1 existants sans contourner `EngineCore`.
