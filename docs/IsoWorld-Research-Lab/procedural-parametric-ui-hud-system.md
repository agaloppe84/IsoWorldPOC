# IsoWorld — Système d’interface / HUD procédural et paramétrique

> **Nouveau step — Gestion interface/HUD procédural**  
> Sujet couvert uniquement : architecture moderne pour une interface et un HUD qui changent selon l’ambiance du monde, les règles du seed, les biomes, l’époque, le niveau technologique, la faction, la météo, la dangerosité, les états RPG et le contexte joueur.

---

## 0. Résumé exécutif

IsoWorld ne doit pas avoir une interface figée. Comme le monde, les props, les biomes, les règles RPG et les FX sont déterministes et procéduraux, le HUD doit devenir un **système vivant**, dérivé d’un **UI DNA** généré par seed.

L’objectif n’est pas seulement de recolorer des boutons. Le seed doit pouvoir produire des interfaces qui semblent venir d’univers complètement différents : carnet de voyage médiéval, HUD militaire tactique, interface biotech organique, menu futuriste holographique, système spirituel à glyphes, UI de survie primitive, interface de colonie spatiale, tablette low-tech bricolée, OS corporate dystopique, grimoire magique, dispositif steampunk, interface alien, etc.

La recommandation principale est une architecture **hybride** :

1. **SwiftUI / AppKit pour le shell macOS**  
   Menus système, fenêtres de debug avancées, préférences, launcher, outils d’édition hors-jeu, accessibilité native, saisie texte complexe, panneaux de configuration, inspecteurs.

2. **Renderer UI custom Metal pour le HUD in-game**  
   HUD gameplay, overlays diegetiques, transitions thématiques, animations procédurales, rendu vectoriel/bitmap/mesh, SDF text/icons, particules UI, layers composités, layout paramétrique, performance et contrôle artistique.

3. **Bridge d’accessibilité et fallback lisible**  
   Même si le HUD est rendu en Metal, le moteur doit exposer une représentation sémantique des éléments critiques : santé, objectifs, prompt d’action, dialogue, inventaire, menus. L’UI procédurale ne doit jamais sacrifier la lisibilité.

4. **Debug UI séparée, probablement immediate-mode**  
   Un système type Dear ImGui, ou une petite API maison inspirée IMGUI, est excellent pour profiler, inspecter les graphes, visualiser les seeds, modifier les tokens et déboguer les règles. Il ne doit pas être utilisé comme UI finale joueur.

Le nom proposé pour ce système : **IPUI — IsoWorld Procedural UI System**.

---

## 1. Objectifs du système

### 1.1 Objectif principal

Construire une interface / HUD qui :

- est **déterministe** : même seed + même état monde = même thème, mêmes variantes, mêmes règles visuelles ;
- est **paramétrique** : les dimensions, couleurs, matières, formes, animations, sons et densités sont contrôlés par des paramètres ;
- est **procédural** : les skins, ornements, glyphes, cadres, motifs, bruit, usure, layout, transitions et micro-animations peuvent être générés ;
- est **contextuel** : le HUD réagit au biome, à la météo, à l’heure, à la faction, au danger, à la santé, à la fatigue, à l’époque, à la technologie et au statut RPG ;
- est **lisible** : même dans les thèmes extrêmes, un mode de lisibilité doit garantir contraste, taille, hiérarchie et stabilité ;
- est **performant** : le rendu UI doit rester prévisible, batché, peu coûteux en CPU, compatible Metal et Apple Silicon ;
- est **versatile** : capable de couvrir menus, HUD combat, exploration, inventaire, crafting, map, dialogue, codex, journal, debug, éditeurs internes ;
- est **moderne** : data-driven, hot-reloadable, testable, stylable via tokens, extensible par graphes/règles.

### 1.2 Ce que le système doit éviter

- Un HUD hardcodé par écran.
- Une interface qui ne change que via une palette de couleurs.
- Une dépendance totale à SwiftUI pour le HUD gameplay, car cela limiterait les effets, le batching, la synchronisation avec le renderer et les skins extrêmes.
- Une UI custom totale pour tout, car cela rendrait coûteux les menus complexes, la saisie texte, les outils, l’accessibilité et les comportements OS.
- Des animations décoratives qui nuisent à la lecture.
- Des thèmes procéduraux qui produisent des combinaisons incohérentes ou illisibles.
- Un système “magique” impossible à debugger.

---

## 2. Recherche et analyse des approches modernes

### 2.1 Apple : SwiftUI, AppKit, MetalKit, CAMetalLayer

Le projet IsoWorld est déjà un POC macOS Swift/Metal avec une application SwiftUI, un monde procédural par chunks et un terrain vertical. Le repo annonce explicitement une app macOS SwiftUI, un rendu 3D initial, le support manette et une architecture découplée/testable.

Côté Apple, `MTKView` fournit une vue Metal prête à l’emploi qui gère le drawable via `CAMetalLayer`, les render pass descriptors, et éventuellement les textures depth/stencil/MSAA. Pour un moteur custom, Apple documente aussi la création d’une vue Metal custom basée directement sur `NSView`/`UIView` + `CAMetalLayer` lorsqu’on veut plus de contrôle que `MTKView`.

**Implication pour IsoWorld :**

- Garder SwiftUI/AppKit pour la fenêtre, les menus, les préférences et l’outillage.
- Utiliser `MTKView` ou une vue Metal custom comme surface de rendu principale.
- Rendre le HUD gameplay dans le pipeline Metal pour garder une frame graph cohérente.
- Utiliser SwiftUI comme overlay temporaire pendant le prototypage, mais pas comme solution finale unique pour le HUD procédural.

### 2.2 Unreal Common UI : input routing, couches, navigation, multiplateforme

Unreal Common UI est intéressant non pas parce qu’il faudrait le copier visuellement, mais parce qu’il répond à des problèmes fondamentaux : menus empilés, popups, navigation clavier/manette/souris, focus, retour au bon élément, input routing, couches sélectivement interactives. Common UI a été conçu initialement pour Fortnite et vise les interfaces multiplateformes complexes.

**Patterns à reprendre :**

- `UIStack` : pile de panneaux actifs.
- `InputRouter` : une seule couche reçoit l’input à un instant donné.
- `FocusGraph` : navigation directionnelle stable.
- `ActionBar` : mapping contextuel des actions manette/clavier.
- `ModalLayer` : popups qui bloquent ou filtrent l’input.
- `Breadcrumbs` et historique de focus.
- `FocusableWidget` explicite, pas de focus implicite fragile.

### 2.3 Unity UI Toolkit : retained-mode, visual tree, styles, layout, binding

Unity UI Toolkit montre une autre direction moderne : une UI retained-mode basée sur un arbre visuel, des styles proches CSS, un layout type Flexbox, un event system et du data binding. Unity recommande UI Toolkit pour les nouveaux projets UI, tout en gardant IMGUI pour certains cas d’outillage.

**Patterns à reprendre :**

- Arbre de widgets retained-mode.
- Styles séparés du comportement.
- Data binding explicite.
- Layout déclaratif.
- Panels runtime + panels outils.
- Possibilité de hot reload des styles.

### 2.4 Dear ImGui : excellent pour les outils, mauvais comme UI finale AAA

Dear ImGui est rapide, portable, renderer-agnostic, très efficace pour les outils et les debug panels. Sa documentation précise qu’il génère des vertex buffers/command lists que l’on peut rendre dans n’importe quel pipeline 3D, et qu’il est particulièrement adapté aux outils de debug, inspecteurs et visualisations temps réel.

Mais Dear ImGui indique aussi ne pas viser l’UI end-user complète et manque de certaines fonctionnalités haut niveau comme l’internationalisation complète, le texte bidirectionnel, le text shaping et l’accessibilité.

**Conclusion IsoWorld :**

- Utiliser un IMGUI pour les outils internes, inspecteurs de seeds, visualisation de graphes, budgets, profilers.
- Ne pas baser l’UI finale joueur sur IMGUI.

### 2.5 Rive / state machines : inspiration pour l’animation UI

Rive est intéressant pour ses state machines visuelles : les designers peuvent connecter des animations, états et transitions sans refaire tout le handoff développeur. Rive met aussi en avant des usages de game UI, HUD, ability wheels, inventory, menus, vector UI et runtime custom engine.

**Patterns à reprendre même sans intégrer Rive directement :**

- composants animés par state machine ;
- séparation entre design et logique ;
- inputs typés : bool, number, trigger ;
- animation mixing ;
- assets interactifs réutilisables ;
- édition visuelle future possible.

### 2.6 Accessibilité Apple et Human Interface Guidelines

