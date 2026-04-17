# Sun Tzu iOS — Spécification d'implémentation

**Version du jeu**: Alan M. Newman, Asmodee/Nexus 2008 (règles françaises du jeu de plateau).
**Usage**: Personnel, non-distribué, non-commercial.
**Auteur**: Cyprien Hallé.
**Destinataire**: Claude Code (ou équivalent) pour scaffolding et implémentation itérative.

-----

## 0. Comment utiliser cette spec

Cette spec est **autoportante**. Tout ce dont tu as besoin pour scaffolder, implémenter et tester le projet est dedans.

### Consignes à Claude Code

1. **Ne pas poser de questions bloquantes.** Pour tout point d'ambiguïté, utiliser les defaults documentés en §13. Les marquer avec un commentaire `// DEFAULT: see SPEC §13 Q#X` dans le code.
1. **Procéder milestone par milestone (§12).** À chaque fin de milestone :
- Commit git
- `swift test`
- Rapport des résultats (pass/fail par test)
- Attendre confirmation utilisateur avant le milestone suivant
1. **TDD rouge → vert.** Les tests de chaque milestone sont spécifiés. Écrire les tests avant l'implémentation.
1. **Zéro dépendance externe** pour le core engine. XCTest uniquement.
1. **Pas d'UI avant M13.** Même si ça démange.
1. **Swift 6 strict concurrency.** Tous les types métier `Sendable`.
1. **Déterminisme.** RNG seeded, pas de `Date()`, `UUID()` OK pour identité des cartes.
1. **Langue.** Documentation inline en anglais, identifiants en anglais, commentaires peuvent référencer les termes français du jeu (QIN, Peste, etc.).
1. **Architecture immuable.** Les fonctions du moteur prennent `GameState` en entrée et retournent un nouveau `GameState`. Pas de classes, pas de mutations en place (sauf via `inout` local à une fonction).

### Conventions

- `⚠️` : point d'attention réglementaire
- `TODO` : à implémenter (avec référence à la section de cette spec)
- `DEFAULT` : choix par défaut pour une règle ambiguë, voir §13
- `RESOLVED` : valeur confirmée par l'utilisateur

-----

## 1. Vue d'ensemble du produit

**Objectif**: Recréer fidèlement *Sun Tzu* en app iOS native pour jouer en solo contre une IA.

### Scope V1

- Jeu solo vs. IA (3 niveaux : random, heuristique, MCTS)
- Mode standard + mode débutant
- Variante cartes Événement (optionnelle)
- Sauvegarde locale d'une partie en cours
- UI SwiftUI native iPhone

### Out of scope V1

- Multijoueur (hot-seat, online async)
- Tutoriel interactif
- Animations de cartes complexes
- iPad optimisations (fonctionne mais pas optimisé)
- Localisation EN (FR uniquement)
- Game Center, iCloud sync

-----

## 2. Tech stack

|Composant     |Choix                                                    |
|--------------|---------------------------------------------------------|
|Langage       |Swift 6                                                  |
|Plateforme    |iOS 17+                                                  |
|UI            |SwiftUI + SpriteKit (plateau)                            |
|Tests         |XCTest                                                   |
|Build         |Swift Package Manager (core engine) + Xcode project (app)|
|RNG           |xorshift64 seeded (implémentation dans la spec)          |
|Persistance   |`Codable` + fichier JSON dans `Documents/`               |
|CI (optionnel)|GitHub Actions, `swift test`                             |

**Zéro dépendance externe** dans le core engine. L'app peut consommer le core via SPM local.

-----

## 3. Architecture

### Principes

- **Hexagonale / DDD** : le cœur métier est un package Swift pur (`SunTzuCore`), sans dépendance UI ni I/O.
- **Fonctions pures** : les règles sont des fonctions `(GameState, Action) -> GameState`. Aucune mutation globale. Aucun singleton.
- **Valeur, pas référence** : tous les types d'état sont `struct`. Partage immutable via `Codable + Hashable`.
- **Déterminisme** : même seed + même séquence d'actions → même état final. Prérequis pour tests, replays, MCTS.

### Diagramme de dépendances (core)

```
Domain (types purs, aucune logique)
   ↑
Rules (fonctions pures sur Domain)
   ↑
Setup (constructeurs d'état initial)
```

