// The HUD: inscribe/divine inputs, dictionary switcher, dims + cadence
// popovers, control buttons, the clickable legend, and the mobile fold.
// Moved verbatim from the legacy codex.html.
import type { Relation } from "../engine";
import { RELS, REL_META } from "./relMeta";
import { S, saveSettings, CADENCES, COMPLEXITIES, type DictName } from "./settings";
import { M, clearAll, seedWord, expand, inscribe, record, setStatus, saveSoon, type Found } from "./model";
import { findPath, DICT_LABELS } from "./engineAdapter";
import { harmonize, speak } from "./sound";

const $ = (id: string): HTMLElement => document.getElementById(id)!;

function pathDetail(rel: Relation, a: string, b: string): string {
  switch (rel) {
    case "anagram": return `${b}: the letters of ${a}, rearranged`;
    case "oneLetter": return `${b}: one letter away from ${a}`;
    case "homophone": return `${b}: pronounced exactly like ${a}`;
    case "rhyme": return `${b}: rhymes with ${a}`;
    case "fusion": return `${b} sound-overlaps ${a}`;
    case "hidden": return `${b} is spelled inside ${a}`;
    case "audible": return `you can hear ${b} inside ${a}`;
    case "reversal": return `${b}: ${a} spelled backwards`;
    case "association": return `${b} keeps company with ${a}`;
  }
}

function go(): void {
  const a = ($("word") as HTMLInputElement).value.trim().toLowerCase();
  const b = ($("toword") as HTMLInputElement).value.trim().toLowerCase();
  if (!a) return;
  if (!b) {
    seedWord(a);
    expand(a, false);
    return;
  }
  setStatus(`divining a way from ${a} to ${b}…`);
  setTimeout(() => {
    const steps = findPath(a, b);
    if (!steps || steps.length < 2) {
      setStatus(steps ? "one and the same word" : "the way is hidden — no path within reach");
      return;
    }
    seedWord(steps[0]!.word);
    record(`the way ${a} ⇢ ${b}: begun.`);
    let prev = steps[0]!.word;
    let i = 1;
    const lay = (): void => {
      if (i >= steps.length) {
        record(`the way is complete: ${steps.length - 1} turns of the compass.`);
        setStatus("the way is drawn — touch any word to open its circle");
        return;
      }
      const st = steps[i]!;
      const rel = st.relation ?? "rhyme";
      const found: Found[] = [{ word: st.word, rel, detail: pathDetail(rel, prev, st.word) }];
      inscribe(prev, found, false);
      record(`${prev} → ${st.word} ${REL_META[rel].glyph}`);
      harmonize(st.relation, prev, st.word); // hear each hop's consonance
      speak(st.word);
      prev = st.word;
      i++;
      setTimeout(lay, 500);
    };
    lay();
  }, 30);
}

// --- popovers: dims (relation filter + complexity + glyphs) and cadence ---
function bindPopover(btnId: string, panelId: string): void {
  const btn = $(btnId),
    panel = $(panelId);
  btn.addEventListener("click", (e) => {
    e.stopPropagation();
    const willOpen = panel.classList.contains("hidden");
    document.querySelectorAll(".popover").forEach((p) => p.classList.add("hidden"));
    if (willOpen) panel.classList.remove("hidden");
  });
  panel.addEventListener("click", (e) => e.stopPropagation());
}

function toggleRelation(rel: Relation, forceState?: boolean): void {
  const on = forceState === undefined ? !S.relationsOn.has(rel) : forceState;
  if (on) S.relationsOn.add(rel);
  else S.relationsOn.delete(rel);
  saveSettings();
  renderLegend();
  renderDimsPanel();
}

function setAllRelations(on: boolean): void {
  S.relationsOn = new Set(on ? RELS : []);
  saveSettings();
  renderLegend();
  renderDimsPanel();
}

