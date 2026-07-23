// Generate public/data/lexicon.txt — the codex's pronunciation data:
//   word|STRESS-STRIPPED PHONES|RHYMEKEY
// one line per ENABLE word that has a cmudict pronunciation (first
// pronunciation only). Same format the legacy codex.html embeds. The rhyme
// key is computed from the stressed pronunciation (phonemes from the last
// stressed vowel onward, then stripped), exactly as Phonetics.swift does.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const dataDir = join(here, "..", "public", "data");

const enable = new Set(
  readFileSync(join(dataDir, "enable.txt"), "utf-8")
    .split("\n")
    .map((w) => w.toLowerCase())
    .filter((w) => /^[a-z]+$/.test(w)),
);

const stripStress = (p) => p.replace(/\d/g, "");

function rhymeKey(phonemes) {
  let lastStressed = -1;
  let lastVowel = -1;
  for (let i = 0; i < phonemes.length; i++) {
    const p = phonemes[i];
    if (/\d/.test(p)) {
      lastVowel = i;
      if (p.includes("1") || p.includes("2")) lastStressed = i;
    }
  }
  const start = lastStressed >= 0 ? lastStressed : lastVowel;
  if (start < 0) return "";
  return phonemes.slice(start).map(stripStress).join(" ");
}

const seen = new Set();
const lines = [];
for (const rawLine of readFileSync(join(dataDir, "cmudict.dict"), "utf-8").split("\n")) {
  let line = rawLine;
  const hash = line.indexOf("#");
  if (hash !== -1) line = line.slice(0, hash);
  const tokens = line.split(/[ \t]+/).filter((t) => t.length > 0);
  if (tokens.length < 2) continue;
  let word = tokens[0].toLowerCase();
  const paren = word.indexOf("(");
  if (paren !== -1) continue; // variants: first pronunciation only
  if (!enable.has(word) || seen.has(word)) continue;
  seen.add(word);
  const phonemes = tokens.slice(1);
  lines.push(`${word}|${phonemes.map(stripStress).join(" ")}|${rhymeKey(phonemes)}`);
}
lines.sort();

const out = join(dataDir, "lexicon.txt");
writeFileSync(out, lines.join("\n") + "\n");
console.log(`wrote ${lines.length} entries to ${out}`);
