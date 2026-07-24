// Single-file build only: the data inlined as strings at build time.
// Loaded via dynamic import from dataSource.ts, so hosted builds never
// bundle these multi-MB strings.
import lexicon from "../../public/data/lexicon.txt?raw";
import scrabble from "../../public/data/enable.txt?raw";
import biblical from "../../public/data/biblical.txt?raw";
import dance from "../../public/data/dance.txt?raw";
import type { CodexData } from "./dataSource";

// Association dumps are optional; once generated (tools/assoc-dump) they are
// added here behind the same size decision the plan defers to Rune.
export const data: CodexData = {
  lexicon,
  wordlists: { scrabble, biblical, dance },
  assoc: { scrabble: "", biblical: "", dance: "" },
};