Apple insiste sur les Human Interface Guidelines, l’accessibilité, la typographie, les contrastes, la réduction du mouvement, le fait de ne pas dépendre uniquement de la couleur, et l’adaptation aux préférences utilisateur. Même si IsoWorld a un HUD custom, ces principes restent essentiels.

**Règle pour IsoWorld :** un thème procédural ne doit jamais pouvoir rendre une information critique illisible. Tous les thèmes doivent passer par un validateur : contraste, taille minimum, motion safety, zone sûre, redondance couleur+forme+texte/icône.

---

## 3. Décision d’architecture : Apple, custom ou hybride ?

### 3.1 Option A — Tout faire avec SwiftUI/AppKit

**Avantages :**

- Très rapide pour prototyper.
- Accessibilité native.
- Text input, menus, listes, scroll, focus OS déjà gérés.
- Bon pour préférences, launcher, debug, éditeurs simples.
- Intégration naturelle avec macOS.

**Limites pour IsoWorld :**

- Contrôle artistique limité pour HUD très stylisé.
- Difficile de batcher avec le renderer 3D.
- Difficile de faire des effets UI procéduraux extrêmes : distortion, glyphes, scanlines, particules, masques, SDF animés, world-space UI, post-process HUD.
- Potentiels problèmes de synchronisation frame-perfect avec gameplay/renderer.
- Moins adapté aux interfaces diegetiques intégrées au monde.
- Difficile de garantir une esthétique radicalement différente par seed sans bricolage.

**Usage recommandé :** shell, menus macOS, outils, préférences, login/start screen simple, éditeurs internes, debug panels avancés.

### 3.2 Option B — Tout faire custom Metal

**Avantages :**

- Contrôle total.
- Pipeline cohérent avec le renderer.
- Très bon pour HUD, diegetic UI, world-space UI, effets procéduraux.
- Batching, GPU instancing, SDF, atlas, masks, compositing sur mesure.
- Peut être entièrement déterministe et data-driven.

**Limites :**

- Coût élevé : layout, text shaping, focus, accessibilité, localisation, IME, sélection, copy/paste, menus.
- Risque de sous-estimer le travail de text rendering multi-langue.
- Nécessite beaucoup de tooling.
- Très difficile d’atteindre la robustesse OS pour les formulaires complexes.

**Usage recommandé :** HUD gameplay, world-space UI, menus stylisés in-game, overlays, prompts, map, radial menus, combat HUD, effets.

### 3.3 Option C — Architecture hybride recommandée

**Décision : partir sur une architecture hybride.**

| Domaine | Technologie recommandée | Pourquoi |
|---|---|---|
| Fenêtre principale | SwiftUI + `MTKView` ou custom `NSView` Metal | intégration macOS + rendu Metal |
| HUD in-game | Custom Metal UI Renderer | contrôle visuel, performance, procédural |
| Menus in-game stylisés | Custom Metal retained-mode | cohérence artistique, thèmes par seed |
| Préférences / settings | SwiftUI | accessibilité, formulaires, OS-native |
| Debug tools | SwiftUI + IMGUI-like overlay | productivité |
| Éditeur de thèmes | SwiftUI/AppKit au départ | développement rapide |
| UI world-space | Custom Metal | intégration scène |
| Texte critique accessible | Bridge sémantique vers AppKit/SwiftUI/accessibility | accessibilité |
| Prototypage rapide | SwiftUI overlay possible | vitesse |

### 3.4 Pourquoi cette décision est la plus robuste

IsoWorld veut une UI qui soit :

- générée par seed ;
- fortement stylisée ;
- animée ;
- liée au monde ;
- parfois diegetique ;
- sensible au gameplay ;
- compatible manette ;
- performante ;
- testable.

Aucun framework unique ne couvre tout parfaitement. SwiftUI est excellent pour l’app et les outils, mais pas pour un HUD AAA procédural radical. Metal custom est excellent pour le HUD, mais coûteux pour l’accessibilité et les formulaires. L’hybride maximise les forces de chaque approche.

---

## 4. Nom du système : IPUI

**IPUI — IsoWorld Procedural UI System**

IPUI est le système qui transforme :

- le seed global ;
- le `WorldRPGDNA` ;
- le biome courant ;
- la météo ;
- l’époque ;
- la faction ;
- la technologie/magie ;
- le danger ;
- le statut joueur ;
- la plateforme d’input ;
- les préférences d’accessibilité ;

…en interface lisible, stylisée, cohérente et performante.

### 4.1 Modules principaux

```text
IPUI
├── UIWorldDNA
├── UIThemeSystem
├── UITokenResolver
├── UIRecipeRegistry
├── UILayoutEngine
├── UIStateStore
├── UIInputRouter
├── UIFocusGraph
├── UIAnimationGraph
├── UIRenderGraph
├── UIMetalRenderer
├── UITextSystem
├── UIIconGlyphSystem
├── UIProceduralOrnamentSystem
├── UIMaterialSystem
├── UIAccessibilityBridge
├── UILocalizationBridge
├── UITestValidator
└── UIDebugInspector
```

---

## 5. UIWorldDNA : la constitution visuelle de l’interface

Le HUD doit avoir sa propre DNA, comme les biomes ou le RPG.

```swift
struct UIWorldDNA: Codable, Hashable {
    let seed: UInt64
    let baseStyle: UIBaseStyle
    let era: UIEra
    let techLevel: UITechLevel
    let magicLevel: UIMagicLevel
    let materialLanguage: UIMaterialLanguage
    let shapeLanguage: UIShapeLanguage
    let ornamentLanguage: UIOrnamentLanguage
    let typographyProfile: UITypographyProfile
    let iconographyProfile: UIIconographyProfile
    let motionProfile: UIMotionProfile
    let informationDensity: UIInformationDensity
    let diegeticLevel: UIDiegeticLevel
    let glitchLevel: Float
    let wearLevel: Float
    let ritualization: Float
    let factionInfluence: [FactionID: Float]
    let biomeInfluence: [BiomeID: Float]
    let accessibilityPolicy: UIAccessibilityPolicy
}
```

### 5.1 Paramètres DNA importants

#### `baseStyle`

Détermine la grande famille d’interface : primitive, naturaliste, médiévale, mystique, industrielle, analogique, militaire, corporate, cybernétique, biotech, alien, etc.

#### `era`

Détermine les métaphores : pierre gravée, parchemin, métal riveté, écran CRT, tablette holographique, implants neuronaux.

#### `techLevel`

Détermine le niveau de sophistication :

- aucun affichage, seulement signes et objets ;
- marqueurs physiques ;
- cadrans mécaniques ;
- appareils électriques ;
- écrans LCD ;
- HUD tactique ;
- hologrammes ;
- interface neuronale ;
- projection quantique ;
- interface biologique.

#### `magicLevel`

Détermine si l’UI peut utiliser : glyphes, cercles rituels, runes, halos, particules mystiques, cartes vivantes, textes auto-écrits, encres réactives.

#### `materialLanguage`

Détermine la matière apparente : papier, cuir, os, bois, pierre, métal, verre, néon, plasma, gel organique, cristal, hologramme.

#### `shapeLanguage`

Détermine la géométrie dominante : rond, anguleux, fractal, organique, hexagonal, brutaliste, baroque, minimaliste, asymétrique.

#### `motionProfile`

Détermine les animations : lentes, mécaniques, nerveuses, organiques, magiques, glitchées, militaires, calmes.

#### `diegeticLevel`

Détermine si l’UI est :

- non-diegetique : HUD classique ;
- semi-diegetique : affichage justifié par équipement ;
- diegetique : éléments dans le monde ;
- méta-diegetique : interface comme artefact narratif.

---

## 6. Design tokens procéduraux

L’UI doit être construite à partir de **tokens** générés et validés.

### 6.1 Catégories de tokens

```text
UITokens
├── ColorTokens
├── TypographyTokens
├── ShapeTokens
├── SpacingTokens
├── BorderTokens
├── ShadowTokens
├── GlowTokens
├── PatternTokens
├── NoiseTokens
├── MaterialTokens
├── MotionTokens
├── IconTokens
├── GlyphTokens
├── AudioTokens
├── FeedbackTokens
├── AccessibilityTokens
└── DensityTokens
```

### 6.2 Color tokens

- `primary`
- `secondary`
- `accent`
- `danger`
- `warning`
- `success`
- `neutral`
- `surface`
- `surfaceAlt`
- `textPrimary`
- `textSecondary`
- `textDisabled`
- `outline`
- `glow`
- `biomeTint`
- `factionTint`
- `magicTint`
- `technologyTint`

### 6.3 Typography tokens