L'UI et l'IA consommeront `Setup` et `Rules`. Elles ne manipuleront jamais directement les structs internes.

-----

## 4. Structure du projet

```
SunTzuCore/                          # SPM package
├── Package.swift                    # swift-tools-version: 6.0, iOS 17, macOS 14
├── README.md
├── SPEC.md                          # cette spec
├── Sources/SunTzuCore/
│   ├── Domain/
│   │   ├── Province.swift           # enum Province, enum Player, adjacency
│   │   ├── Card.swift               # CardValue, Card, StrategyCard, EventCard
│   │   ├── GameState.swift          # GameState, ProvinceState, PlayerState, Phase, ScoreDisplay, Placement
│   │   └── Action.swift             # GameAction, StrategyTarget, WithdrawalSource
│   ├── Rules/
│   │   ├── Rules.swift              # legalActions, apply, isTerminal, winner
│   │   ├── Combat.swift             # resolve, effectiveValue
│   │   ├── ArmyPlacement.swift      # applyCombatDelta, place
│   │   ├── Scoring.swift            # isScoringTurn, computeDelta, checkVictory
│   │   └── EventTriggers.swift      # applyPostCombatEvents (M7)
│   ├── Setup/
│   │   └── GameSetup.swift          # newGame, standardDeck, beginnerDeck
│   └── Util/
│       └── SeededRNG.swift          # xorshift64
└── Tests/SunTzuCoreTests/
    ├── DeckCompositionTests.swift   # M1
    ├── PlacementPhaseTests.swift    # M2
    ├── CombatTests.swift            # M3
    ├── ArmyPlacementTests.swift     # M4
    ├── ScoringTests.swift           # M5
    ├── StrategyCardTests.swift      # M6
    ├── EventCardTests.swift         # M7
    ├── DrawPhaseTests.swift         # M8
    ├── FullGameTests.swift          # M9
    └── InvariantTests.swift         # propriétés globales

SunTzu/                              # Xcode iOS app project (M13+)
├── SunTzu.xcodeproj
├── SunTzu/
│   ├── App/
│   ├── Views/
│   ├── ViewModels/
│   ├── Scene/                       # SpriteKit plateau
│   └── AI/                          # wrapper autour du MCTS
└── SunTzuTests/
```

-----

## 5. Règles du jeu

### 5.1 Constantes

|Élément                        |Valeur                                      |
|-------------------------------|--------------------------------------------|
|Joueurs                        |`BLUE` (Sun Tzu), `RED` (Roi Chu)           |
|Provinces                      |`QIN, CHU, JIN-YAN, HAN-QI, WU`             |
|Tours max                      |9                                           |
|Tours de décompte              |3, 6, 9                                     |
|Armées initiales               |18 (standard) / 21 (débutant)               |
|Renfort exceptionnel (setAside)|3 (standard) / 0 (débutant)                 |
|Cartes Action par joueur       |20 (standard) / 18 (débutant)               |
|Cartes permanentes en main     |6 (numériques 1..6)                         |
|Main initiale                  |10 cartes (6 permanentes + 4 piochées)      |
|Cartes Stratégie               |10 total, chaque joueur choisit 1 sur 5     |
|Cartes Événement               |5 (variante optionnelle)                    |
|Piste de score                 |9 cases de chaque côté (`scoreTrackMax = 9`)|

### 5.2 Composition de la pioche (RESOLVED)

**Standard (20 cartes par joueur)** :

- Numériques `1..10` : 1 de chaque (10 cartes)
- Bonus `+1` : 3 cartes
- Bonus `+2` : 1 carte
- Bonus `+3` : 1 carte
- Malus `-1` : 3 cartes
- Peste `P` : 2 cartes

**Débutant (18 cartes par joueur)** : standard moins `+2` et `+3`.

**Setup de la main** :

1. Les 6 cartes numériques `1..6` vont en main (permanentes).
1. Les 14 (ou 12 en débutant) autres sont mélangées en pioche.
1. Tirer 4 cartes du dessus → main de 10, pioche de 10 (ou 8 en débutant).

### 5.3 Structure d'un tour

Chaque tour = 5 phases :

