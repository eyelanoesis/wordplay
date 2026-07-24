// The codex's living state: inscriptions, growth, decay, persistence, and the
// evolution loop. Moved verbatim from the legacy codex.html; connections now
// come from the tested engine via the adapter. localStorage key and snapshot
// shape unchanged ('wordplay-codex').
import type { Relation } from "../engine";
import { connections } from "./engineAdapter";
import { S, saveSettings } from "./settings";
import { chime, infection, soundNeighborhood, speak, tone } from "./sound";

export interface CodexWord {
  id: string;
  rel: Relation | null;
  detail: string;
  parent: string | null;
  x: number;
  y: number;
  dx: number;
  dy: number;
  gen: number;
  born: number;
  expanded: boolean;
  viral: boolean;
  cx: number | null;
  cy: number | null;
  cr: number;
  expandedAt: number | null;
  dying: number | null;
}

export interface CodexModel {
  words: CodexWord[];
  index: Map<string, number>;
  camX: number;
  camY: number;
  camTarget: [number, number] | null;
  zoom: number;
  current: string | null;
  hovered: string | null;
  lastSpread: number;
  lastInteraction: number;
  busy: boolean;
  readonly MAX: number;
}

export const M: CodexModel = {
  words: [],
  index: new Map(),
  camX: 0,
  camY: 0,
  camTarget: null,
  zoom: 1,
  current: null,
  hovered: null,
  lastSpread: 0,
  lastInteraction: 0,
  busy: false,
  MAX: 110,
};

interface LogLine {
  text: string;
  viral?: boolean;
}
const logLines: LogLine[] = [];

function stamp(): string {
  return new Date().toTimeString().slice(0, 8);
}

export function record(line: string, viral?: boolean): void {
  logLines.push({ text: `[${stamp()}] ${line}`, viral });
  if (logLines.length > 200) logLines.shift();
  const el = document.getElementById("loglines")!;
  el.innerHTML = logLines
    .map(
      (l) =>
        `<div class="${l.viral ? "v" : ""}">${l.text.replace(/&/g, "&amp;").replace(/</g, "&lt;")}</div>`,
    )
    .join("");
  el.parentElement!.scrollTop = el.parentElement!.scrollHeight;
}

export function setStatus(s: string): void {
  document.getElementById("status")!.textContent = s;
}

export function updateCount(): void {
  document.getElementById("count")!.textContent = M.words.length
    ? `${M.words.length} inscriptions`
    : "";
}

export function clearAll(): void {
  M.words = [];
  M.index = new Map();
  M.current = null;
  M.hovered = null;
  M.camX = 0;
  M.camY = 0;
  M.camTarget = null;
  logLines.length = 0;
  document.getElementById("loglines")!.textContent = "the page is blank, and waiting.";
  updateCount();
  saveSoon();
}

export function seedWord(w: string): void {
  clearAll();
  M.words.push({
    id: w, rel: null, detail: "the first inscription", parent: null,
    x: 0, y: 0, dx: 0, dy: -1, gen: 0, born: Date.now(),
    expanded: false, viral: false, cx: null, cy: null, cr: 0,
    expandedAt: null, dying: null,
  });
  M.index.set(w, 0);
  M.current = w;
  record(`${w}: set at the center of the first circle.`);
  chime(null);
  updateCount();
}

export interface Found {
  word: string;
  rel: Relation;
  detail: string;
}

export function inscribe(host: string, found: Found[], viral: boolean): number {
  const i = M.index.get(host);
  if (i === undefined) return 0;
  const h = M.words[i]!;
  const r = Math.max(68, 118 * Math.pow(0.92, h.gen));
  const cx = h.gen === 0 ? h.x : h.x + h.dx * r * 0.9;
  const cy = h.gen === 0 ? h.y : h.y + h.dy * r * 0.9;
  const fresh = found.filter((c) => !M.index.has(c.word));
  const outA = h.gen === 0 ? -Math.PI / 2 : Math.atan2(h.dy, h.dx);
  const spread = h.gen === 0 ? 2 * Math.PI : 4.4;
  let placed = 0;
  fresh.forEach((c, k) => {
    if (M.words.length >= M.MAX) return;
    const n = fresh.length;
    const a =
      h.gen === 0
        ? outA + (spread * k) / n
        : outA - spread / 2 + spread * (n === 1 ? 0.5 : k / (n - 1));
    M.index.set(c.word, M.words.length);
    M.words.push({
      id: c.word, rel: c.rel, detail: c.detail, parent: host,
      x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r,
      dx: Math.cos(a), dy: Math.sin(a), gen: h.gen + 1,
      born: Date.now(), expanded: false, viral,
      cx: null, cy: null, cr: 0, expandedAt: null, dying: null,
    });
    placed++;
  });
  h.expanded = true;
  h.cx = cx;
  h.cy = cy;
  h.cr = r;
  if (!h.expandedAt) h.expandedAt = Date.now();
  M.current = host;
  updateCount();
  saveSoon();
  return placed;
}

