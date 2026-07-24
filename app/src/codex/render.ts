// Canvas rendering: aged parchment, wobbling sepia circles, curved rim
// script, planetary glyphs, frontier ink. Moved verbatim from the legacy
// codex.html.
import { M } from "./model";
import { REL_META } from "./relMeta";
import { S } from "./settings";

const canvas = (): HTMLCanvasElement => document.getElementById("page") as HTMLCanvasElement;
let ctx: CanvasRenderingContext2D;
export let W = 0,
  H = 0;
let DPR = 1;

function resize(): void {
  const c = canvas();
  DPR = window.devicePixelRatio || 1;
  W = window.innerWidth;
  H = window.innerHeight;
  c.width = W * DPR;
  c.height = H * DPR;
  c.style.width = `${W}px`;
  c.style.height = `${H}px`;
}

// Navigation ink: ochre = self-written, verdigris = unopened frontier
// (touch to open), sepia = already opened.
const FRONTIER = [33, 107, 97] as const;
const OCHRE = [158, 46, 26] as const;
const SEPIA = [82, 56, 31] as const;

function drift(x: number, y: number, seed: number, t: number): [number, number] {
  const s = seed & 1023;
  return [x + Math.sin(t * 0.11 + s) * 3.2, y + Math.cos(t * 0.087 + s * 1.7) * 3.2];
}

