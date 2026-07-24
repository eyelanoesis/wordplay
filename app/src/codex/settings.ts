// Persisted per-session choices — dimensions, complexity, cadence, glyphs,
// sound, voice, dictionary, self-writing. localStorage key and JSON shape are
// kept byte-compatible with the legacy codex.html.
import { type Relation } from "../engine";
import { RELS } from "./relMeta";

export const CADENCES = [1, 2, 3, 5, 10, 30] as const;
export const COMPLEXITIES: ReadonlyArray<readonly [number, string]> = [
  [1, "sparse — one per dimension"],
  [2, "modest — two"],
  [4, "rich — four"],
  [6, "lush — six"],
];

export type DictName = "scrabble" | "biblical" | "dance";

export interface Settings {
  /** empty = all off, matching the app's default */
  relationsOn: Set<Relation>;
  /** complexity: sparse=1, modest=2, rich=4, lush=6 */
  perRelation: number;
  glyphsOn: boolean;
  cadenceSeconds: number;
  chimesOn: boolean;
  voiceOn: boolean;
  dict: DictName;
  autoSpread: boolean;
}

export const S: Settings = {
  relationsOn: new Set(),
  perRelation: 1,
  glyphsOn: false,
  cadenceSeconds: 3,
  chimesOn: false,
  voiceOn: false,
  dict: "scrabble",
  autoSpread: false,
};

const SETTINGS_KEY = "wordplay-codex-settings";

export function saveSettings(): void {
  try {
    localStorage.setItem(
      SETTINGS_KEY,
      JSON.stringify({
        relations: [...S.relationsOn],
        perRelation: S.perRelation,
        glyphsOn: S.glyphsOn,
        cadenceSeconds: S.cadenceSeconds,
        chimesOn: S.chimesOn,
        voiceOn: S.voiceOn,
        dict: S.dict,
        autoSpread: S.autoSpread,
      }),
    );
  } catch {
    // storage unavailable (private mode etc.) — settings just don't persist
  }
}

export function loadSettings(): void {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) return;
    const s = JSON.parse(raw) as Partial<{
      relations: string[];
      perRelation: number;
      glyphsOn: boolean;
      cadenceSeconds: number;
      chimesOn: boolean;
      voiceOn: boolean;
      dict: string;
      autoSpread: boolean;
    }>;
    S.relationsOn = new Set(
      (s.relations ?? []).filter((r): r is Relation => (RELS as readonly string[]).includes(r)),
    );
    S.perRelation = COMPLEXITIES.some(([v]) => v === s.perRelation) ? s.perRelation! : 1;
    S.glyphsOn = !!s.glyphsOn;
    S.cadenceSeconds = (CADENCES as readonly number[]).includes(s.cadenceSeconds ?? -1)
      ? s.cadenceSeconds!
      : 3;
    S.chimesOn = !!s.chimesOn;
    S.voiceOn = !!s.voiceOn;
    if (s.dict === "scrabble" || s.dict === "biblical" || s.dict === "dance") S.dict = s.dict;
    S.autoSpread = !!s.autoSpread;
  } catch {
    // corrupt state — fall back to defaults
  }
}
