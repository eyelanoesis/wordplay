// The only module that knows where data comes from.
//   dev / hosted build : fetch from /data/ (Vite's public dir)
//   single-file build  : ?raw imports, inlined into the one HTML artifact
// The MODE check is a build-time constant, so each build carries only its
// own branch.

export interface CodexData {
  lexicon: string;
  wordlists: { scrabble: string; biblical: string; dance: string };
  /** empty strings until the assoc dumps are generated (session 7) */
  assoc: { scrabble: string; biblical: string; dance: string };
}

async function fetchText(path: string): Promise<string> {
  const res = await fetch(path);
  if (!res.ok) return "";
  return res.text();
}

export async function loadData(): Promise<CodexData> {
  if (import.meta.env.MODE === "single") {
    const raw = await import("./dataRaw");
    return raw.data;
  }
  const [lexicon, scrabble, biblical, dance, aScrabble, aBiblical, aDance] = await Promise.all([
    fetchText("/data/lexicon.txt"),
    fetchText("/data/enable.txt"),
    fetchText("/data/biblical.txt"),
    fetchText("/data/dance.txt"),
    fetchText("/data/assoc-enable.txt"),
    fetchText("/data/assoc-biblical.txt"),
    fetchText("/data/assoc-dance.txt"),
  ]);
  return {
    lexicon,
    wordlists: { scrabble, biblical, dance },
    assoc: { scrabble: aScrabble, biblical: aBiblical, dance: aDance },
  };
}
