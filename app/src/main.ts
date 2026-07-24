// Boot the codex: load data, build the engines, wake the page.
import "./codex/styles.css";
import { loadData } from "./codex/dataSource";
import { initEngines } from "./codex/engineAdapter";
import { loadSettings } from "./codex/settings";
import { initHud } from "./codex/hud";
import { bindInput } from "./codex/input";
import { startRendering } from "./codex/render";
import { M, record, restore, startEvolutionLoop, updateCount } from "./codex/model";

async function boot(): Promise<void> {
  const data = await loadData();
  initEngines(data);
  loadSettings();
  initHud();
  bindInput();
  const restored = restore();
  if (restored > 0) record(`the codex remembers: ${restored} inscriptions restored.`);
  updateCount();
  startRendering();
  startEvolutionLoop();
  document.getElementById("boot")!.classList.add("gone");
  void M; // model is alive; the page draws from it every frame
}

boot().catch((e: unknown) => {
  const boot = document.getElementById("boot")!;
  boot.textContent = `the codex could not be bound: ${String(e)}`;
});