export function expand(host: string, auto: boolean): void {
  if (M.busy) return;
  if (!S.relationsOn.size) {
    setStatus(
      "all dimensions are set aside — switch some on in the ☰ dims menu or touch the legend below",
    );
    return;
  }
  M.busy = true;
  const count = auto ? Math.max(1, S.perRelation - 2) : S.perRelation;
  setTimeout(() => {
    // let the UI breathe; searches take ~10ms anyway
    const found: Found[] = connections(host, count, S.relationsOn).map((n) => ({
      word: n.word,
      rel: n.relation,
      detail: n.detail,
    }));
    const placed = inscribe(host, found, auto);
    if (auto && placed > 0) {
      const h = M.words[M.index.get(host)!]!;
      M.camTarget = [-h.cx!, -h.cy!];
    }
    if (placed > 0) {
      if (!auto) speak(host);
      record(
        auto ? `✦ the codex inscribed ${host} · +${placed}` : `${host}: ${placed} inscriptions`,
        auto,
      );
      // Manual open: sound the whole neighbourhood as a chord so you hear how
      // consonant this word's connections are. Auto-growth stays a quiet pulse.
      if (auto) infection();
      else soundNeighborhood(host, found.map((c) => c.word));
    } else {
      record(`${host}: nothing new under this sun`);
    }
    M.busy = false;
  }, 10);
}

function beginDecay(): string | null {
  const c = M.words.filter((w) => !w.expanded && !w.dying && w.gen > 0 && w.id !== M.current);
  if (!c.length) return null;
  const victim = c.reduce((a, b) => (a.born < b.born ? a : b));
  victim.dying = Date.now();
  return victim.id;
}

function reap(): void {
  const before = M.words.length;
  M.words = M.words.filter((w) => !(w.dying && Date.now() - w.dying > 1800));
  if (M.words.length !== before) {
    M.index = new Map(M.words.map((w, i) => [w.id, i]));
    updateCount();
    saveSoon();
  }
}

/** The evolution loop: the codex writes itself onward, forgets to continue. */
export function startEvolutionLoop(): void {
  setInterval(() => {
    reap();
    if (S.autoSpread && M.words.length > 88) {
      const victim = beginDecay();
      if (victim) {
        record(`∴ ${victim} fades from the page`);
        tone(130.8, 0.05);
      }
    }
    if (!S.autoSpread || M.busy || M.words.length >= M.MAX || !M.words.length || !S.relationsOn.size) {
      return;
    }
    if (Date.now() - M.lastSpread < S.cadenceSeconds * 1000) return;
    const unopened = M.words.filter((w) => !w.expanded && !w.dying);
    const opened = M.words.filter((w) => w.expanded);
    let host: CodexWord | null = null;
    if (opened.length && Math.random() < 0.25) {
      host = opened[Math.floor(Math.random() * opened.length)]!;
    } else if (unopened.length) {
      host = unopened[Math.floor(Math.random() * unopened.length)]!;
    } else if (opened.length) {
      host = opened[Math.floor(Math.random() * opened.length)]!;
    }
    if (!host) return;
    M.lastSpread = Date.now();
    expand(host.id, true);
  }, 1000);
}

// persistence — the codex remembers
let saveGen = 0;

export function saveSoon(): void {
  const g = ++saveGen;
  setTimeout(() => {
    if (g !== saveGen) return;
    try {
      localStorage.setItem(
        "wordplay-codex",
        JSON.stringify({
          words: M.words,
          camX: M.camX,
          camY: M.camY,
          current: M.current,
          log: logLines.slice(-40),
        }),
      );
    } catch {
      // storage unavailable — the codex simply doesn't remember
    }
  }, 2000);
}

export function restore(): number {
  try {
    const snap = JSON.parse(localStorage.getItem("wordplay-codex") ?? "null") as {
      words?: CodexWord[];
      camX?: number;
      camY?: number;
      current?: string | null;
      log?: LogLine[];
    } | null;
    if (!snap?.words?.length) return 0;
    M.words = snap.words.filter((w) => !w.dying);
    M.index = new Map(M.words.map((w, i) => [w.id, i]));
    M.camX = snap.camX ?? 0;
    M.camY = snap.camY ?? 0;
    M.current = snap.current ?? null;
    for (const l of snap.log ?? []) logLines.push(l);
    updateCount();
    return M.words.length;
  } catch {
    return 0;
  }
}

export function toggleAutoSpread(): void {
  S.autoSpread = !S.autoSpread;
  saveSettings();
}
