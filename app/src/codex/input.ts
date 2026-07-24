// Pointer interaction: drag pans, pinch and wheel zoom, tap opens circles
// (two-tap on touch), hover shows the honest tooltip. Moved verbatim from the
// legacy codex.html.
import { M, expand, type CodexWord } from "./model";
import { W, H } from "./render";
import { REL_META } from "./relMeta";
import { S } from "./settings";
import { consonance, intervalFor, IV_NAME } from "./sound";
import { pronOf } from "./engineAdapter";

const tip = (): HTMLElement => document.getElementById("tip")!;
const pointers = new Map<number, { x: number; y: number }>(); // active pointers, for pinch detection
let dragging = false,
  moved = 0,
  lastX = 0,
  lastY = 0;
let pinchDist = 0; // last two-finger distance
let armed: string | null = null; // touch: word shown by a first tap
const isTouch = (): boolean => matchMedia("(pointer: coarse)").matches;

function wordAt(clientX: number, clientY: number): CodexWord | null {
  const wx = (clientX - W / 2 - M.camX) / M.zoom;
  const wy = (clientY - H / 2 - M.camY) / M.zoom;
  let best: CodexWord | null = null;
  let bd = (isTouch() ? 44 : 34) / M.zoom; // fatter for fingertips
  for (const w of M.words) {
    const d = Math.hypot(w.x - wx, w.y - wy);
    if (d < bd) {
      bd = d;
      best = w;
    }
  }
  return best;
}

function showTip(word: CodexWord | null, clientX: number, clientY: number): void {
  const el = tip();
  if (!word || !word.detail) {
    el.style.display = "none";
    return;
  }
  const meta = word.rel ? REL_META[word.rel] : null;
  let caption = word.detail;
  if (meta) {
    const mark = S.glyphsOn ? `${meta.glyph} ` : "";
    caption = `${mark}${meta.name} — ${meta.explanation}\n${caption}`;
  }
  if (word.parent) {
    caption += M.index.has(word.parent)
      ? `\njoined through ${word.parent}`
      : `\njoined through ${word.parent}, whose ink has since faded`;
  }
  const ph = pronOf(word.id);
  if (ph) caption += "\n/" + ph.join(" ") + "/";
  // If this word hangs off a parent, name how consonant the pair sounds.
  if (word.rel && M.current && M.current !== word.id) {
    const c = consonance(M.current, word.id);
    const iv = intervalFor(c);
    const feel = c >= 0.66 ? "consonant" : c >= 0.4 ? "tense" : "dissonant";
    caption += `\n♪ ${IV_NAME[iv]} · ${feel} (${c.toFixed(2)})`;
  }
  caption += word.viral
    ? "\ninscribed by the codex itself · click to open its circle"
    : "\nclick to open its circle";
  el.textContent = caption;
  el.style.display = "block";
  const tw = el.offsetWidth || 240;
  el.style.left = `${Math.max(8, Math.min(clientX + 14, W - tw - 8))}px`;
  el.style.top = `${Math.max(8, clientY - 40)}px`;
}

/** Zoom the world about a screen point by scaling the camera offset. */
function zoomAbout(cx: number, cy: number, factor: number): void {
  factor = Math.max(0.5, Math.min(2, factor));
  const before = { x: cx - W / 2 - M.camX, y: cy - H / 2 - M.camY };
  M.zoom = Math.max(0.35, Math.min(2.5, (M.zoom || 1) * factor));
  // keep the pinch midpoint anchored: adjust camera so 'before' stays put
  M.camX = cx - W / 2 - before.x * factor;
  M.camY = cy - H / 2 - before.y * factor;
}

export function bindInput(): void {
  const canvas = document.getElementById("page")!;

  canvas.addEventListener("pointerdown", (e) => {
    canvas.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 2) {
      // begin pinch
      const [a, b] = [...pointers.values()] as [{ x: number; y: number }, { x: number; y: number }];
      pinchDist = Math.hypot(a.x - b.x, a.y - b.y);
      dragging = false;
      return;
    }
    dragging = true;
    moved = 0;
    lastX = e.clientX;
    lastY = e.clientY;
  });

  canvas.addEventListener("pointermove", (e) => {
    if (!pointers.has(e.pointerId)) {
      // hover (mouse only)
      if (e.pointerType === "mouse") {
        const w = wordAt(e.clientX, e.clientY);
        M.hovered = w ? w.id : null;
        showTip(w, e.clientX, e.clientY);
      }
      return;
    }
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

    if (pointers.size === 2) {
      // pinch-zoom about the midpoint
      const [a, b] = [...pointers.values()] as [{ x: number; y: number }, { x: number; y: number }];
      const dist = Math.hypot(a.x - b.x, a.y - b.y);
      if (pinchDist > 0) {
        const factor = dist / pinchDist;
        zoomAbout((a.x + b.x) / 2, (a.y + b.y) / 2, factor);
      }
      pinchDist = dist;
      M.lastInteraction = Date.now();
      M.camTarget = null;
      return;
    }

    if (!dragging) return;
    const dx = e.clientX - lastX,
      dy = e.clientY - lastY;
    moved += Math.abs(dx) + Math.abs(dy);
    if (moved > 6) {
      M.camX += dx;
      M.camY += dy;
      M.lastInteraction = Date.now();
      M.camTarget = null;
      canvas.classList.add("panning");
      tip().style.display = "none";
    }
    lastX = e.clientX;
    lastY = e.clientY;
  });

  function endPointer(e: PointerEvent): void {
    const had = pointers.has(e.pointerId);
    pointers.delete(e.pointerId);
    if (pointers.size < 2) pinchDist = 0;
    if (!had) return;
    canvas.classList.remove("panning");
    const wasDrag = dragging;
    dragging = false;
    if (!wasDrag || moved > 6) {
      M.lastInteraction = Date.now();
      return;
    }

    // A clean tap/click.
    const w = wordAt(e.clientX, e.clientY);
    if (e.pointerType === "mouse") {
      if (w) expand(w.id, false);
      return;
    }
    // Touch: first tap reveals + arms; tapping the armed word opens it;
    // tapping elsewhere dismisses.
    if (w && armed === w.id) {
      tip().style.display = "none";
      armed = null;
      expand(w.id, false);
    } else if (w) {
      armed = w.id;
      M.hovered = w.id;
      showTip(w, e.clientX, e.clientY);
    } else {
      armed = null;
      M.hovered = null;
      tip().style.display = "none";
    }
  }
  canvas.addEventListener("pointerup", endPointer);
  canvas.addEventListener("pointercancel", endPointer);

  // Desktop: wheel / trackpad pinch also zooms.
  canvas.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      const factor = e.deltaY < 0 ? 1.08 : 0.926;
      zoomAbout(e.clientX, e.clientY, factor);
      M.lastInteraction = Date.now();
      M.camTarget = null;
    },
    { passive: false },
  );
}
