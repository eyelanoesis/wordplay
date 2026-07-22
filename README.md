# Wordplay (v2)

A native macOS (SwiftUI) **wordplay toolkit**, fully offline. It began as a
clone of the **Internet Anagram Server** advanced form
(wordsmith.org/anagram/advanced.html) and now bundles nine tools behind a
sidebar:

1. **Anagrams** — rearrange every letter of a phrase into other words (the
   original I.A.S. feature, with the same filters).
2. **Rack Solver** — every word formable from a set of letters, ranked by
   Scrabble score; `?`/`*` act as blank tiles.
3. **Crossword** — pattern search; `?` = one letter, `*` = any run (e.g. `c?t`,
   `*tion`).
4. **Word Ladder** — shortest one-letter-at-a-time path between two words, plus
   add/drop/change-a-letter neighbours.
5. **Cryptic** — cryptic-crossword helpers: hidden words across phrase
   boundaries and exact single-word anagrams.
6. **Rhymes & Sounds** — rhymes, homophones, and syllable counts from the bundled
   CMU Pronouncing Dictionary.
7. **Fusions** — overlap two words by *sound* into one pseudo-word where both
   stay audible: brain ⋈ angel share /EY N/, giving "brangel" — in which you
   also hear *rain* and *gel*. (Linguistically: overlapping blends; perceptually:
   one-word oronyms.) Finds every dictionary word that phonetically overlaps
   your word's start or end, ranks by overlap length, and lists the bonus words
   hiding in the fused phoneme stream (a schwa may stand in for any vowel).
8. **Minimal Pairs** — the phonology tool: every word that differs by exactly
   one *phoneme* (`pat`/`bat`, `sip`/`ship`, `bit`/`beat`), grouped by the
   distinctive feature that separates the pair (voicing, place, manner, vowel
   height/backness, rounding) from an ARPABET feature table. Works in sound,
   not spelling — so it catches contrasts orthography hides — and every word
   is tappable to hear it spoken.
9. **Web** — everything is connected. Three pages over the same engines
   (the codex and the orrery share one model — one web, seen flat or in the
   round). Every automatic behavior is **off by default**: the seven relation
   dimensions, self-writing, sound, and voice all start dark and are switched
   on per session (dropdown checkboxes or the clickable legend). Pinch or
   two-finger scroll zooms every page.
   - **The codex** (default): an aged-parchment page where each word is
     inscribed at the center of a hand-drawn sigil circle, its connections
     written in curved script around the rim, each bearing the glyph of its
     dimension (the seven relations mapped to the seven classical planets:
     ☉ ☽ ☿ ♀ ♂ ♃ ♄). The codex **evolves**: it inscribes new circles on its
     own, revisits old ones to deepen them, ages its ink, and lets the oldest
     unopened words fade so it can write forever. It **remembers** across
     launches (Application Support/Wordplay/codex.json) and can **speak** its
     words aloud (toggle). Enter a second word for **six degrees**: a
     bidirectional BFS chains any two words across all seven dimensions.
   - **The crossword** (toggle): the same web as a self-writing crossword on
     an endless grid — words physically crossing at shared letters, crossing
     cells tinted by dimension.
   - **The orrery** (toggle): the codex's inscriptions in 3D — words chained
     outward from the seed inside faint armillary rings, navigated like a 3D
     modelling app: drag to orbit, ⌥-drag to pan, scroll/pinch to dolly.
   Each dimension has a pentatonic note (pure sine synthesis); self-growth
   plays a low detuned infection-interval. The camera button exports either
   page as a retina PNG.

Everything runs locally — no network, no rate limit. Three switchable
dictionaries (sidebar footer): **Scrabble (ENABLE)** — the clean default,
**System** — 236k words with the archaic tail, and **Biblical (KJV)** — a
curated lexicon of names, places, and King James vocabulary.

## The Anagrams tool

Rearranges the letters of a word or phrase into every valid combination of
dictionary words, with the same filters as the advanced form:

