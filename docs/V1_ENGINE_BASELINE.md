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
- `PropType` contient les types de props V1: `rock`, `tree`, `crystal`.
- `StableRNG` est le generateur deterministe public du moteur.
- `LODPolicy` et `LODSelection` decrivent la visibilite et le niveau de detail des chunks avant upload GPU.
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

## Prochaine cible

Step 11 peut ajouter les props naturels simples au-dessus de ce budget LOD. Les nouveaux props doivent respecter la selection LOD existante et ne pas creer de chemin d'instancing parallele sans contrat moteur.
