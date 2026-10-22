# WonderMath (iPad)

A native iPad learning game (Swift, SwiftUI, SpriteKit, SwiftData). It runs landscape-only, works fully offline, and has no accounts, tracking, network calls or monetization. Its educational content comes from the **Marble Skill Taxonomy** in this repository (`data/`).

> Marble Skill Taxonomy (v1) · © Generative Spark, Inc. (Marble) · https://withmarble.com · licensed under ODbL 1.0 (database) and CC BY-SA 4.0 (content).

See [LICENSE-NOTICE.md](LICENSE-NOTICE.md). The attribution string is also shown in-app under **Parent Zone → About**.

## Status: vertical slice

| Area | State |
|---|---|
| World map (5 regions) | ✅ Number Kingdom playable; Worlds 2/3/4/5 shown with a lock and an explanatory "coming soon" sheet |
| World 1 mechanic "Repair the bridge" (missing number / balance the equation) | ✅ 19 Mathematics topics, deterministic generation and validation |
| Pattern path (stepping stones, logic/visual stage) | ✅ 5 Mathematics pattern topics |
| Hints (Nudge → Clue → Walkthrough), misconception feedback, "Why does this work?" | ✅ linked to `teaching-research.json`, with fallback for unresearched topics |
| Adaptive engine (raise on evidence, scaffold to `hard` prereqs, spaced review) | ✅ |
| XP, treasure chests, achievements, companion customization, daily adventure | ✅ |
| Parent dashboard (gate, time, mastery, improvement areas, offline activities, settings, attribution) | ✅ |
| Localization: English plus a German (Swiss) scaffold with Swiss number format (`1’234`) | ✅ |
| Worlds 2, 3, 5 content (logic / spatial / mystery) | ⏳ TODO: authored content required (see *Known limitations*) |
| World 4 Inventor's Workshop (Computing topics) | ⏳ TODO: topics are bundled and mapped, but no mechanic yet |

## Layout

```
apps/WonderMath/
├── project.yml                 XcodeGen spec (source of truth for the project)
├── WonderMath.xcodeproj        generated from project.yml
├── tools/build_taxonomy_subset.py   data import / filtering script
├── WonderMathCore/             Swift package — all logic, Foundation-only, tested with `swift test`
│   ├── Sources/WonderMathCore/
│   │   ├── Content/            Codable models (Topic, Dependency, TeachingRecord), TaxonomyStore, SkillGraph, WorldCatalog
│   │   ├── Puzzles/            PuzzleGenerator protocol, Equation, Bridge/PatternPath generators, misconception matcher
│   │   ├── Adaptive/           SkillProgress, AdaptiveEngine, DailyAdventurePlanner
│   │   ├── Progression/        XP, chests, achievements
│   │   └── Localization/       L10n keys, English + German (CH) tables, taxonomy translation table
│   └── Tests/WonderMathCoreTests/
├── WonderMath/                 iOS app target (SwiftUI + SpriteKit + SwiftData)
│   ├── Models/                 SwiftData: ChildProfile, MasteryRecord, Achievement, DailyAdventureLog
│   ├── Content/                AppState (loads the bundled taxonomy)
│   ├── Adaptive/               ProgressService (gameplay → engine → SwiftData)
│   ├── Puzzles/                PuzzleSession (one puzzle's state machine)
│   ├── Game/                   world map, topic path, BridgeScene (SpriteKit), puzzle UI, daily adventure, onboarding, companion, speech
│   ├── Parent/                 parent gate + dashboard
│   ├── Localization/           SwiftUI environment glue for the core Localizer
│   └── Resources/              Assets, Taxonomy/ (bundled JSON subset)
├── WonderMathTests/            hosted XCTest: SwiftData persistence round-trips
└── WonderMathUITests/          XCUITest flow that captures screenshots of the major screens
```

### Architecture