const escAttr = (s: string): string => s.replace(/"/g, "&quot;");

function renderDimsPanel(): void {
  const panel = $("dimsPanel");
  panel.innerHTML =
    RELS.map((k) => {
      const m = REL_META[k],
        on = S.relationsOn.has(k);
      return `<label title="${escAttr(m.explanation)}"><input type="checkbox" data-rel="${k}" ${on ? "checked" : ""}> ${S.glyphsOn ? m.glyph + " " : ""}${m.name}</label>`;
    }).join("") +
    `<div class="row"><button type="button" class="mini" id="allOn">All on</button><button type="button" class="mini" id="allOff">All off</button></div>` +
    `<hr><div class="label">complexity</div>` +
    COMPLEXITIES.map(
      ([v, label]) =>
        `<label><input type="radio" name="complexity" value="${v}" ${S.perRelation === v ? "checked" : ""}> ${label}</label>`,
    ).join("") +
    `<hr><label><input type="checkbox" id="glyphsToggle" ${S.glyphsOn ? "checked" : ""}> planetary glyphs (☉ ☽ ☿ ♀ ♂ ♃ ♄ ♅ ♆)</label>`;
  panel.querySelectorAll<HTMLInputElement>("input[type=checkbox][data-rel]").forEach((cb) =>
    cb.addEventListener("change", () => toggleRelation(cb.dataset.rel as Relation, cb.checked)),
  );
  $("allOn").addEventListener("click", () => setAllRelations(true));
  $("allOff").addEventListener("click", () => setAllRelations(false));
  panel.querySelectorAll<HTMLInputElement>("input[name=complexity]").forEach((r) =>
    r.addEventListener("change", () => {
      S.perRelation = Number(r.value);
      saveSettings();
    }),
  );
  $("glyphsToggle").addEventListener("change", (e) => {
    S.glyphsOn = (e.target as HTMLInputElement).checked;
    saveSettings();
    renderLegend();
    renderDimsPanel();
  });
}

function renderCadencePanel(): void {
  $("cadencePanel").innerHTML =
    '<div class="label">cadence</div>' +
    CADENCES.map(
      (s) =>
        `<label><input type="radio" name="cadence" value="${s}" ${S.cadenceSeconds === s ? "checked" : ""}> every ${s === 1 ? "second" : s + " seconds"}</label>`,
    ).join("");
  document.querySelectorAll<HTMLInputElement>("input[name=cadence]").forEach((r) =>
    r.addEventListener("change", () => {
      S.cadenceSeconds = Number(r.value);
      saveSettings();
    }),
  );
}

// legend — each dimension is a clickable toggle, struck through when off
function renderLegend(): void {
  const parts = RELS.map((k) => {
    const m = REL_META[k],
      on = S.relationsOn.has(k);
    const mark = S.glyphsOn
      ? `<span class="lmark" style="color:${m.color};opacity:${on ? 0.9 : 0.3}">${m.glyph}</span>`
      : `<span class="lmark ldot" style="background:${m.color};opacity:${on ? 0.7 : 0.2}"></span>`;
    return `<button type="button" class="legendItem" data-rel="${k}" title="${m.name}: ${escAttr(m.explanation)}"><span style="opacity:${on ? 1 : 0.55}">${mark} <span style="text-decoration:${on ? "none" : "line-through"}">${m.name}</span></span></button>`;
  }).join("");
  $("legend").innerHTML =
    parts +
    "<span class=\"hint\">green ink = unopened doors · ochre = the codex's own hand · drag wanders · scroll zooms</span>";
  document.querySelectorAll<HTMLElement>(".legendItem").forEach((btn) =>
    btn.addEventListener("click", () => toggleRelation(btn.dataset.rel as Relation)),
  );
}

function renderDictSelect(): void {
  const sel = $("dict") as HTMLSelectElement;
  sel.innerHTML = (Object.keys(DICT_LABELS) as DictName[])
    .map((k) => `<option value="${k}">${DICT_LABELS[k]}</option>`)
    .join("");
  sel.value = S.dict;
  sel.addEventListener("change", () => {
    S.dict = sel.value as DictName;
    record(`the dictionary changes: ${DICT_LABELS[S.dict]}`);
    saveSettings();
  });
}

export function initHud(): void {
  $("go").addEventListener("click", go);
  $("word").addEventListener("keydown", (e) => {
    if ((e as KeyboardEvent).key === "Enter") go();
  });
  $("toword").addEventListener("keydown", (e) => {
    if ((e as KeyboardEvent).key === "Enter") go();
  });
  $("clear").addEventListener("click", clearAll);

  const spread = $("spread");
  spread.classList.toggle("on", S.autoSpread);
  spread.addEventListener("click", () => {
    S.autoSpread = !S.autoSpread;
    spread.classList.toggle("on", S.autoSpread);
    saveSettings();
  });

  const chimes = $("chimes");
  chimes.classList.toggle("on", S.chimesOn);
  chimes.addEventListener("click", () => {
    S.chimesOn = !S.chimesOn;
    chimes.classList.toggle("on", S.chimesOn);
    saveSettings();
  });

  const voice = $("voice");
  voice.classList.toggle("on", S.voiceOn);
  voice.addEventListener("click", () => {
    S.voiceOn = !S.voiceOn;
    voice.classList.toggle("on", S.voiceOn);
    if (S.voiceOn && M.current) speak(M.current);
    saveSettings();
  });

  $("save").addEventListener("click", () => {
    const a = document.createElement("a");
    a.download = `codex-${M.current ?? "page"}.png`;
    a.href = (document.getElementById("page") as HTMLCanvasElement).toDataURL("image/png");
    a.click();
  });

  // On phones the log is a bottom sheet; start hidden, toggle with ☰ log.
  const codexlog = $("codexlog");
  const onPhone = matchMedia("(max-width: 720px)").matches;
  if (onPhone) codexlog.classList.add("hidden");
  $("logtoggle").addEventListener("click", () => {
    codexlog.classList.toggle("hidden");
  });

  // Folded controls on phones: start folded so the codex owns the screen.
  // The + seal unfurls the HUD; it rotates into an × to close; tapping the
  // canvas also folds it back so the page stays unobstructed.
  if (onPhone) document.body.classList.add("folded");
  $("fold").addEventListener("click", () => {
    document.body.classList.toggle("folded");
  });
  $("page").addEventListener(
    "pointerdown",
    () => {
      if (onPhone && !document.body.classList.contains("folded")) {
        document.body.classList.add("folded");
      }
      document.querySelectorAll(".popover").forEach((p) => p.classList.add("hidden"));
    },
    true, // capture phase: fold before the canvas handles the gesture
  );

  document.addEventListener("click", () =>
    document.querySelectorAll(".popover").forEach((p) => p.classList.add("hidden")),
  );

  renderDictSelect();
  renderDimsPanel();
  renderCadencePanel();
  renderLegend();
  bindPopover("dimsBtn", "dimsPanel");
  bindPopover("cadenceBtn", "cadencePanel");
}

// saveSoon re-export keeps model the single writer of the codex snapshot.
export { saveSoon };