| Advanced-form option        | Here                          |
|-----------------------------|-------------------------------|
| Max # of anagrams (`t`)     | "Max anagrams to show"        |
| Max words per anagram (`d`) | "Max words"                   |
| Must include word           | "Must include word"           |
| Must exclude words          | "Exclude words"               |
| Min letters per word (`n`)  | "Min letters"                 |
| Max letters per word (`m`)  | "Max letters"                 |
| Repeat a word OK (`a`)      | "Allow a word to repeat"      |
| Show line numbers (`q`)     | "Show line numbers"           |
| Casing (`k`)                | "Output casing"               |

## Architecture

- `Sources/AnagramEngine/` — the pure, testable engine (no UI).
  - `LetterCount.swift` — 26-slot letter-count vector; anagram search is repeated
    subtraction of these.
  - `Dictionary.swift` — loads/cleans a word list (defaults to
    `/usr/share/dict/words`, ~236k words).
  - `AnagramEngine.swift` — depth-first multi-word search with pruning, a
    streaming `emit` callback, and cooperative cancellation.
  - `AnagramOptions.swift` — all the anagram form knobs.
  - `Scrabble.swift` / `RackSolver.swift` — tile scoring + sub-anagram search.
  - `PatternMatcher.swift` — glob (`?`/`*`) crossword matcher.
  - `WordLadder.swift` — BFS ladder + single-letter add/drop/change/behead.
  - `Phonetics.swift` — CMUdict parser: rhymes, homophones, syllables.
  - `Fusion.swift` — phonetic overlap search + audible-bonus-word scan.
  - `Connections.swift` — aggregates every relation type into one word-web.
  - `PathFinder.swift` — six-degrees bidirectional BFS across the mixed graph.
  - `MinimalPairs.swift` — one-phoneme-apart neighbours, labelled by the
    distinctive feature that differs (ARPABET feature table).
- `Sources/Anagrammer/` — SwiftUI front end. `WordStore` loads the dictionary
  once and vends every engine (CMUdict loads lazily on first use of the Rhymes
  tab). `RootView` is the sidebar; one `*View.swift` per tool. Queries run on
  detached tasks so the UI stays responsive.
- `Sources/Anagrammer/Resources/cmudict.dict` — bundled CMU Pronouncing
  Dictionary (~135k entries, public domain).

## Web sibling

`web/fusions.html` is the Fusions engine ported to JavaScript as a single
self-contained page — the pronouncing lexicon (ENABLE ∩ CMUdict, ~51k words)
rides inside the file (1.3 MB). It runs offline in any browser on any OS,
Linux included. Double-click it or send it to a friend.

## For developers

[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — build/test/package, the code
layout, the pattern for adding a tool, project conventions, the codex design
direction, and the roadmap. Start here to pick the project up cold.

## The story

[docs/BUILD-LOG.md](docs/BUILD-LOG.md) — how this went from one pun to
a living codex in a single night of human-AI collaboration, wrong
turns included.

## Build & run

```sh
swift run            # launches the app
swift test           # runs the engine test suite
swift build -c release
```

## Algorithm

1. Reduce the phrase to a 26-letter count vector (case folded, non-letters dropped).
2. Build *candidates*: dictionary words that fit the phrase and pass the
   length/exclude filters. Sorted longest-first so interesting anagrams surface early.
3. Depth-first search: pick a candidate that fits the remaining letters, subtract
   it, recurse on the remainder. Empty remainder = a complete anagram. A
   non-decreasing start index avoids re-emitting the same word-set in a different
   order; `allowRepeats` controls whether a word may be reused.
4. Pruning: stop a branch when remaining letters < shortest candidate, when the
   word-count ceiling is hit, or when the result cap is reached.

## Packaging as a .app

```sh
./package.sh
```

Produces `dist/Wordplay.app` — a real, double-clickable, ad-hoc-signed bundle
with an icon and the bundled CMUdict. Drag it to `/Applications` to install.
Ad-hoc signing runs freely on this Mac; distributing to others would need an
Apple Developer ID + notarization.

## Ideas / next steps

- Bundle a curated word list (the system dict includes archaic words; a
  SOWPODS/TWL Scrabble list gives cleaner results).
- Add language dictionaries (the original supports 10+ languages).
- Live-stream results into the UI instead of all at once.
- Haiku/limerick helper built on the syllable counter.
- Spoonerism generator (swap initial sounds) using the phonetic data.