- famille système ou custom ;
- poids ;
- condensation ;
- tracking ;
- taille minimum ;
- optical size ;
- style des chiffres ;
- style des titres ;
- style des labels ;
- style des textes longs ;
- fallback lisible ;
- mode dyslexia-friendly optionnel ;
- support localisation.

### 6.4 Shape tokens

- rayon des coins ;
- épaisseur des cadres ;
- angle dominant ;
- nombre de segments ;
- irrégularité ;
- symétrie ;
- niveau d’ornement ;
- niveau de fracture ;
- niveau d’usure ;
- intensité organique.

### 6.5 Motion tokens

- durée courte/moyenne/longue ;
- courbes d’easing ;
- amplitude ;
- overshoot ;
- tremblement ;
- délais ;
- stagger ;
- loop ;
- motion noise ;
- transition par état ;
- réduction automatique si `ReduceMotion`.

### 6.6 Material tokens UI

- papier sec ;
- papier humide ;
- parchemin ;
- cuir ;
- bois peint ;
- os poli ;
- pierre gravée ;
- métal rouillé ;
- acier brossé ;
- cuivre oxydé ;
- verre ;
- cristal ;
- hologramme ;
- écran CRT ;
- écran LCD ancien ;
- plasma ;
- gel biotech ;
- membrane organique ;
- interface de lumière ;
- poussière ;
- neige ;
- sable ;
- boue ;
- sang ;
- suie ;
- mousse.

---

## 7. Génération procédurale des thèmes

### 7.1 Pipeline de génération

```text
World Seed
  ↓
WorldRPGDNA / BiomeDNA / EraDNA / FactionDNA
  ↓
UIWorldDNA
  ↓
Theme Archetype Selection
  ↓
Token Generation
  ↓
Legibility Validation
  ↓
Component Recipe Binding
  ↓
Layout Variant Selection
  ↓
Animation/Motion Variant Selection
  ↓
Runtime Theme Instance
  ↓
HUD/Menu Rendering
```

### 7.2 Exemple de résolution

Seed A :

```text
World era: post-collapse industrial
Biome: toxic marsh
Dominant faction: scavenger cult
Magic: low
Tech: medium broken analog
Mood: oppressive
```

UI générée :

- panneaux en métal rouillé ;
- bandes adhésives et vis ;
- texte stencil ;
- palette vert toxique / orange rouille ;
- glitch analogique léger ;
- icônes simplifiées façon signalétique industrielle ;
- alertes avec clignotement lent ;
- inventaire façon caisse/étiquettes ;
- carte comme blueprint sali ;
- prompts manette sous forme de stickers usés.

Seed B :

```text
World era: mythic bronze age
Biome: high alpine sacred valley
Dominant faction: oracle order
Magic: high
Tech: low
Mood: contemplative
```

UI générée :

- cadres gravés bronze/pierre ;
- runes animées ;
- halos doux ;
- carte comme fresque ;
- health/stamina sous forme de filaments lumineux ;
- textes avec serif gravé ;
- transitions lentes circulaires ;
- icônes inspirées astres/montagnes/animaux.

---

## 8. Taxonomie longue de thèmes UI générables

Cette liste doit servir de base pour `UIThemeArchetype`.

### 8.1 Primitif / survie / nature

1. HUD de chasseurs-cueilleurs avec marques d’os et pigments.
2. Interface de survie en cordes, nœuds, pierres et gravures.
3. Carnet de peau animale cousue.
4. Signes peints sur bois humide.
5. UI de tribu forestière, feuilles, fibres, écorces.
6. UI de tribu désertique, sable, cuir tanné, symboles solaires.
7. UI polaire, os, ivoire, glace, peaux épaisses.
8. UI de chamane, totems, fumée, peinture rituelle.
9. UI volcanique primitive, obsidienne, lave, cendres.
10. UI de navigation par étoiles, coquillages, cartes nouées.

### 8.2 Antique / mythologique

11. Tablettes d’argile gravées.
12. Fresques grecques stylisées.
13. Interface romaine en marbre, bronze et cire.
14. Papyrus égyptien avec glyphes animés.
15. Astrolabe antique.
16. Codex maya imaginaire.
17. Cartographie mythologique avec monstres marins.
18. Interface de temple solaire.
19. Interface de bibliothèque antique.
20. UI de divination par constellations.

### 8.3 Médiéval / fantasy

21. Parchemin enluminé.
22. Grimoire vivant.
23. Interface runique nordique.
24. UI de guilde marchande.
25. UI de chevalier, écussons et métal poli.
26. UI de nécromancien, os, cire noire, glyphes.
27. UI druidique, racines et lumière verte.
28. UI de mage académique, cercles et diagrammes.
29. UI de voleur, cuir sombre, signes discrets.
30. UI de royaume en guerre, bannières et sceaux.
31. UI de cartographe médiéval.
32. UI d’alchimiste, fioles, symboles, étiquettes.
33. UI de prêtre/ordre religieux.
34. UI de monde féerique, halos, poussière, ornements.
35. UI de monde démoniaque, fissures rouges, pactes.

### 8.4 Renaissance / exploration

36. Interface de navigateur maritime.
37. UI d’atelier d’inventeur.
38. UI de cabinet de curiosités.
39. Carnet scientifique ancien.
40. UI de carte astrologique.
41. UI de guilde d’explorateurs.
42. UI de mécaniques horlogères.
43. UI de cité marchande.
44. UI de pirate, cartes brûlées, encre, bois.
45. UI d’expédition coloniale fictive.

### 8.5 Steampunk / dieselpunk / industriel

46. UI steampunk cuivre, jauges, engrenages.
47. UI dieselpunk militaire, acier, rivets, jauges.
48. UI d’usine, pictogrammes, huile, poussière.
49. UI de mine, lanternes, plans, charbon.
50. UI ferroviaire, tickets, horaires, signaux.
51. UI sous-marin ancien, sonar analogique.
52. UI aéronautique rétro, cadrans et altitude.
53. UI de laboratoire électrique, bobines, arcs.
54. UI de centrale énergétique.
55. UI de cité industrielle corrompue.

### 8.6 Moderne / tactique / réaliste

56. HUD militaire minimal.
57. UI survival moderne, GPS, batterie, radio.
58. UI smartphone in-game.
59. UI smartwatch.
60. UI drone recon.
61. UI de police/enquête.
62. UI de hacker réaliste terminal.
63. UI de médecine terrain.
64. UI d’expédition scientifique.
65. UI catastrophe naturelle.
66. UI de spéléologie.
67. UI de haute montagne.
68. UI de plongée.
69. UI de photographie/scan.
70. UI d’archéologue moderne.

### 8.7 Cyberpunk / corporate / dystopie

71. UI néon cyberpunk.
72. UI corporate blanche, froide, invasive.
73. UI glitch illégale.
74. UI de black market.
75. UI de réalité augmentée urbaine.
76. UI de police prédictive.
77. UI de mégacorporation médicale.
78. UI de surveillance omniprésente.
79. UI de hacker underground.
80. UI de gang de rue.
81. UI de ruche urbaine dense.
82. UI de réseau social dystopique.
83. UI de propagande algorithmique.
84. UI de cyber-implant low quality.
85. UI de lux corporation.

### 8.8 Science-fiction spatiale

86. UI de vaisseau spatial industriel.
87. UI de cockpit militaire.
88. UI de colonie martienne.
89. UI d’exploration exoplanétaire.
90. UI de station orbitale usée.
91. UI de combinaison EVA.
92. UI de civilisation post-humaine.
93. UI de cargo spatial.
94. UI de terraformation.
95. UI de ruine alien scannée.
96. UI de communication interstellaire.
97. UI de mission scientifique lointaine.
98. UI de navigation gravitationnelle.
99. UI de cryosommeil.
100. UI de catastrophe spatiale.

### 8.9 Biotech / organique / alien

101. UI organique vivante.
102. UI membrane translucide.
103. UI de symbiote.
104. UI de colonie fongique intelligente.
105. UI de plante consciente.
106. UI de civilisation insectoïde.
107. UI de cerveau collectif.
108. UI de technologie osseuse.
109. UI de liquide bioluminescent.
110. UI alien à géométrie non euclidienne.
111. UI de coquillage/cristal vivant.
112. UI de virus numérique-biologique.
113. UI de ruche parasitoïde.
114. UI de machine organique.
115. UI de langage pheromonal visualisé.

### 8.10 Magie avancée / métaphysique

116. UI d’astres et constellations.
117. UI de tarot vivant.
118. UI de chronomancie.
119. UI de rêve lucide.
120. UI de mémoire fracturée.
121. UI de pactes spirituels.
122. UI de dimensions parallèles.
123. UI de nœuds karmiques.
124. UI d’énergie élémentaire.
125. UI d’école de magie élémentale.
126. UI de magie noire corruptrice.
127. UI de magie blanche sacrée.
128. UI de runes mécaniques.
129. UI de portails.
130. UI de réalité instable.

