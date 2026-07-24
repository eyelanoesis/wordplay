// Sound: sine chimes, phonetic-consonance harmony, and the browser's own
// voice. Moved verbatim from the legacy codex.html; pronunciations now come
// from the engine adapter.
import type { Relation } from "../engine";
import { pronOf } from "./engineAdapter";
import { S } from "./settings";

const VOWELS = new Set([
  "AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER",
  "EY", "IH", "IY", "OW", "OY", "UH", "UW",
]);

let AC: AudioContext | null = null;

export function tone(freq: number, amp = 0.14, when = 0, dur = 1.2): void {
  if (!S.chimesOn) return;
  if (!AC) AC = new AudioContext();
  const t0 = AC.currentTime + when;
  const osc = AC.createOscillator(),
    gain = AC.createGain();
  osc.type = "sine";
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0.0001, t0);
  gain.gain.exponentialRampToValueAtTime(amp, t0 + 0.012); // soft attack
  gain.gain.exponentialRampToValueAtTime(0.0006, t0 + dur);
  osc.connect(gain).connect(AC.destination);
  osc.start(t0);
  osc.stop(t0 + dur + 0.05);
}

export const CHIME: Record<Relation | "seed", number> = {
  seed: 523.25,
  anagram: 261.63,
  oneLetter: 293.66,
  homophone: 329.63,
  rhyme: 392,
  fusion: 440,
  hidden: 587.33,
  audible: 659.26,
  reversal: 783.99,
  association: 880.0,
};

// ── consonance: how alike two pronunciations sound, in [0,1] ──────────────
export function consonance(a: string, b: string): number {
  const pa = pronOf(a),
    pb = pronOf(b);
  if (!pa || !pb || !pa.length || !pb.length) return 0.5; // unknown → neutral
  const setA = new Set(pa),
    setB = new Set(pb);
  let inter = 0;
  for (const p of setA) if (setB.has(p)) inter++;
  const jaccard = inter / (setA.size + setB.size - inter);
  let tail = 0;
  const m = Math.min(pa.length, pb.length);
  while (tail < m && pa[pa.length - 1 - tail] === pb[pb.length - 1 - tail]) tail++;
  const tailScore = tail / m;
  const va = pa.filter((p) => VOWELS.has(p)),
    vb = pb.filter((p) => VOWELS.has(p));
  const vset = new Set(vb);
  let vs = 0;
  for (const v of va) if (vset.has(v)) vs++;
  const vowelScore = va.length ? vs / Math.max(va.length, vb.length) : 0;
  const lenPen = 1 - Math.abs(pa.length - pb.length) / (pa.length + pb.length);
  return Math.max(0, Math.min(1, 0.45 * jaccard + 0.3 * tailScore + 0.15 * vowelScore + 0.1 * lenPen));
}

// Consonant intervals for alike pairs, dissonant ones for unlike pairs.
const CONSONANT_IV = [12, 7, 5, 9, 4, 3]; // octave, P5, P4, M6, M3, m3
const DISSONANT_IV = [10, 2, 11, 6, 1]; // m7, M2, M7, tritone, m2

export function intervalFor(c: number): number {
  if (c >= 0.5) {
    return CONSONANT_IV[Math.min(CONSONANT_IV.length - 1, Math.floor(((1 - c) / 0.5) * CONSONANT_IV.length))]!;
  }
  return DISSONANT_IV[Math.min(DISSONANT_IV.length - 1, Math.floor(((0.5 - c) / 0.5) * DISSONANT_IV.length))]!;
}

const semis = (n: number): number => Math.pow(2, n / 12);

/**
 * The dimension picks the root pitch (its colour); the phonetic consonance
 * of the two words picks the interval stacked on top. Alike words ring as an
 * octave/fifth; unlike words as a tritone/second. You hear the likeness.
 */
export function harmonize(rel: Relation | null, wordA?: string, wordB?: string): void {
  const root = CHIME[rel ?? "seed"];
  tone(root, 0.13);
  if (wordA && wordB) {
    const iv = intervalFor(consonance(wordA, wordB));
    tone(root * semis(iv), 0.1, 0.04); // second voice, a hair later
  }
}

export function chime(rel: Relation | null): void {
  tone(CHIME[rel ?? "seed"], 0.13);
}

export function infection(): void {
  tone(185, 0.09);
  tone(196.6, 0.09, 0, 1.4);
}

/**
 * Sound a whole circle as one arpeggiated chord — the harmony of a word's
 * neighbourhood. A consonant chord means the word lives among words that
 * sound like it; a clashing chord means its connections pull every which way.
 */
export function soundNeighborhood(host: string, members: string[]): void {
  if (!S.chimesOn || !members.length) return;
  const root = CHIME.seed;
  tone(root, 0.11, 0, 1.6);
  members.slice(0, 6).forEach((w, i) => {
    const iv = intervalFor(consonance(host, w));
    tone(root * semis(iv), 0.08, 0.07 * (i + 1), 1.5); // gentle upward roll
  });
}

export function speak(word: string): void {
  if (!S.voiceOn || !("speechSynthesis" in window)) return;
  const u = new SpeechSynthesisUtterance(word);
  u.rate = 0.85;
  u.volume = 0.8;
  speechSynthesis.speak(u);
}

export const IV_NAME: Record<number, string> = {
  0: "unison", 1: "minor 2nd", 2: "major 2nd", 3: "minor 3rd", 4: "major 3rd",
  5: "perfect 4th", 6: "tritone", 7: "perfect 5th", 9: "major 6th", 10: "minor 7th",
  11: "major 7th", 12: "octave",
};
