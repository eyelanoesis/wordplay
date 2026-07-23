// Placeholder boot: proves the dev loop (Vite serves, data loads, engine runs).
// Replaced by the codex app in a later session.
import { WordList } from "./engine/wordList";

const status = document.getElementById("status")!;

async function boot(): Promise<void> {
  const text = await (await fetch("/data/enable.txt")).text();
  const list = WordList.fromText(text);
  status.textContent = `${list.count.toLocaleString()} words loaded — the engines are coming.`;
}

boot().catch((e) => {
  status.textContent = `failed to load: ${e}`;
});