### 8.11 Minimalisme / abstraction / méta

131. UI purement typographique.
132. UI de signes géométriques.
133. UI monochrome haute lisibilité.
134. UI de simulation informatique.
135. UI de rêve abstrait.
136. UI de monde sans langage.
137. UI de pictogrammes seulement.
138. UI de sons/ondes visualisés.
139. UI de lignes topographiques.
140. UI de diagrammes scientifiques.
141. UI de système d’exploitation fictif.
142. UI de terminal minimaliste.
143. UI d’artefact fractal.
144. UI invisible/contextuelle.
145. UI adaptative qui disparaît hors danger.

---

## 9. Liste longue des surfaces UI / HUD à générer

### 9.1 HUD exploration

- barre de vie ;
- endurance ;
- faim ;
- soif ;
- température corporelle ;
- fatigue ;
- oxygène ;
- radiation ;
- infection ;
- statut magique ;
- statut mental ;
- charge portée ;
- bruit produit ;
- visibilité ;
- boussole ;
- mini-carte ;
- altimètre ;
- inclinomètre ;
- montre / cycle jour-nuit ;
- météo actuelle ;
- qualité de l’air ;
- humidité ;
- vent ;
- direction d’objectif ;
- zone de danger ;
- statut biome ;
- niveau de froid/chaleur ;
- état des chaussures ;
- grip/adhérence ;
- niveau d’eau/boue/neige au sol ;
- indicateur de verticalité ;
- indicateur de corde/grappin/escalade.

### 9.2 HUD combat

- santé locale ;
- posture ;
- stamina combat ;
- garde ;
- équilibre ;
- visée ;
- lock target ;
- menace ennemie ;
- direction des attaques ;
- timing de parade ;
- fenêtre de contre ;
- blessures ;
- saignement ;
- stress ;
- munitions ;
- chaleur d’arme ;
- charge magique ;
- cooldowns ;
- compétences actives ;
- effets de statut ;
- moral ;
- couverture ;
- bruit ;
- camouflage ;
- alerte faction.

### 9.3 HUD terrain/verticalité

- prompt de grimpe ;
- qualité d’accroche ;
- résistance de corde ;
- angle de pente ;
- danger chute ;
- surface glissante ;
- rocher instable ;
- rebord accessible ;
- endurance de suspension ;
- ancrage possible ;
- escalier/échelle détecté ;
- chemin alternatif ;
- statut grappin ;
- indicateur de poids supporté ;
- zone d’éboulement ;
- état du sol sous le pied.

### 9.4 Menus principaux

- écran titre ;
- sélection de seed ;
- génération de monde ;
- choix du personnage ;
- paramètres ;
- sauvegardes ;
- chargement ;
- pause ;
- crédits ;
- accessibilité ;
- contrôle manette ;
- debug build menu.

### 9.5 Inventaire et équipement

- grille d’inventaire ;
- sacs/contenants ;
- équipement porté ;
- durabilité ;
- rareté ;
- poids ;
- volume ;
- odeur ;
- humidité ;
- saleté ;
- température ;
- contamination ;
- compatibilité ;
- réparation ;
- amélioration ;
- comparaison ;
- tri ;
- filtre ;
- favori ;
- craft depuis inventaire.

### 9.6 Crafting / construction

- arbre de recettes ;
- recette contextuelle ;
- qualité des matériaux ;
- outils requis ;
- station requise ;
- temps de fabrication ;
- risque d’échec ;
- variantes de résultat ;
- prévisualisation 3D ;
- coût énergétique ;
- savoir-faire ;
- unlock par compétence ;
- blueprint ;
- assemblage modulaire ;
- usure prévue.

### 9.7 Dialogue / social / factions

- dialogue classique ;
- roue de dialogue ;
- statut émotionnel NPC ;
- confiance ;
- réputation ;
- menace ;
- influence faction ;
- mensonge détecté ;
- relation ;
- dette ;
- promesse ;
- faveur ;
- contrat ;
- tabou culturel ;
- langue inconnue ;
- traduction partielle ;
- rituel social ;
- négociation ;
- marchandage.

### 9.8 Journal / quêtes / RPG

- journal procédural ;
- objectifs dynamiques ;
- quête mythique ;
- indices ;
- cartes annotées ;
- arbre de conséquences ;
- factions impliquées ;
- hypothèses ;
- preuves ;
- rumeurs ;
- prophéties ;
- objectifs alternatifs ;
- résolution pacifique/violente ;
- progression de monde ;
- fins potentielles ;
- chronologie ;
- codex culturel ;
- encyclopédie créatures ;
- bestiaire ;
- atlas biomes.

### 9.9 Map / navigation

- carte 2D stylisée ;
- carte isométrique ;
- carte topographique ;
- carte mentale incomplète ;
- fog of war ;
- notes joueur ;
- routes ;
- points d’intérêt ;
- dangers ;
- altitude ;
- biome layers ;
- météo ;
- territoire faction ;
- ressources ;
- traces ;
- flux hydrologiques ;
- routes commerciales ;
- migrations ;
- couches temporelles ;
- carte ancienne incorrecte ;
- carte vivante magique.

### 9.10 Diegetic UI

- écrans dans le monde ;
- panneaux holographiques ;
- cadrans physiques ;
- livres ouverts ;
- table de carte ;
- console de vaisseau ;
- terminal ;
- tablette ;
- grimoire ;
- cristaux d’information ;
- tatouages lumineux ;
- marques sur bras ;
- lunettes/visière ;
- projection sur fumée ;
- interface de drone ;
- voix/sonar visualisé.

---

## 10. Types de composants UI paramétriques

### 10.1 Composants atomiques

- `Label`
- `RichText`
- `Icon`
- `Glyph`
- `Button`
- `Toggle`
- `Slider`
- `RadialSlider`
- `ProgressBar`
- `SegmentedBar`
- `Meter`
- `Gauge`
- `Dial`
- `Needle`
- `PipCounter`
- `Badge`
- `Tag`
- `Tooltip`
- `Divider`
- `Frame`
- `Panel`
- `Card`
- `Slot`
- `Socket`
- `Reticle`
- `CompassMark`
- `PromptGlyph`
- `NotificationToast`
- `StatusChip`
- `CooldownRing`
- `BuffIcon`
- `DebuffIcon`
- `MiniGraph`
- `Sparkline`

### 10.2 Composants composés

- `HealthCluster`
- `SurvivalCluster`
- `AbilityWheel`
- `InventoryGrid`
- `EquipmentPaperDoll`
- `QuestTracker`
- `DialogueBox`
- `FactionPanel`
- `BiomeReadout`
- `WeatherReadout`
- `MapPanel`
- `CraftingPanel`
- `SkillTree`
- `TimelinePanel`
- `CodexPage`
- `WorldEventBanner`
- `DamageDirectionIndicator`
- `StealthVisibilityMeter`
- `ClimbingAssistPanel`
- `VehicleDashboard`
- `TerminalScreen`
- `BookInterface`
- `HologramPanel`
- `RitualCircleMenu`

### 10.3 Composants procéduraux spécialisés

- cadre généré par grammaire ;
- glyphes générés par seed ;
- icône dérivée d’un concept RPG ;
- carte topographique générée ;
- diagramme de faction ;
- arbre de compétences génératif ;
- roue d’abilities variable ;
- grimoire dont les pages changent ;
- terminal avec bruit/glitch ;
- instrument analogique généré ;
- jauge organique ;
- mini-hologramme 3D ;
- widget de scan environnemental ;
- widget météo dynamique ;
- widget d’alchimie ;
- widget de craft modulaire.

---

## 11. Règles de génération des variantes

### 11.1 Principes

Les variantes doivent être corrélées. Une UI steampunk ne doit pas mélanger par hasard du papier féerique, une typographie cyberpunk, des boutons organiques et des sons de verre magique — sauf si la DNA du monde justifie explicitement un hybride.

### 11.2 Variables de contrôle

```text
Variant Context
├── worldSeed
├── localBiome
├── currentWeather
├── currentTimeOfDay
├── dangerLevel
├── playerHealthState
├── playerEquipment
├── factionTerritory
├── magicContamination
├── technologyReliability
├── corruptionLevel
├── UIAccessibilityMode
└── platformInputMode
```

### 11.3 Règles de cohérence