- **The core is separate from the UI.** All logic that decides learning outcomes lives in `WonderMathCore`: loading, the graph, puzzle generation and validation, adaptivity, rewards and localization. It depends only on Foundation, so it builds and its tests run on macOS and Linux (`swift test`). The app target is a thin SwiftUI/SpriteKit/SwiftData shell over it.
- **The taxonomy.** `TaxonomyStore` decodes the three JSON files and indexes topics by `id`. Decoding is lenient, and optional research fields are allowed to be missing. `SkillGraph` holds the forward edges (topic → prerequisites, split by `hard`/`soft`) and reverse edges (prerequisite → the topics it unlocks). It also provides a deterministic topological order (Kahn's algorithm, with ties broken by age band, then name). Edges whose endpoints fall outside the bundled subset are dropped.
- **Puzzles.** A `PuzzleGenerator` is bound to exactly one taxonomy topic `id`. `makePuzzle(sequence:difficulty:store:)` is a pure function of a seeded SplitMix64 RNG, so the same inputs always produce the same puzzle. Each `PuzzleInstance` carries:
  - an id, type, topic id, `evidenceIndex` and difficulty
  - its config (an equation or a sequence) and its answer choices
  - an interaction model (drag or tap)
  - three hints and a step-by-step explanation
  - "Why" info and a completion criterion
  - a table mapping each distractor answer to a misconception

  Validation is plain Swift arithmetic: `Equation.check` and `PuzzleValidator`. **No LLM is involved anywhere.** At generation time each equation is solved structurally and checked again, and a `precondition` guarantees there is exactly one answer. The tests also enumerate candidate answers to show uniqueness.
- **Evidence = mastery.** Each topic's `evidence[]` statements map one-to-one onto `MasteryCriteria.evidenceForms`. For example, for *Unknown in addition & subtraction* (`mt_3JgrHY221M`): evidence 0 is the result unknown, evidence 1 is the change unknown, evidence 2 is the start unknown, and evidence 3 is an oral explanation, which a puzzle can't assess. A topic is **mastered** once every assessable evidence item has 2 hint-free correct solves at or above the minimum difficulty **and** recent accuracy is at least 80%. Evidence items that are conversation-only are listed on the parent dashboard as offline checks.
- **Adaptivity.** The engine works on `MasteryRecord`, which serializes `SkillProgress`.
  - It raises difficulty after 3 consecutive independent solves.
  - It lowers difficulty after 2 struggles.
  - After 3 struggles at difficulty 1 it scaffolds to a prerequisite. It prefers the research `reteachPrerequisiteId` from the matched `assess.errorPatterns` entry; otherwise it uses the weakest unmastered `hard` prerequisite.
  - A topic unlocks when all of its bundled `hard` prerequisites are mastered.
  - Mastered topics come back for review in a Leitner schedule (1/3/7/14/30 days).
  - Response latency is recorded but **never** used to judge ability.
- **Hints and feedback.** The three hint levels draw on the research data:
  - **Nudge** is a generic prompt to notice the structure.
  - **Clue** names the inverse operation or the balance idea.
  - **Walkthrough** solves the puzzle step by step with the child's own numbers.

  For the child, a wrong answer is matched to a misconception (for example *used visible numbers*, *wrote the whole*, *running total*, *off by one*) and gets a gentle, localized message. The matched `errorPatterns` entry (its `pattern` and `nextMove`) is shown to parents. "Why does this work?" draws on `pedagogy` and `learn.activities`. For the 80 bundled Mathematics topics and 57 Computing topics that have no research record, it shows a neutral explanation built from the equation itself. Nothing breaks.
- **Persistence.** SwiftData stores everything locally only (no CloudKit container, no sync): `ChildProfile`, `MasteryRecord`, `Achievement` and `DailyAdventureLog`.

## Data import / filtering

The app bundles a **filtered, otherwise unmodified** subset of `data/`, built by:

```bash
python3 apps/WonderMath/tools/build_taxonomy_subset.py
```

Rules:
1. Topics are kept if `subject ∈ {Mathematics, Computing}` **and** their age band overlaps 7–12 (`ageRangeStart ≤ 12 && ageRangeEnd ≥ 7`).
2. Dependency edges are kept only if **both** endpoints were kept.
3. Teaching-research records are kept only for kept topics. `coverage` is recomputed for the subset.
4. Every output file gets a `subset` metadata block (filter rules, source file SHA-256, counts). Records are copied byte-for-byte as JSON values; no text is rewritten.

Result: 592 topics (535 Mathematics, 57 Computing), 1,165 edges, 455 research records. The output goes to `WonderMath/Resources/Taxonomy/` and is bundled as a folder reference (`Taxonomy/` inside the app bundle). The subset is a derivative database and stays under ODbL 1.0 / CC BY-SA 4.0. `curriculum-standards.json` is **not** bundled.

Domain names were read from disk, not assumed. Mathematics: Counting & Cardinality, Number Representation & Place Value, Addition & Subtraction, Multiplication & Division, Fractions, Algebra, Mathematical Thinking, Measurement, Geometry, Data & Statistics, Probability, Ratio & Proportion. Computing: Algorithms & Programming, Artificial Intelligence, Data Representation, Designing Digital Solutions, Digital Systems, Digital Tools & Collaboration, Privacy & Security.

## Build & run on a Mac

Requirements: macOS 14+, Xcode 15.4+ (Xcode 16 recommended), and an iPad simulator runtime on iOS 17 or later.

```bash
git clone https://github.com/yvescabre/os-taxonomy.git
cd os-taxonomy/apps/WonderMath

# optional: regenerate the project after editing project.yml
brew install xcodegen && xcodegen generate

open WonderMath.xcodeproj        # scheme "WonderMath", pick an iPad simulator, ⌘R
```

Command line:

```bash
# list simulators and pick an iPad
xcrun simctl list devices available | grep -i ipad

xcodebuild -project WonderMath.xcodeproj -scheme WonderMath \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build

# app unit + UI tests (UI tests attach screenshots to the .xcresult)
xcodebuild -project WonderMath.xcodeproj -scheme WonderMath \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -resultBundlePath build/WonderMath.xcresult test

# core logic tests (macOS or Linux, no simulator needed)
cd WonderMathCore && swift test
```

Use any iPad simulator name from `simctl list` (verified with Xcode 26.6 / iOS 26.5 on iPad Pro 13-inch (M5)). To export the UI-test screenshots: `xcrun xcresulttool export attachments --path build/WonderMath.xcresult --output-path build/shots`. The UI tests launch the app with `-UITestInMemory -UITestProfile Mia`, which uses an in-memory store and a pre-made profile so that the screenshots are reproducible.

## Screenshots

Captured on the iPad Pro 13-inch (M5) simulator (iOS 26.5), landscape.

**Onboarding**

![Onboarding](docs/screenshots/01-onboarding.png)

**World map**

![World map](docs/screenshots/02-world-map.png)

**Coming-soon world sheet**

![Coming-soon world sheet](docs/screenshots/18-coming-soon.png)

**Buddy sheet**

![Buddy sheet](docs/screenshots/19-buddy-sheet.png)

**Number Kingdom topic path**

![Number Kingdom topic path](docs/screenshots/03-topic-path.png)

**Bridge puzzle (stepping-stone sequence)**

![Bridge puzzle (stepping-stone sequence)](docs/screenshots/04-bridge-puzzle.png)

**Wrong plank: gentle feedback**

![Wrong plank: gentle feedback](docs/screenshots/05-gentle-feedback.png)

**Hints: Nudge → Clue → Walkthrough**

![Hints: Nudge → Clue → Walkthrough](docs/screenshots/06-hint-walkthrough.png)

**Bridge solved**

![Bridge solved](docs/screenshots/20-bridge-solved.png)

**Why does this work?**

![Why does this work?](docs/screenshots/07-why-does-this-work.png)

**Reward after solving**

![Reward after solving](docs/screenshots/08-reward.png)

**Treasure chest (every 5 solves)**

![Treasure chest (every 5 solves)](docs/screenshots/09-treasure-chest.png)

**Today's Adventure**

![Today's Adventure](docs/screenshots/10-daily-adventure.png)

**Parent gate**

![Parent gate](docs/screenshots/11-parent-gate.png)

**Parent dashboard**

![Parent dashboard](docs/screenshots/12-parent-dashboard.png)

**Parent dashboard scrolled: content & licences (Marble attribution)**

![Parent dashboard scrolled: content & licences (Marble attribution)](docs/screenshots/13-attribution.png)

**World map in German (Switzerland)**

![World map in German (Switzerland)](docs/screenshots/17-world-map-de-CH.png)

**Parent dashboard in German (Switzerland)**

![Parent dashboard in German (Switzerland)](docs/screenshots/14-parent-dashboard-de-CH.png)

**Topic path in German (Switzerland)**

![Topic path in German (Switzerland)](docs/screenshots/15-topic-path-de-CH.png)

**Bridge puzzle in German (Switzerland)**

![Bridge puzzle in German (Switzerland)](docs/screenshots/16-bridge-puzzle-de-CH.png)

## Tests

- `WonderMathCoreTests` (`swift test`):
  - taxonomy loading and graph integrity (acyclic, hard/soft split, unlocks, topological order)
  - world mapping
  - puzzle solvability and uniqueness across every generator × difficulty 1–5 × many seeds
  - determinism and distractor correctness
  - misconception diagnosis and its link to research
  - adaptive transitions: promote, demote, scaffold to a hard prerequisite, mastery that needs evidence *and* accuracy, gating, spaced review, next activity
  - localization: key and placeholder parity, Swiss number formatting, German names for every playable topic
  - Codable round-trips
- `WonderMathTests`: SwiftData persistence round-trips through `ProgressService`.
- `WonderMathUITests`: an end-to-end flow plus screenshots (world map, topic path, puzzle, hint, reward, locked world, parent gate, dashboard, onboarding).

## Known limitations

- **Which worlds use taxonomy content and which need authored content.** World 1 (Number Kingdom) uses taxonomy topics only. World 4 (Inventor's Workshop) maps all 57 bundled Computing topics, but has no puzzle mechanic yet. Worlds 2/3/5 (Logic Lagoon, Puzzle Peaks, Mystery Island) need original WonderMath content, because the dataset has few pure logic or spatial puzzles; they are stubbed with TODOs in `WorldCatalog.swift`. The logic stage of the daily adventure currently uses the taxonomy's Mathematics *pattern* topics.
- Only 24 of the 535 bundled Mathematics topics have generators so far. The others show on the parent dashboard and in the graph, but are not playable yet.
- **German (Swiss) is a scaffold.** All UI strings are translated, and topic names are translated for the playable topics. Taxonomy research text (offline activities, research tips) is English-only and appears only in the parent area, labelled as such; it is never shown to the child in German mode.
- Text-to-speech uses the system `AVSpeechSynthesizer` voices; there is no recorded audio.
- One child profile per device in this slice.
- Gating only counts hard prerequisites playable in the app; other prerequisites are treated as met and listed for parents.
