// Copy the canonical data files from the frozen Swift app's resources into
// public/data/. The Swift side is the one canonical home of these files; this
// script exists so the copy is always mechanical, never manual.
import { copyFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const src = join(here, "..", "..", "Sources", "Anagrammer", "Resources");
const dst = join(here, "..", "public", "data");

mkdirSync(dst, { recursive: true });
for (const file of ["enable.txt", "biblical.txt", "dance.txt", "cmudict.dict"]) {
  copyFileSync(join(src, file), join(dst, file));
  console.log(`synced ${file}`);
}