- Tous les éléments d’un écran doivent partager une famille de matériaux.
- Les icônes doivent partager une même grammaire de silhouette.
- Les animations doivent partager un motion profile.
- Les informations critiques doivent toujours avoir un fallback stable.
- Les couleurs danger/warning/success doivent être stables dans toute la session.
- Les états critiques doivent être redondants : couleur + forme + texte/icône + son optionnel.
- Les effets procéduraux ne doivent pas masquer texte et chiffres.
- Les thèmes locaux peuvent moduler le HUD, mais pas casser la reconnaissance des éléments fondamentaux.

### 11.4 Règles de variation selon monde

| Facteur | Effet UI |
|---|---|
| Époque primitive | formes physiques, peu de chiffres, pictogrammes |
| Époque médiévale | parchemin, sceaux, gravures, textes longs |
| Époque industrielle | jauges, rivets, métal, bruit mécanique |
| Époque moderne | écrans plats, GPS, pictos clairs |
| Époque cyberpunk | néon, glitch, overlays AR |
| Époque spatiale | panels lumineux, telemetry, hologrammes |
| Monde magique | glyphes, halos, cercles, transitions rituelles |
| Monde sans magie | instrumentation physique, cartes, données |
| Monde organique | membranes, pulsations, croissance |
| Monde alien | asymétrie, symboles inconnus, formes non humaines |

### 11.5 Règles de variation selon biome

| Biome | Modulation UI |
|---|---|
| Désert | poussière, chaleur, mirage, tons sable/soleil |
| Banquise | cristaux, condensation, bleus froids, fissures |
| Forêt dense | feuilles, mousse, ombres, organique |
| Marais | humidité, salissures, vert toxique, bulles |
| Volcan | lueur rouge, cendres, fissures chaudes |
| Montagne | cartes topo, roche, altitude, vent |
| Océan | corrosion, sel, bleus profonds, sonar |
| Caverne | faible lumière, glyphes, échos, minéraux |
| Ville | signalétique, écrans, réseau, bruit data |
| Ruines | usure, fragments, poussière, symboles anciens |

### 11.6 Règles de variation selon météo

- Pluie : gouttes sur UI diegetique, reflets, sons mouillés, wetness subtile.
- Neige : accumulation légère sur cadres non critiques, froid visuel, cristaux.
- Tempête de sable : bruit, opacité réduite, warning navigation.
- Brouillard : soft edges, baisse de contraste décoratif, hausse lisibilité critique.
- Orage : flashs contrôlés, interférences, jitter faible.
- Canicule : shimmer, couleurs chaudes, alertes hydratation.
- Nuit : mode faible luminance, icônes plus contrastées.
- Eclipse / événement mythique : thème temporaire global.

### 11.7 Règles selon statut joueur

- Blessé : HUD plus instable, mais texte critique stable.
- Empoisonné : teinte subtile, distorsion périphérique.
- Fatigué : animations ralenties, flou très léger non critique.
- Paniqué : rythme plus nerveux, alertes plus fréquentes.
- Concentré : réduction du bruit, focus sur objectifs.
- En stealth : HUD minimal, visibilité/bruit mis en avant.
- En escalade : module verticalité prioritaire.
- Sous l’eau : oxygène, pression, son étouffé, UI flottante.
- En véhicule : cockpit/dashboard dédié.

---

## 12. Système de layout moderne

### 12.1 Besoin

Le HUD doit s’adapter à :

- résolution ;
- aspect ratio ;
- safe area ;
- mode fenêtré/plein écran ;
- distance écran ;
- manette/clavier/souris ;
- taille de texte ;
- langue ;
- densité d’information ;
- contexte gameplay ;
- thème.

### 12.2 Recommandation : retained-mode layout + render cache

Un système custom immediate-mode est tentant, mais pour une UI joueur complexe, il faut un modèle retained-mode :

```text
UIScreen
└── UIPanel
    ├── UIStack
    │   ├── UILabel
    │   └── UIIcon
    └── UIGrid
        └── UISlot
```

Le moteur garde un arbre UI, recalcule layout quand l’état change, puis génère des draw commands batchées.

### 12.3 Layout primitives

- `StackLayout` vertical/horizontal ;
- `GridLayout` ;
- `AnchorLayout` ;
- `RadialLayout` ;
- `CompassLayout` ;
- `FlowLayout` ;
- `ConstraintLayout` simple ;
- `WorldProjectedLayout` ;
- `DiegeticSurfaceLayout` ;
- `TimelineLayout` ;
- `GraphLayout` ;
- `MapOverlayLayout`.

### 12.4 Zones HUD

```text
Screen
├── TopLeft: status compact
├── TopCenter: compass/objective
├── TopRight: minimap/weather/time
├── Center: reticle/context prompt
├── BottomLeft: survival/equipment
├── BottomCenter: action bar/abilities
├── BottomRight: inventory quick slots
├── LeftEdge: quest/social alerts
├── RightEdge: notifications/context
└── FullscreenOverlay: menu/map/dialogue
```

### 12.5 Layout procédural contrôlé

Le seed peut varier :

- position du health cluster ;
- forme des jauges ;
- densité ;
- style de grouping ;
- orientation des menus ;
- transition d’ouverture ;
- taille des panneaux ;
- niveaux d’ornement.

Mais il ne doit pas casser :

- zones de lecture habituelles ;
- ergonomie manette ;
- distance entre éléments ;
- taille minimum ;
- ordre logique ;
- focus.

---

## 13. Rendu Metal du HUD

### 13.1 Position dans la frame graph

```text
FrameGraph
├── World GBuffer / Forward / Depth
├── Lighting
├── Transparent World
├── Particles / FX
├── Post-process scene
├── UI World-space pass
├── UI Screen-space pass
├── UI Composite / Bloom safe
└── Present
```

### 13.2 Backends de rendu UI

IPUI doit supporter plusieurs types de primitives :

1. **Quad sprites**  
   Icônes, panneaux, textures, atlas.

2. **SDF / MSDF text**  
   Texte net à plusieurs tailles, contours, ombres, glow.

3. **SDF shapes**  
   Rectangles arrondis, cercles, arcs, barres, cadres.

4. **Vector-like tessellation offline**  
   Glyphes, ornements, formes complexes.

5. **Mesh UI**  
   Panels 3D, jauges mécaniques, world-space widgets.

6. **Procedural shader UI**  
   Bruit, scanline, hologramme, parchemin, grain, fissures.

7. **Particle UI**  
   Sparks, runes, poussières, petits effets non envahissants.

8. **Mask/stencil layers**  
   Fenêtres, scroll, radial fills, clipping.

### 13.3 Draw command model

```swift
struct UIDrawCommand {
    let pipelineID: UIPipelineID
    let materialID: UIMaterialID
    let geometryRange: Range<Int>
    let textureBindings: UITextureBindings
    let clipRect: SIMD4<Float>
    let depthMode: UIDepthMode
    let blendMode: UIBlendMode
    let sortKey: UInt64
}
```

### 13.4 Batching

Trier par :

1. layer ;
2. blend mode ;
3. pipeline ;
4. texture atlas ;
5. material ;
6. clip rect ;
7. depth.

### 13.5 Text rendering

Le texte est une des parties les plus difficiles.

#### Phase 1

- Utiliser Swift/Apple pour rasteriser des glyphes dans des atlas.
- Cache par police/taille/style/langue.
- Rendu en quads Metal.
- Suffisant pour prototypes.

#### Phase 2

- MSDF/SDF atlas pour tailles variables.
- Support contours, glow, shadow.
- Cache de runs de texte.
- Mesure précise pour layout.

#### Phase 3

- Support text shaping avancé.
- Fallback multi-langues.
- Bidirectionnel si nécessaire.
- Hyphenation/line breaking.
- Bridge SwiftUI/AppKit pour text input complexe.

### 13.6 Icones et glyphes procéduraux

Les icônes doivent être générées à partir d’une grammaire :

```text
IconRecipe
├── baseShape: circle | triangle | blade | leaf | gear | rune | bone | hex | waveform
├── silhouetteComplexity: Float
├── strokeProfile
├── ornamentLevel
├── damage/wear
├── symmetry
├── fillPattern
├── semanticAnchor
└── themeInfluence
```

Exemple : une icône “poison” dans un monde biotech peut devenir une cellule verte pulsante ; dans un monde médiéval, un crâne gravé ; dans un monde corporate, un pictogramme toxicité ; dans un monde alien, un symbole radial étrange.

---

## 14. Animation UI procédurale

### 14.1 Architecture

Chaque composant peut avoir un `UIAnimationGraph` :

```text
State
├── idle
├── hover/focus
├── pressed
├── disabled
├── appearing
├── disappearing
├── warning
├── critical
├── corrupted
├── biomeReactive
└── worldEventOverride
```