export function hash(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

const sx = (x: number): number => W / 2 + M.camX + x * M.zoom;
const sy = (y: number): number => H / 2 + M.camY + y * M.zoom;

function wobbleCircle(cx: number, cy: number, r: number, seed: number): void {
  ctx.beginPath();
  let h = seed >>> 0;
  for (let k = 0; k <= 48; k++) {
    const a = (k / 48) * 2 * Math.PI;
    h = (Math.imul(h, 1664525) + 1013904223) >>> 0;
    const wob = (((h >>> 20) & 1023) / 1023 - 0.5) * 3;
    const rr = r + wob;
    const x = cx + Math.cos(a) * rr,
      y = cy + Math.sin(a) * rr;
    if (k === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.closePath();
}

function draw(nowMs: number): void {
  const t = nowMs / 1000;
  ctx.setTransform(DPR, 0, 0, DPR, 0, 0);

  // camera glide toward fresh ink
  if (M.camTarget && Date.now() - M.lastInteraction > 8000) {
    M.camX += (M.camTarget[0] - M.camX) * 0.03;
    M.camY += (M.camTarget[1] - M.camY) * 0.03;
    if (Math.hypot(M.camTarget[0] - M.camX, M.camTarget[1] - M.camY) < 5) M.camTarget = null;
  }

  // parchment
  const g = ctx.createRadialGradient(W / 2, H * 0.45, 0, W / 2, H * 0.45, Math.max(W, H) * 0.8);
  g.addColorStop(0, "#eee3ca");
  g.addColorStop(1, "#d9c8a1");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, W, H);
  let h = 0x0de1ca7e;
  for (let i = 0; i < 14; i++) {
    h = (Math.imul(h, 1664525) + 1013904223) >>> 0;
    const x = (((h >>> 12) & 1023) / 1023) * W;
    h = (Math.imul(h, 1664525) + 1013904223) >>> 0;
    const y = (((h >>> 12) & 1023) / 1023) * H;
    h = (Math.imul(h, 1664525) + 1013904223) >>> 0;
    const r = 26 + ((h >>> 12) & 89);
    ctx.fillStyle = "rgba(140,107,56,0.028)";
    ctx.beginPath();
    ctx.arc(x, y, r, 0, 7);
    ctx.fill();
  }
  // vitruvian construct at the origin
  ctx.strokeStyle = "rgba(82,56,31,0.07)";
  ctx.lineWidth = 1;
  const ox = sx(0),
    oy = sy(0),
    R = 275,
    Sq = R * 0.885;
  ctx.beginPath();
  ctx.arc(ox, oy, R, 0, 7);
  ctx.stroke();
  ctx.strokeRect(ox - Sq, oy - Sq, Sq * 2, Sq * 2);

  if (!M.words.length) {
    ctx.fillStyle = "rgba(82,56,31,0.45)";
    ctx.font = "italic 20px Georgia";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("speak a word, and the codex will study it", W / 2, H / 2);
    requestAnimationFrame(draw);
    return;
  }

  // circles + spokes + mirror notes
  for (const w of M.words) {
    if (!w.expanded || w.cx === null) continue;
    const seed = hash(w.id);
    const [dcx, dcy] = drift(w.cx, w.cy!, seed, t);
    const cx = sx(dcx),
      cy = sy(dcy),
      r = w.cr;
    if (cx < -r || cx > W + r || cy < -r || cy > H + r) continue;
    const age = w.expandedAt ? (Date.now() - w.expandedAt) / 1000 : 0;
    const aged = 1 - 0.5 * Math.min(age / 150, 1);
    ctx.strokeStyle = `rgba(82,56,31,${0.42 * aged + 0.08})`;
    ctx.lineWidth = 1.1;
    wobbleCircle(cx, cy, r, seed);
    ctx.stroke();
    ctx.strokeStyle = `rgba(82,56,31,${0.2 * aged + 0.04})`;
    ctx.lineWidth = 0.8;
    wobbleCircle(cx, cy, r - 5, seed + 1);
    ctx.stroke();
    if (w.id === M.current) {
      ctx.save();
      ctx.strokeStyle = "rgba(98,24,16,0.5)";
      ctx.lineWidth = 0.9;
      ctx.setLineDash([3, 7]);
      ctx.lineDashOffset = -t * 14;
      ctx.beginPath();
      ctx.arc(cx, cy, r + 9, 0, 7);
      ctx.stroke();
      ctx.restore();
    }
    for (const m of M.words) {
      if (m.gen !== w.gen + 1) continue;
      if (Math.abs(Math.hypot(m.x - w.cx, m.y - w.cy!) - r) > 2) continue;
      const [mx, my] = drift(m.x, m.y, hash(m.id), t);
      ctx.strokeStyle = `rgba(82,56,31,${0.14 * aged + 0.03})`;
      ctx.lineWidth = 0.7;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(sx(mx), sy(my));
      ctx.stroke();
    }
    if (w.detail && w.gen > 0) {
      ctx.save();
      ctx.translate(cx, cy + r + 14);
      ctx.scale(-1, 1);
      ctx.rotate(-0.05);
      ctx.fillStyle = "rgba(82,56,31,0.26)";
      ctx.font = "italic 9px Georgia";
      ctx.textAlign = "center";
      ctx.fillText(w.detail, 0, 0);
      ctx.restore();
    }
  }

  // words
  for (const w of M.words) {
    const seed = hash(w.id);
    const [dx0, dy0] = drift(w.x, w.y, seed, t);
    const x = sx(dx0),
      y = sy(dy0);
    if (x < -80 || x > W + 80 || y < -40 || y > H + 40) continue;
    const grown = 1 - Math.pow(1 - Math.min((Date.now() - w.born) / 500, 1), 3);
    const aged = 1 - 0.4 * Math.min((Date.now() - w.born) / 150000, 1);
    const isCur = w.id === M.current,
      isHov = w.id === M.hovered;
    let alpha = grown * aged * (isCur || isHov ? 1 : 0.82);
    if (w.dying) alpha *= Math.max(0, 1 - (Date.now() - w.dying) / 1800);
    if (alpha <= 0.01) continue;

    if (w.gen === 0) {
      ctx.fillStyle = `rgba(82,56,31,${alpha})`;
      ctx.font = "600 26px Georgia";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(w.id.toUpperCase(), x, y);
      continue;
    }
    const angle = Math.atan2(w.dy, w.dx);
    const flip = Math.cos(angle) < 0;
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle + (flip ? Math.PI : 0));
    const rgb = w.viral ? OCHRE : !w.expanded && !w.dying ? FRONTIER : SEPIA;
    ctx.fillStyle = `rgba(${rgb[0]},${rgb[1]},${rgb[2]},${alpha})`;
    ctx.font = (isCur ? "600 italic 15px" : "italic 13px") + " Georgia";
    ctx.textAlign = flip ? "right" : "left";
    ctx.textBaseline = "middle";
    ctx.fillText(w.id, flip ? -26 : 26, 0);
    ctx.restore();
    if (w.rel) {
      const meta = REL_META[w.rel];
      const mx = x - w.dx * 12,
        my = y - w.dy * 12;
      if (S.glyphsOn) {
        ctx.fillStyle = meta.color;
        ctx.globalAlpha = 0.9 * alpha;
        ctx.font = "13px Georgia";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(meta.glyph, mx, my);
        ctx.globalAlpha = 1;
      } else {
        ctx.fillStyle = meta.color;
        ctx.globalAlpha = 0.75 * alpha;
        ctx.beginPath();
        ctx.arc(mx, my, 2.5, 0, 7);
        ctx.fill();
        ctx.globalAlpha = 1;
      }
    }
  }
  requestAnimationFrame(draw);
}

export function startRendering(): void {
  ctx = canvas().getContext("2d")!;
  window.addEventListener("resize", resize);
  resize();
  requestAnimationFrame(draw);
}
