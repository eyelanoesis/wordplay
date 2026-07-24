// The nine dimensions' presentation: planetary glyphs, ink colors, and the
// honest explanations shown in tooltips. (Moved from the legacy codex.html;
// the Relation type itself lives in the engine.)
import { ALL_RELATIONS, type Relation } from "../engine";

export const RELS: readonly Relation[] = ALL_RELATIONS;

export interface RelMeta {
  name: string;
  glyph: string;
  color: string;
  explanation: string;
}

export const REL_META: Record<Relation, RelMeta> = {
  anagram: {
    name: "Anagram",
    glyph: "☉", // Sol — gold: the same matter, transmuted
    color: "#f2991a",
    explanation: "both words use exactly the same letters, rearranged (silent / listen)",
  },
  oneLetter: {
    name: "One letter",
    glyph: "☽", // Luna — silver: waxing, waning by one
    color: "#4080f2",
    explanation:
      "changing, adding, or dropping one letter turns one word into the other (word → ward)",
  },
  homophone: {
    name: "Homophone",
    glyph: "☿", // Mercury — the twin-tongued messenger
    color: "#995ae6",
    explanation: "spelled differently but pronounced exactly the same (pair / pear)",
  },
  rhyme: {
    name: "Rhyme",
    glyph: "♀", // Venus — harmony of endings
    color: "#e64d73",
    explanation:
      "the words share their final sounds, from the last stressed vowel on (moon / June)",
  },
  fusion: {
    name: "Fusion",
    glyph: "♂", // Mars — two forged into one
    color: "#26b373",
    explanation:
      "the words overlap by sound and fuse into one audible pseudo-word (brain ⋈ angel → brangel)",
  },
  hidden: {
    name: "Hidden inside",
    glyph: "♄", // Saturn — lead, buried within
    color: "#bf991a",
    explanation: "one word is spelled, letter for letter, inside the other (ear inside heart)",
  },
  audible: {
    name: "Heard inside",
    glyph: "♃", // Jupiter — the voice within the voice
    color: "#26a6bf",
    explanation:
      "one word can be heard inside the other's pronunciation, whatever the spelling (cane inside hurricane)",
  },
  reversal: {
    name: "Reversal",
    glyph: "♆", // Neptune — the mirror sea (a modern)
    color: "#666b8c",
    explanation: "one word is the other spelled backwards (stressed / desserts)",
  },
  association: {
    name: "Association",
    glyph: "♅", // Uranus — the electric kinship (a modern)
    color: "#cc40b8",
    explanation:
      "the words keep close company in meaning — semantic neighbors from an on-device map, precomputed on a Mac and shipped as data",
  },
};