### 14.2 Paramètres procéduraux

- durée ;
- easing ;
- delay ;
- overshoot ;
- shake ;
- noise ;
- flicker ;
- pulse ;
- morph ;
- radial reveal ;
- ink spread ;
- scanline ;
- glitch ;
- rune draw ;
- mechanical tick ;
- organic breathing.

### 14.3 Familles de motion

#### Motion organique

- respiration lente ;
- pulsation ;
- croissance ;
- contraction ;
- ondulation ;
- liquide.

#### Motion mécanique

- tick ;
- verrouillage ;
- glissière ;
- jauge ;
- engrenage ;
- ressort ;
- amortissement.

#### Motion magique

- cercle qui se trace ;
- glyphes qui s’allument ;
- particules orbitantes ;
- apparition par poussière ;
- écriture automatique ;
- halo.

#### Motion numérique

- scanline ;
- pixel sorting ;
- glitch ;
- flicker ;
- hologram jitter ;
- data stream.

#### Motion minimaliste

- fade ;
- slide court ;
- scale léger ;
- blur contrôlé ;
- transition rapide.

### 14.4 Règles de motion safety

- Désactiver ou réduire parallax, vortex, multi-axis motion si Reduced Motion.
- Jamais de shake intense sur du texte critique.
- Pas de clignotement rapide pour les alertes.
- Préférer forme + texte + son à flash stroboscopique.
- Les animations décoratives doivent être stoppables.

---

## 15. Interaction et input routing

### 15.1 Inputs à gérer

- clavier ;
- souris ;
- trackpad ;
- manette PS5 ;
- joystick analogique ;
- D-pad ;
- radial menu ;
- hold/tap/double-tap ;
- long press ;
- navigation focus ;
- input remapping ;
- accessibility shortcuts.

### 15.2 InputRouter

```swift
enum UIInputLayer {
    case gameplayHUD
    case radialMenu
    case inventory
    case dialogue
    case pauseMenu
    case modal
    case debugOverlay
}
```

Un seul layer doit être prioritaire pour éviter :

- le joueur qui attaque en cliquant un menu ;
- la caméra qui bouge pendant l’inventaire ;
- le bouton `B/Circle` qui ferme deux panneaux ;
- un popup qui ne rend pas le focus au bon widget.

### 15.3 FocusGraph

Chaque menu doit générer un graphe de focus :

```text
Widget A
├── up: Widget B
├── down: Widget C
├── left: Widget D
└── right: Widget E
```

Pour les layouts procéduraux, le focus ne peut pas être uniquement spatial. Il doit être validé par :

- ordre logique ;
- proximité ;
- priorité ;
- groupement ;
- historique ;
- type d’action.

### 15.4 Action prompts procéduraux

Les prompts doivent changer selon :

- manette/clavier/souris ;
- thème monde ;
- danger ;
- contexte ;
- difficulté ;
- accessibilité.

Exemples :

- Monde médiéval : bouton manette dessiné comme sceau.
- Monde cyberpunk : prompt comme overlay AR.
- Monde primitif : pictogramme simple avec icône main/outil.
- Monde magique : rune correspondant à l’action.

Mais le symbole réel de la touche doit rester reconnaissable.

---

## 16. UI liée au monde et aux systèmes procéduraux

### 16.1 Sources de données

IPUI doit lire des snapshots, pas interroger directement tous les systèmes.

```text
UIFrameSnapshot
├── PlayerHUDState
├── SurvivalState
├── CombatState
├── TerrainInteractionState
├── WeatherState
├── BiomeState
├── RPGState
├── QuestState
├── InventoryState
├── FactionState
├── WorldEventState
├── InputModeState
└── AccessibilityState
```

### 16.2 Règle importante

Le HUD doit être **pull/render safe**, mais les données doivent venir d’un snapshot stable produit par le gameplay. Cela évite les états incohérents pendant une frame.

### 16.3 UI contextuelle terrain

Vu les autres documents IsoWorld, le HUD doit être conscient de :

- pente ;
- matière du sol ;
- humidité ;
- glace ;
- neige ;
- boue ;
- rochers ;
- falaises ;
- corde ;
- escalier attaché à structure verticale ;
- zone de grimpe ;
- points d’ancrage ;
- danger chute.

Le HUD ne doit pas tout afficher en permanence. Il doit afficher :

- un indicateur discret quand le système comprend le terrain ;
- un prompt clair quand une action devient possible ;
- une alerte si le risque est élevé ;
- un module complet seulement si le joueur grimpe ou interagit.

---

## 17. Thèmes dynamiques selon ambiance du monde

### 17.1 Ambiance globale

```swift
struct WorldAmbienceUIState {
    let mood: WorldMood
    let danger: Float
    let mystery: Float
    let corruption: Float
    let sacredness: Float
    let technologyReliability: Float
    let magicFlux: Float
    let weatherSeverity: Float
    let biomeColorInfluence: SIMD3<Float>
}
```

### 17.2 Modulation subtile vs changement radical

Il faut deux niveaux :

1. **Theme base** : déterminé par seed au chargement du monde.
2. **Theme modulation** : change en runtime selon le contexte.

Exemples :

- entering desert → poussière + chaleur sur edges ;
- entering sacred biome → glyphes plus lumineux ;
- entering enemy territory → teinte faction hostile ;
- night → luminance réduite ;
- storm → bruit et jitter légers ;
- cursed zone → corruption progressive du HUD ;
- high danger → densité d’informations augmente.

### 17.3 Ne pas faire changer tout le HUD trop souvent

Si le HUD change trop, le joueur perd ses repères. Il faut :

- conserver les emplacements essentiels ;
- animer lentement les transitions de thème ;
- limiter les changements majeurs aux états narratifs/biomes importants ;
- utiliser des micro-modulations pour le reste.

---

## 18. Génération des ornements, cadres et patterns

### 18.1 Ornament grammar

```text
OrnamentGrammar
├── strokes
├── corners
├── knots
├── glyphs
├── cracks
├── rivets
├── leaves
├── circuits
├── veins
├── crystals
├── runes
├── stains
├── scratches
└── procedural masks
```

### 18.2 Techniques

- bruit fractal ;
- masks procéduraux ;
- distance fields ;
- L-systems pour motifs végétaux ;
- grammaires de formes ;
- symétries ;
- motifs tilables ;
- atlas générés offline ;
- variation runtime légère ;
- decals UI ;
- erosion/damage masks.

### 18.3 Exemples par thème

| Thème | Ornements |
|---|---|
| Druidique | lianes, feuilles, racines, spores |
| Steampunk | vis, rivets, jauges, engrenages |
| Cyberpunk | circuits, scanlines, data strips |
| Parchemin | encre, taches, coins brûlés |
| Alien | symboles radiaux, asymétrie, bioluminescence |
| Corporate | lignes nettes, grilles, IDs, codes-barres |
| Nécromancien | os, cire, fissures, glyphes sombres |
| Spatial | telemetry, panels, caution stripes |
| Biotech | veines, membranes, fluides |

---

## 19. Material system pour l’UI

L’UI doit avoir ses propres matériaux, proches du pipeline PBR mais optimisés 2D/overlay.

```swift
struct UIMaterial {
    let baseColor: ColorToken
    let opacity: Float
    let roughness: Float
    let metallic: Float
    let emission: Float
    let normalIntensity: Float
    let proceduralNoise: NoiseParams
    let edgeWear: Float
    let wetness: Float
    let dirt: Float
    let glow: GlowParams
    let distortion: DistortionParams
}
```

### 19.1 Matériaux dynamiques

- pluie → wetness augmente ;
- désert → dust augmente ;
- neige → frost mask ;
- corruption → cracks/glow instable ;
- magie → emission/glyph intensity ;
- low tech → flicker/interference ;
- damage joueur → edges rouges, mais contrôlés ;
- poison → veines vertes discrètes ;
- radiation → noise + warning symbols.

### 19.2 UI et post-process

Le HUD ne doit pas être détruit par le post-process scène. Il faut plusieurs modes :

- HUD non affecté ;
- HUD légèrement affecté par ambiance ;
- HUD diegetique affecté par lumière/blur ;
- HUD critique rendu au-dessus de tout.

---

## 20. Accessibilité et lisibilité

### 20.1 Règle absolue

Une UI procédurale qui devient illisible est un bug, pas une variante artistique.

### 20.2 Validateurs automatiques

Chaque thème doit passer :

- contraste texte/fond ;
- taille minimum ;
- lisibilité icône ;
- distance entre éléments ;
- distinction sans couleur ;
- test daltonisme approximatif ;
- motion safety ;
- safe area ;
- focus graph valide ;
- navigation manette ;
- test localisation longue ;
- test basse luminosité ;
- test haute densité.

