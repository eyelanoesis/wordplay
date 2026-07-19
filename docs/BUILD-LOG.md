# Build log: from one pun to a living codex, in a single night

*A record of one working session (July 19, 2026, roughly midnight to
morning): a human directing an AI coding agent (Claude) from a
question about wordplay to a shipped macOS app, a web port, and a
published artifact. Written by the agent, directed and art-directed
throughout by [eyelanoesis](https://github.com/eyelanoesis). Kept
honest on purpose — including the wrong turns.*

---

## 1. The seed

The session opened with a question, not a spec:

> I hear the word "angel". I realize that it is nice to put "br" in
> front. When spoken, you hear both *angel* and *brain* and *gel*.
> What do we call this kind of wordplay?

The answer (an **overlapping blend**, perceived as a one-word
**oronym**) mattered less than what it implied: this is *computable*.
The app already bundled the CMU Pronouncing Dictionary for a rhymes
tool. Overlap detection in phoneme space is a suffix/prefix match.

**Fusions** shipped an hour later: for any word, scan all ~50k
pronounced dictionary words for phonetic overlaps at either end, rank
by overlap length, guess a written form, and — the good part — re-scan
the fused phoneme stream for *stowaway words* the ear would catch
("brangel" hides *rain* and *gel*), with one principled fuzz rule:
an unstressed schwa may impersonate any vowel, but only with three or
more phonemes of context. For "angel" the first real-dictionary run
produced *strangel* (strange ⋈ angel — "also hear: strain, train,
stranger, reign"). We checked for prior art and found letter-based
portmanteau generators, but nothing doing overlap fusion in phoneme
space with audible-bonus detection.

## 2. Everything is connected

The next directive was a thesis, not a feature: *"an app that will
let people understand that everything is connected."*

The app already knew seven kinds of edges between words — anagram,
one-letter step, homophone, rhyme, phonetic fusion, spelled-inside,
audible-inside — trapped in seven separate tools. So:

- **`ConnectionWeb`** — an aggregator giving any word its neighbors
  across all seven dimensions at once, first-relation-wins dedup.
- **`PathFinder`** — six degrees for words: bidirectional BFS over the
  mixed-relation graph. First single-ended version exhausted its
  60k-node budget on hard pairs in seconds; the bidirectional rewrite
  finds *fire → firm → term → water* in well under a second, and has
  yet to meet two English words it cannot connect.

## 3. Six looks, five misses

Then came the search for the *form* — the most instructive part of the
session. Version by version:

| v | Look | Verdict |
|---|------|---------|
| 4.1 | Indigo cosmos, glowing force-directed stars | "I like it. keep going" |
| 4.2 | Matrix rain, KJV verse chronicle | "leave the matrix thing" |
| 4.3 | Neutral research instrument | "I do want it biblical in that way" |
| 4.4 | Gold-leaf scriptorium, astrolabe on vellum | "not what I envisioned at all" |
| 4.5 | *Arrival* mist, logogram rings | "its more like… protein folding" |
| 5.x | Molecular viewer → firing neurons → glitch → viral spread | "it all looks the same to me. I want it to look completely different" |

That last note was the sharpest design feedback of the night, and it
was correct: five "different" skins were all the same form — glowing
dots and lines on a dark void. The fix was to change the *object*:

- **6.0** — the node-graph deleted entirely. The words themselves
  became the structure: a **self-writing crossword** on an endless
  page, words physically crossing at shared letters, each crossing
  cell tinted by the dimension that binds the pair. (This had been the
  user's idea in their *second message* of the night —
  "trans-dimensional crossword puzzles." It took the agent six
  versions to hear it.)
- **6.1** — the vision finally named: *"weird. Esoteric. Mystic. maybe
  a bit davincy like."* The **codex**: sigil circles chained across
  aged parchment, connections written in curved script around
  hand-wobbled rings, the seven dimensions marked with the seven
  classical planets (☉ ☽ ☿ ♀ ♂ ♃ ♄), mirror-written margin notes.
  The crossword survives as a toggle.

## 4. Making it alive

Three directives finished the thing: *"make it dynamic so that it
evolves"*, then memory, then voice.

- The codex **writes itself**: every few seconds it opens a circle
  around an uninscribed word, or returns to an old circle and deepens
  it with connections missed the first time.
- **Ink ages.** Fresh inscriptions are dark; over minutes they pale
  into the parchment, so the page's history is legible at a glance.
- **It forgets in order to continue.** Near capacity, the oldest
  unopened words fade and are reaped — birth and death in balance, so
  the page evolves indefinitely instead of saturating.
- **It remembers** across launches (state persisted and restored, so
  the ink is genuinely older when you return) and can **speak** each
  word as its circle opens.
- Each dimension has a pentatonic sine chime; a traced path plays as a
  melody; self-growth sounds a low detuned minor second.

## 5. The web port

"Can we make the web section into a webapp easily?" — the test of the
architecture. Because every engine is a pure algorithm over two text
files, the answer was a line-for-line port to JavaScript in one pass:

- [`web/fusions.html`](../web/fusions.html) — the fusion engine, 1.3 MB,
  lexicon embedded, works from a double-click on any OS.
- [`web/codex.html`](../web/codex.html) — the full living codex: canvas
  rendering, WebAudio chimes, browser speech, localStorage memory,
  3.6 MB, zero dependencies, offline forever.

The engines were verified headless (node) before the pages ever opened
in a browser: same *fire → firm → term → water* path, ~30 ms.

## 6. What the process was actually like

Worth recording, because the collaboration *is* the method:

- **Direction by taste, not spec.** The human's messages were rarely
  longer than a sentence. The information was in the *rejections* —
  each "no" carried a constraint ("biblical ≠ church") that no
  up-front brief would have surfaced.
- **Verification as a habit.** Every version: build, full test suite
  (34 tests by morning), package, relaunch, and — where possible —
  drive the actual UI and screenshot it. One accidental keystroke into
  the wrong app taught a hard lesson about automation while a human is
  at the keyboard; the practice changed immediately.
- **Version discipline on request** ("use revisioning numbers from now
  on"): 4.0.0 → 6.3.0 in one night, every bump meaningful.
- **The best ideas were the human's earliest ones.** The
  trans-dimensional crossword and the mystic register were both present
  in the first few messages. The agent's job turned out to be building
  fast enough, and listening carefully enough, for the human to
  recognize their own idea when it finally appeared on screen.

---

*The app: [Wordplay](https://github.com/eyelanoesis/wordplay) — eight
offline wordplay tools for macOS. The engines live in
`Sources/AnagramEngine/`; the codex in
`Sources/Anagrammer/SigilPageView.swift`; the web ports in `web/`.*