1. **Avancement du pion compte-tours** (implicite dans `turn += 1`)
1. **Placement des cartes Action** (5 par joueur, face cachée)
1. **Révélation + résolution des combats** (5 résolutions)
1. **Décompte** (tours 3, 6, 9 uniquement)
1. **Pioche des nouvelles cartes**

### 5.4 Phase Placement

- Simultanée et secrète. Chaque joueur pose 5 cartes face cachée, une par province.
- ⚠️ **DEFAULT Q6** : placement simultané (les deux joueurs peuvent poser dans n'importe quel ordre, l'ordre importe peu puisque les cartes sont face cachée jusqu'à la révélation).
- Action : `placeCard(player, province, card)`.
- Transition vers Reveal quand `placements.count == 10` (5 par joueur).

### 5.5 Phase Reveal — ordre de révélation

- **Tour 1** : ordre fixe `QIN → CHU → JIN-YAN → HAN-QI → WU`.
- **Tours 2+** : le joueur avec le moins d'armées sur le plateau au début de la phase choisit l'ordre. Égalité → le dernier détenteur du privilège le conserve. Si personne n'en a jamais eu → ordre du tour 1.
- Action : `revealNext` résout la province suivante dans l'ordre courant.

### 5.6 Résolution d'un combat (§ critique)

#### 5.6.1 Valeur effective `effValue(own, opp)`

|`own`       |`opp`       |Résultat                                           |
|------------|------------|---------------------------------------------------|
|`numeric(n)`|tout        |`n`                                                |
|`bonus(+k)` |`numeric(m)`|`m + k`                                            |
|`malus(-1)` |`numeric(m)`|`m - 1`                                            |
|`malus(-1)` |`bonus(+k)` |`0` (le bonus l'emporte)                           |
|`bonus(+k1)`|`bonus(+k2)`|`k1` (la différence se calcule au niveau supérieur)|
|`plague`    |—           |traité séparément (§5.6.2)                         |

#### 5.6.2 Cas Peste

- **Deux Pestes simultanées** : une seule prise en compte.
  - ⚠️ **DEFAULT Q5** : celle du joueur *premier dans l'ordre de révélation* (typiquement le détenteur du privilège). L'autre est défaussée sans effet.
- **Une Peste + une carte non-Peste** :
  - Si la stratégie `pesteCounter` (`P=0`) est active côté adverse → la Peste est comptée comme attaque numérique de valeur 0, combat normal.
  - Sinon : effets de la carte adverse **totalement annulés**. Dans la province : `floor(armies / 2)` armées détruites, retournent dans la réserve du propriétaire.
  - Si la stratégie `pesteTotal` est active côté joueur de la Peste : **toutes les armées sauf 1** sont détruites.

#### 5.6.3 Cas normaux

```
valB = effValue(blueCard, redCard)
valR = effValue(redCard, blueCard)

si (blueCard.value == redCard.value) → tie, rien ne se passe
si (valB == valR) → tie, rien ne se passe
sinon:
  winner = (valB > valR) ? BLUE : RED
  delta  = |valB - valR|
  → appliquer §5.6.4
```

**Cas "deux bonus différents"** (PDF p.4) : par exemple `+1` vs `+3`. `delta = |k1 - k2| = 2`, winner = bonus le plus fort.

#### 5.6.4 Application du delta — 4 cas (PDF p.2)

Soit `n = province.armies`, `ctrl = province.controller`, `loser = winner.opponent`.

|Cas  |Condition                        |Effet                                                                                                                             |
|-----|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
|**A**|`ctrl == nil` OU `ctrl == winner`|`province.controller = winner` ; `province.armies += delta` ; `placeArmies(winner, delta, province)`                              |
|**B**|`ctrl == loser` ET `n > delta`   |`province.armies -= delta` ; `loser.reserve += delta`                                                                             |
|**C**|`ctrl == loser` ET `n == delta`  |`province.armies = 0` ; `province.controller = nil` ; `loser.reserve += n`                                                        |
|**D**|`ctrl == loser` ET `n < delta`   |`loser.reserve += n` ; `province.controller = winner` ; `province.armies = delta - n` ; `placeArmies(winner, delta - n, province)`|

#### 5.6.5 `placeArmies(player, count, province)` — priorité de prélèvement

```
fromReserve = min(count, player.reserve)
player.reserve -= fromReserve
remaining = count - fromReserve

tant que remaining > 0:
  1. essaie une province adjacente à `province`, contrôlée par `player`
  2. sinon, essaie toute autre province contrôlée par `player`
  pour la source retenue:
    take = min(remaining, source.armies)
    source.armies -= take
    si source.armies == 0 : source.controller = nil
    remaining -= take
```

⚠️ Quand plusieurs sources sont possibles (choix du joueur), cela doit être une action explicite `specifyWithdrawal` — pas un choix implicite du moteur.

#### 5.6.6 Déclencheurs post-combat

À vérifier après chaque résolution :

- Carte jouée `numeric(9)` + perdue + événement `defiChampion` actif → retirer 1 armée du perdant.
- Carte jouée `numeric(10)` + perdue + événement `defiHero` actif → retirer 2 armées.
- `pestesPlayedTotal` atteint 4 + événement `pandemie` actif → chaque joueur retire 1 armée (réserve en priorité, plateau sinon).
- `player.sixesPlayed` atteint 3 + événement `charsDeGuerre` actif → ce joueur choisit une 2e Stratégie.
- Stratégie `count7to10As6` : si le joueur a posé 7/8/9/10, valeur effective = 6, la province n'est **pas** marquée avec un `sixMarker`.

### 5.7 Phase Scoring (tours 3, 6, 9)

```
blueScore = Σ scoreDisplay[p].value(turn) pour chaque p contrôlée par BLUE
redScore  = Σ scoreDisplay[p].value(turn) pour chaque p contrôlée par RED
scoreTrack += (blueScore - redScore)

si |scoreTrack| == scoreTrackMax (= 9) → gameOver, winner = signe de scoreTrack
```

À la fin du tour 9, même si `|scoreTrack| < 9` → gameOver, winner = signe de scoreTrack.

### 5.8 Phase Draw

Pour chaque joueur :

1. Les cartes jouées `numeric(1..6)` retournent en main (permanentes).
1. Les autres cartes jouées sont **retirées du jeu** (pas de défausse, pas de retour en pioche).
1. Pioche : tirer 2 cartes du dessus du deck, en garder 1 en main, placer l'autre **en dessous** du deck.
- Si deck ne contient qu'1 carte : la prendre directement.
- Si deck vide : rien.

Action : `pickDrawCard(player, keep, bottom)`.

### 5.9 Cartes Stratégie

Chaque joueur tire au hasard 5 cartes Stratégie de sa couleur, en choisit 1 secrètement, les 4 autres retournent hors jeu.

#### Roi Chu (RED)

|ID                  |Effet                                                                                     |Fenêtre       |
|--------------------|------------------------------------------------------------------------------------------|--------------|
|`double6`           |Jouer la carte 6 dans une province où elle a déjà été jouée (outrepasse le marqueur)      |placement     |
|`removeArmy`        |Retirer 1 armée d'une province (retour réserve du joueur)                                 |T1-6, libre   |
|`pesteTotal`        |Modifie l'effet Peste jouée par ce joueur : toutes les armées sauf 1 détruites            |passive       |
|`pesteCounter` (P=0)|Contre une Peste adverse, qui compte comme attaque 0                                      |pendant reveal|
|`pesteBottomDiscard`|Après avoir joué une Peste, la remettre en bas de la pioche et défausser la 1ère du dessus|après reveal  |

#### Sun Tzu (BLUE)

|ID                  |Effet                                                                                   |Fenêtre     |
|--------------------|----------------------------------------------------------------------------------------|------------|
|`moveArmy`          |Déplacer 1 armée vers province adjacente vide ou contrôlée                              |T1-6, libre |
|`count7to10As6`     |Compter 7/8/9/10 comme 6, ne marque pas la province                                     |après reveal|
|`startBonus`        |`scoreTrack += 1` vers BLUE                                                             |setup       |
|`malusBottomDiscard`|Après avoir joué un `-1`, le remettre en bas de la pioche et défausser la 1ère du dessus|après reveal|
|`reinforce`         |Prendre 1 armée de la réserve, la placer dans une province contrôlée                    |T1-6, libre |

Chaque stratégie est jouable **1 fois**, sauf événement `charsDeGuerre` qui autorise une 2e.

### 5.10 Cartes Événement (variante optionnelle)

Mécanique : 5 cartes mélangées, 1ère retournée face visible. Dès que sa condition est remplie, effet appliqué, carte retirée, suivante retournée. **Quand la 5e est appliquée, la partie se termine immédiatement** (leader au `scoreTrack` gagne).

|Carte             |Condition                                         |Effet                                                                                  |
|------------------|--------------------------------------------------|---------------------------------------------------------------------------------------|
|`pandemie`        |4e Peste jouée globalement                        |Chaque joueur retire 1 armée (réserve en priorité, plateau sinon)                      |
|`charsDeGuerre`   |3e carte 6 jouée par un joueur                    |Ce joueur choisit une 2e Stratégie (DEFAULT Q7 : parmi les 4 non choisies initialement)|
|`defiChampion`    |Un joueur joue un 9 et perd                       |Ce joueur retire 1 armée                                                               |
|`defiHero`        |Un joueur joue un 10 et perd                      |Ce joueur retire 2 armées                                                              |
|`infanterieLegere`|Les deux joueurs posent un 1 dans la même province|Le joueur avec le moins de VP sur le `scoreTrack` gagne la province avec écart de 1    |

### 5.11 Renfort exceptionnel

À tout moment hors résolution de combat, un joueur peut :

- Défausser définitivement une carte non-permanente (pas `numeric(1..6)`). La carte est montrée à l'adversaire.
- `setAside -= 1 ; reserve += 1`.

Interdit si `setAside == 0`.

Action : `useRenfort(player, discarded)`.

### 5.12 Conditions de victoire

Vérifier dans cet ordre :

1. **Fin T3 ou T6** : si `|scoreTrack| == 9` → leader gagne, `phase = gameOver(winner)`.
1. **Fin T9** : `phase = gameOver(winner)`, `winner = scoreTrack > 0 ? BLUE : scoreTrack < 0 ? RED : tiebreak`.
1. **Événements** : quand la 5e carte événement est appliquée → `phase = gameOver(winner)`.
1. **Tiebreak à T9** : si `scoreTrack == 0`, vainqueur = joueur avec le plus d'armées en réserve. Si encore égalité → `gameOver(winner: nil)`.

-----

## 6. Modèle de données (Swift)

Types implémentés dans `Sources/SunTzuCore/Domain/`. Voir les fichiers Swift pour les signatures définitives.

### 6.3 RNG

```swift
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
```

-----

## 7. API publique

### 7.1 `Rules`

```swift
public enum Rules {
    public static func legalActions(in state: GameState) -> [GameAction]
    public static func apply(_ action: GameAction, to state: GameState) throws -> GameState
    public static func isTerminal(_ state: GameState) -> Bool
    public static func winner(of state: GameState) -> Player?
}

public enum RulesError: Error, Equatable {
    case illegalAction(String)
    case malformedState(String)
    case notImplemented(String)
}
```

### 7.2 `GameSetup`

```swift
public enum GameSetup {
    public static func newGame(seed: UInt64, beginner: Bool = false, events: Bool = false) -> GameState
    static func standardDeck(owner: Player) -> [Card]
    static func beginnerDeck(owner: Player) -> [Card]
}
```

-----

## 8. Stratégie de test

### 8.1 Pyramide

- **Unit** : chaque fonction pure testée isolément.
- **Intégration** : enchaînements de phases.
- **Propriété** : invariants qui doivent tenir à tout moment (§8.3).
- **End-to-end** : parties complètes scriptées.

### 8.2 Déterminisme

Tous les tests utilisent un `seed` explicite. Aucun test ne dépend de `Date()` ou d'un RNG non-seeded.

### 8.3 Invariants globaux

Pour chaque joueur, à tout moment :

- `reserve + setAside + armies_sur_plateau + armies_retirées == army_count_initial`
- `0 ≤ hand.count ≤ 10`
- `deck.count + hand.count ≤ 20` (standard) ou `≤ 18` (débutant)

Pour chaque province :

- `armies == 0 ⇔ controller == nil`
- `armies ≥ 0`

Global :

- `placements.count ∈ {0, 1, 2, ..., 10}` pendant placement
- `phase == gameOver ⇔ Rules.isTerminal(state)`
- `0 ≤ pestesPlayedTotal ≤ 4`

-----

## 9. Cas de test concrets

(Voir tests unitaires à partir de M1 pour les détails. Cas référencés dans §12.)

-----

## 10. IA (M10-M12)

- **M10 Random baseline** : choix uniforme dans `Rules.legalActions`.
- **M11 Heuristique** : fonction d'évaluation manuelle + minimax profondeur 2.
- **M12 MCTS** : Determinized MCTS, ~1000 simulations / coup.

-----

## 11. Phase UI (M13+)

- **Scene plateau** : SpriteKit.
- **HUD** : SwiftUI.
- **ViewModel** : `@Observable` class exposant `GameState`.
- **Store** : sérialisation JSON dans `Documents/`.

-----

## 12. Plan de milestones

| M | Scope |
|---|-------|
| M0 | Scaffold package, signatures publiques, SeededRNG, `swift build` passe |
| M1 | Setup & composition de deck (8 tests) |
| M2 | Placement phase (6 tests) |
| M3 | Combat resolution cas basiques (9 tests) |
| M4 | Army placement 4 cas + withdrawal |
| M5 | Scoring & victory |
| M6 | Draw phase |
| M7 | Strategy cards (10 tests) |
| M8 | Event cards (5 tests) |
| M9 | Full game loop & invariants (fuzz 100 parties) |
| M10 | Random AI |
| M11 | Heuristic AI |
| M12 | MCTS AI |
| M13 | UI iOS SwiftUI + SpriteKit |

Chaque milestone : TDD, commit git, `swift test`, rapport pass/fail, attendre confirmation utilisateur.

-----

## 13. Questions ouvertes — defaults et validations

|#|Question                             |Status    |Default (code)                                                   |Validation requise                         |
|-|-------------------------------------|----------|-----------------------------------------------------------------|-------------------------------------------|
|1|Composition exacte de la pioche      |✅ RESOLVED|{1..10} + 3×+1 + 1×+2 + 1×+3 + 3×-1 + 2×P                        |—                                          |
|2|Taille de la piste de score          |✅ RESOLVED|`scoreTrackMax = 9`                                              |—                                          |
|3|Adjacence des provinces              |⚠️ DEFAULT |`Province.adjacency` (Risk-style hypothétique)                   |Vérifier sur le plateau physique avant M4  |
|4|Valeurs des 10 présentoirs de Score  |⚠️ UNKNOWN |`ScoreDisplay(t3:0, t6:0, t9:0)` stub                            |À transcrire depuis les composants avant M5|
|5|Deux Pestes simultanées              |⚠️ DEFAULT |Celle du 1er dans l'ordre de révélation résout, l'autre défaussée|Accepter ou préciser avant M7              |
|6|Placement simultané ou séquentiel    |⚠️ DEFAULT |Simultané (information cachée)                                   |Accepter avant M2                          |
|7|"Chars de guerre" — pool 2e Stratégie|⚠️ DEFAULT |Parmi les 4 non choisies                                         |Accepter avant M8                          |

-----

## 15. Glossaire

|FR (jeu)            |EN (code)         |
|--------------------|------------------|
|Armée               |Army              |
|Province            |Province          |
|Réserve             |Reserve           |
|Pioche              |Deck              |
|Main                |Hand              |
|Piste de score      |ScoreTrack        |
|Présentoir de score |ScoreDisplay      |
|Décompte            |Scoring           |
|Carte Action        |Card              |
|Carte Stratégie     |StrategyCard      |
|Carte Événement     |EventCard         |
|Peste               |Plague / `plague` |
|Renfort exceptionnel|setAside / renfort|
|Bonus / Malus       |bonus / malus     |
|Tour                |Turn              |

-----

## 16. Checklist finale avant chaque commit

- [ ] `swift build` passe
- [ ] `swift test` : tous verts
- [ ] Pas de warning Swift 6 concurrency
- [ ] Doc-comment de haut de fichier
- [ ] Pas de dépendance externe ajoutée
- [ ] `// DEFAULT: see SPEC §13 Q#X` présent là où c'est appliqué

-----

**Fin de spec.**