### 20.3 Modes d’accessibilité

- contraste renforcé ;
- texte large ;
- HUD stable ;
- réduire mouvement ;
- réduire effets glitch ;
- réduire transparence ;
- outlines forts ;
- icons + labels ;
- daltonisme ;
- prompts persistants ;
- simplification HUD ;
- mode lecture dialogue ;
- pause automatique sur textes importants.

### 20.4 Bridge sémantique

Même si un panel est rendu en Metal, le système doit avoir une représentation :

```swift
struct UIAccessibleNode {
    let id: UIElementID
    let role: UIRole
    let label: String
    let value: String?
    let hint: String?
    let frame: CGRect
    let isFocusable: Bool
    let actions: [UIAccessibleAction]
}
```

Cela peut alimenter une couche SwiftUI/AppKit invisible ou un bridge accessibility custom.

---

## 21. Data model et authoring

### 21.1 Fichiers de données

Proposition :

```text
Resources/UI
├── themes/
│   ├── primitive_survival.ui-theme.json
│   ├── medieval_grimoire.ui-theme.json
│   ├── cyberpunk_ar.ui-theme.json
│   └── biotech_membrane.ui-theme.json
├── recipes/
│   ├── health_cluster.ui-recipe.json
│   ├── inventory_grid.ui-recipe.json
│   └── quest_tracker.ui-recipe.json
├── glyphs/
├── icons/
├── fonts/
├── materials/
├── animations/
└── validators/
```

### 21.2 Theme archetype data

```json
{
  "id": "steampunk_mechanical",
  "baseStyle": "industrial",
  "eraTags": ["steam", "mechanical", "analog"],
  "materials": ["brass", "copper", "glass", "aged_paper"],
  "shapeLanguage": "circular_gauges",
  "motionProfile": "mechanical_ticks",
  "ornamentRules": ["rivets", "gears", "engraved_frames"],
  "forbiddenCombos": ["neon_cyber", "organic_membrane"],
  "minimumContrast": 4.5
}
```

### 21.3 Component recipe

```json
{
  "id": "health_cluster",
  "semanticRole": "player_health",
  "layoutFamilies": ["bar", "orb", "segmented", "gauge", "vessel"],
  "themeBindings": {
    "primitive": "blood_mark_segments",
    "medieval": "vitality_seal",
    "industrial": "pressure_gauge",
    "cyberpunk": "biometric_bar",
    "biotech": "pulsing_membrane"
  },
  "criticalRules": {
    "alwaysLabelBelow30Percent": true,
    "forceHighContrast": true,
    "disableDecorativeNoise": true
  }
}
```

### 21.4 Authoring futur

D’abord : JSON/YAML + Swift structs + hot reload.  
Ensuite : éditeur SwiftUI interne.  
Plus tard : node graph visuel pour thèmes et animations.

---

## 22. Runtime state management

### 22.1 UIStateStore

Centraliser l’état UI :

```swift
final class UIStateStore {
    var screens: [UIScreenID: UIScreenState]
    var activeStack: [UIScreenID]
    var focus: UIFocusState
    var inputMode: UIInputMode
    var theme: UIThemeInstance
    var snapshots: UIFrameSnapshot
}
```

### 22.2 Éviter les dépendances directes

Un widget ne doit pas lire directement `Player`, `WorldGenerator`, `InventorySystem`. Il lit un snapshot ou un binding.

```swift
struct UIBinding<T> {
    let path: UIStatePath
    let fallback: T
}
```

### 22.3 Event bus UI

```text
UIEvent
├── ButtonPressed
├── FocusChanged
├── MenuOpened
├── MenuClosed
├── InventorySlotSelected
├── QuestPinned
├── DialogueChoiceSelected
├── ThemeModulationChanged
├── AccessibilityModeChanged
└── DebugTokenEdited
```

---

## 23. Intégration avec les autres systèmes IsoWorld

### 23.1 Avec le WorldGenerator

- UI seed dérivé du world seed.
- Biome courant module le HUD.
- Cartographie générée depuis terrain/chunks.
- Points d’intérêt alimentent map/quest tracker.

### 23.2 Avec le système RPG procédural

- Les règles RPG peuvent changer le type de HUD.
- Monde sans combat → pas de combat HUD.
- Monde mythique → objectifs sous forme de prophéties.
- Monde corporate → quests comme tickets/contracts.
- Monde sans technologie → pas de minimap GPS, mais carte approximative.

### 23.3 Avec le système de props

- UI diegetique sur terminaux, panneaux, livres, machines.
- Props interactifs fournissent leurs propres UI recipes.
- Un objet manufacturé peut avoir son micro-HUD.

### 23.4 Avec météo/cycle jour-nuit

- Modulation lumière UI.
- Condensation/pluie/neige sur UI diegetique.
- Alertes contextuelles.

### 23.5 Avec particules/FX

- FX UI légers.
- Rune particles.
- Glitch particles.
- Poussière/sable/neige sur overlay.
- Notifications avec micro-FX.

### 23.6 Avec animation/physique

- Prompts contextualisés pour grimpe, chute, équilibre.
- Feedback de glissade, adhérence, fatigue.
- HUD minimal pendant animations critiques.

---

## 24. Longue liste de systèmes UI à implémenter

### 24.1 Systèmes fondamentaux

1. UI theme resolver.
2. UI token generator.
3. UI token validator.
4. UI layout engine.
5. UI render command builder.
6. UI Metal renderer.
7. UI input router.
8. UI focus graph.
9. UI screen stack.
10. UI modal system.
11. UI animation graph.
12. UI material system.
13. UI text atlas.
14. UI icon atlas.
15. UI glyph generator.
16. UI state store.
17. UI binding system.
18. UI event bus.
19. UI accessibility bridge.
20. UI localization bridge.

### 24.2 Systèmes gameplay HUD

21. Player vitals HUD.
22. Survival HUD.
23. Combat HUD.
24. Stealth HUD.
25. Traversal HUD.
26. Climbing/rope HUD.
27. Vehicle HUD.
28. Mount/animal HUD.
29. Weather hazard HUD.
30. Biome hazard HUD.
31. Quest tracker.
32. World event banners.
33. Damage indicators.
34. Threat indicators.
35. Contextual action prompts.
36. Objective compass.
37. Discovery notifications.
38. Status effects.
39. Ability cooldowns.
40. Skill progression feedback.

### 24.3 Menus et écrans

41. Main menu.
42. Pause menu.
43. Settings.
44. Accessibility settings.
45. Controls/remapping.
46. Seed selection.
47. World generation screen.
48. Character creation.
49. Inventory.
50. Equipment.
51. Crafting.
52. Construction.
53. Map.
54. Journal.
55. Codex.
56. Dialogue.
57. Faction screen.
58. Reputation screen.
59. Trade screen.
60. Skill tree.
61. Quest log.
62. Save/load.
63. Photo mode.
64. Debug menu.
65. Profiler overlay.

### 24.4 Systèmes procéduraux avancés

66. Procedural frame generator.
67. Procedural ornament generator.
68. Procedural icon generator.
69. Procedural map style generator.
70. Procedural font pairing selector.
71. Procedural motion profile generator.
72. Procedural notification style generator.
73. Procedural faction UI skinning.
74. Procedural biome UI modulation.
75. Procedural item card generator.
76. Procedural quest card generator.
77. Procedural codex page layout.
78. Procedural skill tree layout.
79. Procedural radial menu layout.
80. Procedural terminal UI.
81. Procedural book UI.
82. Procedural hologram UI.
83. Procedural analog dashboard.
84. Procedural grimoire UI.
85. Procedural alien symbol UI.

### 24.5 Debug et tooling

86. Theme inspector.
87. Token inspector.
88. Contrast debugger.
89. Motion debugger.
90. Focus graph viewer.
91. Layout bounds viewer.
92. Draw call viewer.
93. UI overdraw heatmap.
94. Text atlas viewer.
95. Icon atlas viewer.
96. Accessibility node viewer.
97. Localization expansion test.
98. Seed compare tool.
99. Theme mutation tool.
100. Screenshot regression tool.

---

## 25. Qualité visuelle AAA : principes

### 25.1 Hiérarchie visuelle

Chaque écran doit avoir :

- 1 priorité principale ;
- 2 à 3 priorités secondaires ;
- le reste en soutien ;
- jamais 15 éléments qui crient en même temps.

### 25.2 Cohérence

- Une famille d’icônes.
- Une famille de cadres.
- Une famille de motion.
- Une famille de matériaux.
- Une famille sonore.
- Des règles stables pour danger/success/warning.

### 25.3 Réactivité

- Feedback immédiat sur input.
- Animation courte pour confirmer.
- Son optionnel.
- Focus clair.
- Latence minimale.

### 25.4 Sobriété dynamique

Le HUD doit apparaître quand il est utile et disparaître quand il gêne.

- Exploration calme → HUD minimal.
- Danger → HUD riche.
- Combat → HUD prioritaire.
- Dialogue → HUD narratif.
- Grimpe → HUD verticalité.
- Carte/inventaire → plein écran.

### 25.5 Diegèse optionnelle

Le HUD peut être justifié par un objet : carnet, montre, implant, grimoire, terminal, cristal, tatouage. Mais il faut garder un fallback non-diegetique pour la jouabilité.

---

## 26. Performance et budgets

### 26.1 Budgets cibles

Sur MacBook Pro M1, viser :

- HUD gameplay : < 0.5 ms GPU dans la majorité des frames ;
- menus complexes : < 1.5 ms GPU ;
- CPU layout stable : recalcul uniquement sur changement ;
- draw calls UI : idéalement batchés en quelques dizaines max ;
- atlas text/icon : cache persistant ;
- zéro allocation par frame dans le path chaud ;
- animations évaluées en batch.

### 26.2 Optimisations

- Dirty flags sur layout.
- Cache de geometry pour widgets statiques.
- Atlas textures.
- Pipeline state cache.
- Tri par material/pipeline.
- Clip rects groupés.
- Instancing pour icônes/jauges.
- SDF shapes en shader.
- Pré-bake des ornements complexes.
- LOD UI : réduire ornements sur faible budget.
- Culling des panels invisibles.
- Réduction automatique en mode battery/thermal.

### 26.3 Dégrader intelligemment

Quand le budget baisse :

1. réduire particules UI ;
2. réduire bruit/glitch ;
3. désactiver normal maps UI ;
4. réduire blur ;
5. simplifier ombres ;
6. réduire ornements ;
7. garder texte et icônes critiques intacts.

---

## 27. Roadmap d’implémentation

### Phase 0 — Fondations rapides

- Garder SwiftUI pour menus basiques.
- Ajouter overlay HUD prototype SwiftUI si nécessaire.
- Définir `UIFrameSnapshot`.
- Définir `UIWorldDNA`.
- Définir tokens de base.
- Créer 3 thèmes simples : neutral, parchment, sci-fi.

### Phase 1 — Custom Metal HUD minimal

- `UIMetalRenderer` quads + atlas.
- `UILabel` simple.
- `UIImage/Icon`.
- `UIPanel`.
- `ProgressBar`.
- `HUDRoot`.
- Draw command batching.
- Snapshot player health/stamina/weather/biome.

### Phase 2 — Layout retained-mode

- Arbre UI.
- Stack/grid/anchor/radial.
- Dirty layout.
- UI state store.
- Input router.
- Focus graph manette.

### Phase 3 — Theme system

- JSON themes.
- Token resolver.
- Theme validator.
- Procedural modulation biome/weather/faction.
- 10 archétypes UI.
- Screenshots comparatifs par seed.

### Phase 4 — Menus in-game stylisés

- Inventory.
- Map.
- Quest log.
- Dialogue.
- Crafting.
- Settings restent SwiftUI ou bridge.

### Phase 5 — Advanced rendering

- SDF/MSDF text.
- Procedural shapes.
- Masks/stencil.
- UI particles.
- Hologram/glitch/ink shaders.
- World-space UI.

### Phase 6 — Accessibility bridge

- Accessible nodes.
- Reduce motion.
- High contrast.
- Colorblind modes.
- Large text.
- Focus narration.

### Phase 7 — Authoring tools

- Theme inspector SwiftUI.
- Token editor.
- Layout bounds viewer.
- Contrast validator.
- Focus graph viewer.
- Seed mutation viewer.

### Phase 8 — Procedural iconography/glyphs

- Icon grammar.
- Glyph grammar.
- Faction symbols.
- Biome motifs.
- RPG concept icons.

---

## 28. Exemple de code conceptuel Swift

### 28.1 UI theme instance

```swift
struct UIThemeInstance {
    let id: UIThemeID
    let dna: UIWorldDNA
    let colors: UIColorTokens
    let typography: UITypographyTokens
    let shapes: UIShapeTokens
    let motion: UIMotionTokens
    let materials: UIMaterialTokens
    let icons: UIIconTokens
    let accessibility: UIAccessibilityTokens
}
```

### 28.2 Widget recipe

```swift
protocol UIWidgetRecipe {
    associatedtype State
    func build(context: UIRecipeContext, state: State) -> UINode
    func validate(theme: UIThemeInstance) -> [UIValidationIssue]
}
```

### 28.3 Renderer interface

```swift
protocol UIRenderBackend {
    func beginFrame(snapshot: UIFrameSnapshot)
    func submit(commands: [UIDrawCommand])
    func endFrame(commandBuffer: MTLCommandBuffer, target: MTLTexture)
}
```

### 28.4 Theme resolver

```swift
final class UIThemeResolver {
    func resolve(seed: UInt64,
                 world: WorldRPGDNA,
                 biome: BiomeState,
                 faction: FactionState?,
                 accessibility: UIAccessibilityState) -> UIThemeInstance {
        // 1. derive deterministic streams
        // 2. select archetype
        // 3. generate tokens
        // 4. apply biome/faction/mood modulation
        // 5. validate and repair contrast/motion/focus
        // 6. return immutable theme instance
    }
}
```

---

## 29. Risques techniques

### 29.1 Texte

Le text rendering est souvent sous-estimé. Il faut planifier tôt les questions de glyph atlas, shaping, localisation, fallback fonts, tailles, mesure et accessibilité.

### 29.2 Accessibilité

Un HUD custom peut devenir inaccessible si aucun bridge sémantique n’est prévu. Il faut stocker les rôles/labels/valeurs dès le modèle UI.

### 29.3 Trop de procédural

Un thème généré peut être incohérent ou kitsch. Il faut des archétypes forts, des règles de compatibilité et un validateur.

### 29.4 Performance des effets UI

Les blur/glow/glitch/particles peuvent coûter cher. Les effets décoratifs doivent être LODables.

### 29.5 Debugging

Sans tooling, un système procédural devient opaque. Il faut visualiser tokens, règles, arbre UI, focus, layout, draw calls.

---

## 30. Recommandation finale

Pour IsoWorld, la meilleure stratégie est :

1. **Conserver SwiftUI/AppKit pour tout ce qui est OS-native, outils, préférences, saisie texte et debug avancé.**
2. **Créer un renderer UI custom Metal pour tout le HUD et les menus stylisés in-game.**
3. **Construire IPUI autour d’un modèle retained-mode data-driven, pas autour d’écrans hardcodés.**
4. **Générer les thèmes via `UIWorldDNA` + design tokens + validateurs.**
5. **Autoriser des modulations runtime par biome/météo/faction/danger, mais garder les repères essentiels stables.**
6. **Prévoir accessibilité et lisibilité dès le début.**
7. **Utiliser un IMGUI uniquement pour les outils internes.**
8. **Avancer par phases : HUD minimal → layout → thème → menus → effets → accessibilité → authoring tools.**

La cible n’est pas “un HUD joli”. La cible est un **système d’interface procédurale**, capable de donner à chaque monde généré une identité forte, tout en restant jouable, lisible, performant et maintenable.

---

## 31. Références consultées

- IsoWorldPOC — repo GitHub : https://github.com/agaloppe84/IsoWorldPOC
- Apple Developer Documentation — `MTKView` : https://developer.apple.com/documentation/metalkit/mtkview
- Apple Developer Documentation — Creating a custom Metal view : https://developer.apple.com/documentation/Metal/creating-a-custom-metal-view
- Apple Metal sample code : https://developer.apple.com/metal/sample-code/
- Apple Human Interface Guidelines : https://developer.apple.com/design/human-interface-guidelines
- Apple HIG — Accessibility : https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple HIG — Color : https://developer.apple.com/design/human-interface-guidelines/color
- Apple HIG — Typography : https://developer.apple.com/design/human-interface-guidelines/typography
- Unreal Engine Common UI Overview : https://dev.epicgames.com/documentation/unreal-engine/overview-of-advanced-multiplatform-user-interfaces-with-common-ui-for-unreal-engine
- Unity UI Toolkit Manual : https://docs.unity3d.com/2023.2/Documentation/Manual/UIElements.html
- Dear ImGui GitHub : https://github.com/ocornut/imgui
- Rive State Machine Overview : https://rive.app/docs/editor/state-machine/state-machine
- Rive for Game UI : https://rive.app/game-ui
