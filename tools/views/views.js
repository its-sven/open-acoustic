// Shared model, pedal sync, gestures and top bar for the touch views (tools/views).
// Effects, labels, ranges, value formats, style lists and pictures come from ../pa-menus.js and ../pa-images.js;
// the pedal is reached through ../pa-link.js. With no pedal connected the views run on a demo preset.
(function () {
  const M = window.PA_MENUS, IM = window.PA_IMAGES || {}, L = window.PALink;
  const pageOf = (menu, title) => (M[menu] && M[menu].pages.find(p => p.title === title)) || null;
  const cellsOf = p => (p ? (p.rows || []).flat().filter(Boolean) : []);
  const hex = s => parseInt(s, 16);

  // Effects in signal order (from the firmware's send parameters: LEAD TO UMOD, UMOD TO DELAY, DELAY TO REVERB, GTR TO UMOD …).
  // `demo` values are only used while no pedal is connected.
  const DEF = [
    { id: "hardtune",   side: "vocal",  name: "HardTune",   color: "--c-hardtune",   page: ["VOCAL", "HARDTUNE"],   demo: { state: 0, style: 3 } },
    { id: "transducer", side: "vocal",  name: "Transducer", color: "--c-transducer", page: ["VOCAL", "TRANSDUCER"], adv: [["VOCAL ADV", "TRANSDUCER"]], demo: { state: 2, style: 0, DRIVE: 62, FILTER: 40, "GATE THRESHOLD": -40 } },
    { id: "double",     side: "vocal",  name: "Double",     color: "--c-double",     page: ["VOCAL", "DOUBLE"],     demo: { state: 1, style: 1, LEVEL: -6 } },
    { id: "harmony",    side: "vocal",  name: "Harmony",    color: "--c-harmony",    page: ["VOCAL", "HARMONY"],    adv: [["VOCAL ADV", "HARMONY"]], demo: { state: 1, style: 6, LEVEL: -4, HUMANIZE: 35, PORTAMENTO: 40 } },
    { id: "umod",       side: "vocal",  name: "uMOD",       color: "--c-umod",       page: ["VOCAL", "uMOD"],       demo: { state: 0, style: 4, LEVEL: -12, SPEED: 180 } },
    { id: "delay",      side: "vocal",  name: "Delay",      color: "--c-delay",      page: ["VOCAL", "DELAY"],      adv: [["VOCAL ADV", "DELAY"]], demo: { state: 1, style: 1, LEVEL: -14, FEEDBACK: 28, FILTER: 1, TEMPO: 96 } },
    { id: "reverb",     side: "vocal",  name: "Reverb",     color: "--c-reverb",     page: ["VOCAL", "REVERB"],     demo: { state: 1, style: 9, LEVEL: -10, DECAY: 120 } },
    { id: "g-bodyrez",  side: "guitar", name: "BodyRez",    color: "--c-bodyrez",    page: ["GUITAR", "BODYREZ EQ"], adv: [["GUITAR", "BODYREZ SHELF EQ"], ["GUITAR", "BODYREZ PARAMETRIC EQ"]], always: true,
      demo: { style: 5, AMOUNT: 6, "LOW GAIN": -2, "HI GAIN": 3, "LOW FREQ": 60, "HI FREQ": 180, "PARA 1 FREQ": 95, "PARA 2 FREQ": 150, "PARA 1 WIDTH": 16, "PARA 2 WIDTH": 12, "PARA 1 GAIN": -4, "PARA 2 GAIN": 2 } },
    { id: "g-comp",     side: "guitar", name: "Comp",       color: "--c-comp",       page: ["GUITAR", "BODYREZ COMPRESSOR"], always: true, img: 9, demo: { THRESHOLD: -18, RATIO: 8, ATTACK: 6, RELEASE: 10, "MAKEUP GAIN": 4, AMBIENCE: -12 } },
    { id: "g-umod",     side: "guitar", name: "uMOD",       color: "--c-umod",       page: ["GUITAR", "GUITAR uMOD"],   adv: [["GUITAR ADV", "GUITAR uMOD"]], demo: { state: 1, style: 0, "UMOD LEVEL": -10, SPEED: 120, DEPTH: 60 } },
    { id: "g-delay",    side: "guitar", name: "Delay",      color: "--c-delay",      page: ["GUITAR", "GUITAR DELAY"],  adv: [["GUITAR ADV", "GUITAR DELAY"]], demo: { state: 0, style: 2, "DELAY LEVEL": -16, FEEDBACK: 22, TEMPO: 96, FILTER: 1 } },
    { id: "g-reverb",   side: "guitar", name: "Reverb",     color: "--c-reverb",     page: ["GUITAR", "GUITAR REVERB"], adv: [["GUITAR ADV", "GUITAR REVERB"]], demo: { state: 1, style: 0, "REVERB LEVEL": -12, "REVERB DECAY": 130, "REVERB PRE DLY": 20 } },
  ];

  // ── central value store: parameter id → value ───────────────────────────
  const V = new Map(), CELL = new Map();   // CELL: id → cell (range/format), for any parameter a view uses
  const HIT = 0x2A8, PRESET = 0x2A4;
  const clampC = (c, v) => Math.max(c.min, Math.min(c.max, Math.round(v)));

  const FX = DEF.map(d => {
    const p = pageOf(...d.page), cells = cellsOf(p);
    const styleCell = d.img ? null : cells.find(c => c.format === "list" && c.values && c.values.length > 3) || null;
    const seen = new Set(cells.map(c => c.param));
    const adv = (d.adv || []).flatMap(a => cellsOf(pageOf(...a))).filter(c => !seen.has(c.param) && seen.add(c.param));
    const fx = { ...d, pageObj: p, control: p && p.control, styleCell, images: (p && p.images) || [], params: cells.filter(c => c !== styleCell), adv, vals: {} };
    for (const c of [styleCell, fx.control, ...fx.params, ...fx.adv]) if (c) { c.id = hex(c.param); CELL.set(c.id, c); }
    // fx.vals.LABEL, fx.style and fx.state read and write the central store (writes go to the pedal)
    for (const c of [...fx.params, ...fx.adv]) Object.defineProperty(fx.vals, c.label, { enumerable: true, get: () => V.get(c.id) ?? c.default ?? clampC(c, 0), set: v => setParam(c.id, v) });
    Object.defineProperty(fx, "style", { get: () => (styleCell ? V.get(styleCell.id) ?? 0 : 0), set: v => setStyle(fx.id, v) });
    Object.defineProperty(fx, "state", { get: () => fx.always ? "on" : (["off", "on", "hit"][V.get(fx.control.id)] ?? "off"), set: s => setState(fx.id, s) });
    return fx;
  });
  const byId = Object.fromEntries(FX.map(f => [f.id, f]));
  const owners = new Map();   // param id → [{fx, label}]  (some ids are shared, e.g. the delay TEMPO)
  for (const fx of FX) for (const c of [...fx.params, ...fx.adv]) { if (!owners.has(c.id)) owners.set(c.id, []); owners.get(c.id).push({ fx, label: c.label }); }
  const cellOf = (fx, label) => [...fx.params, ...fx.adv].find(c => c.label === label);
  // Register a parameter that isn't on an FX page (mix levels, sends …) so it is read and written like the rest.
  function addParam(id, cell) { const c = { id, param: "0x" + id.toString(16), format: "number", ...cell }; CELL.set(id, c); return c; }
  addParam(HIT, { label: "HIT", min: 0, max: 1, format: "list", values: ["OFF", "ON"] });

  // ── value formats (same rules as pa-remote.html, incl. the calibration points in pa-menus.js) ──
  const trim = (n, d) => (+(+n).toFixed(d)).toString();
  function lerp(pts, v) { if (!pts || !pts.length) return v; if (v <= pts[0][0]) return pts[0][1];
    for (let i = 1; i < pts.length; i++) if (v <= pts[i][0]) { const [x0, y0] = pts[i - 1], [x1, y1] = pts[i]; return y0 + (y1 - y0) * (v - x0) / (x1 - x0); }
    return pts[pts.length - 1][1]; }
  function fmt(c, v) {
    if (!c) return String(v); if (v == null) return "··";
    if (c.values) return c.values[v - c.min] ?? String(v);
    const o = c.fmt || {};
    switch (c.format) {
      case "dB": return (v > 0 ? "+" : v < 0 ? "−" : "") + Math.abs(v) + " dB";
      case "%": return v + "%";
      case "Hz/2": return (v / 2).toFixed(1) + " Hz";
      case "OFF/%": return v ? v + "%" : "OFF";
      case "BPM": return v + " BPM";
      case "ms": return v + " ms";
      case "scale": return trim(v * (o.mul ?? .01), o.dec ?? 2) + " " + (o.unit ?? "Hz");
      case "time": { const s = o.points ? lerp(o.points, v) : v / 10; return s < 1 ? Math.round(s * 1000) + " ms" : trim(s, s < 10 ? 1 : 0) + " s"; }
      case "curve": return trim(lerp(o.points, v), o.dec ?? 0) + (o.unit ? " " + o.unit : "");
      default: return (c.min < 0 && v > 0 ? "+" : "") + String(v).replace("-", "−");
    }
  }
  const seconds = (c, v) => (c && c.fmt && c.fmt.points ? lerp(c.fmt.points, v) : v / 10);   // decay as seconds, for drawings
  const styleName = fx => (fx.styleCell ? fx.styleCell.values[fx.style] ?? "" : fx.name.toUpperCase());
  const img = fx => fx.img ?? fx.images[fx.style] ?? fx.images[0];
  const artHTML = (n, cls = "", extra = "") => `<i class="art ${cls}" style="--m:url('${IM[n] || ""}');${extra}"></i>`;
  const color = fx => `var(${fx.color})`;
  const emit = (type, detail) => document.dispatchEvent(new CustomEvent("pa:" + type, { detail }));

  // ── writes: model first (instant UI), then the pedal (coalesced per parameter) ──
  const touched = new Map(), pending = new Map(); let flushT = null;
  function send(id, v) {
    touched.set(id, performance.now());
    if (!L.ready) return;
    pending.set(id, v); if (!flushT) flushT = setTimeout(flush, 30);
  }
  function flush() { flushT = null; for (const [id, v] of pending) L.set(id, v); pending.clear(); saveCache(); }
  function store(id, v) { V.set(id, v); }
  function setParam(id, v, { quiet } = {}) {
    const c = CELL.get(id); if (!c) return; v = clampC(c, v);
    if (V.get(id) === v) return; record(id); store(id, v); send(id, v);
    for (const o of owners.get(id) || []) { emit("change", { fx: o.fx, label: o.label, v, cell: c }); redrawKnobs(o.fx.id, o.label); }
    if (!owners.has(id) && !quiet) emit("param", { id, v, cell: c });
  }
  function set(fxId, label, v) { const c = cellOf(byId[fxId], label); if (c) setParam(c.id, v); }
  function setStyle(fxId, i) {
    const fx = byId[fxId]; if (!fx.styleCell) return; const n = fx.styleCell.values.length; i = ((i % n) + n) % n;
    if (fx.style === i) return; record(fx.styleCell.id); store(fx.styleCell.id, i); send(fx.styleCell.id, i); emit("style", { fx });
  }
  function setState(fxId, s) {
    const fx = byId[fxId]; if (fx.always || !fx.control) return; if (s === "hit" && !hasHit(fx)) s = "on";
    const v = ["off", "on", "hit"].indexOf(s); if (V.get(fx.control.id) === v) return;
    record(fx.control.id); store(fx.control.id, v); send(fx.control.id, v); emit("state", { fx });
  }
  const nextState = fx => (fx.state === "off" ? "on" : "off");
  const hasHit = fx => !!(fx.control && fx.control.values.includes("HIT"));
  const hitOn = () => !!V.get(HIT);
  function setHit(on) { on = on ? 1 : 0; if (V.get(HIT) === on) return; store(HIT, on); send(HIT, on); emit("hit", { on: !!on }); }
  // An effect is audible when ON, or when set to HIT and HIT is engaged.
  const live = fx => fx.state === "on" || (fx.state === "hit" && hitOn());

  // Undo: one step per gesture (changes within 600 ms of each other count as one step)
  const history = []; let lastRec = 0, group = null;
  function record(id) {
    if (replaying) return; const now = performance.now();
    if (!group || now - lastRec > 600) { group = new Map(); history.push(group); if (history.length > 100) history.shift(); }
    if (!group.has(id)) group.set(id, V.get(id)); lastRec = now; emit("history", { n: history.length });
  }
  let replaying = false;
  function undo() {
    const g = history.pop(); if (!g) return false; replaying = true;
    for (const [id, v] of g) if (v != null) applyRemote(id, v, true);
    replaying = false; group = null; emit("history", { n: history.length }); emit("sync", {}); return true;
  }
  // Put a value in the model and send it (used by undo / A-B); fires the right events.
  function applyRemote(id, v, sendIt) { store(id, v); if (sendIt) send(id, v); }
  const snapshot = () => new Map([...CELL.keys()].filter(id => id !== HIT && V.has(id)).map(id => [id, V.get(id)]));
  function restore(snap) { replaying = true; for (const [id, v] of snap) if (V.get(id) !== v) applyRemote(id, v, true); replaying = false; emit("sync", {}); }

  // ── demo presets (no pedal) ──────────────────────────────────────────────
  const DEMO_NAMES = ["Open Mic Warm", "Ballad Hall", "Coffee House Duet", "Big Chorus Stack", "Slapback Country", "Octave Doubler", "Radio Verse",
    "Megaphone Bridge", "Tight Double", "Church Choir", "Tape Echo Folk", "Robot HardTune", "Shimmer Room", "Dry Talk", "Arena Anthem",
    "Bossa Nylon", "Campfire", "Spring Surf", "Unplugged Set", "Encore"];
  function loadDemo(i) {
    for (const fx of FX) {
      for (const c of [...fx.params, ...fx.adv]) V.set(c.id, fx.demo[c.label] ?? c.default ?? clampC(c, 0));
      if (fx.styleCell) V.set(fx.styleCell.id, fx.demo.style ?? 0);
      if (fx.control) { const k = FX.indexOf(fx), r = (i * 7 + k * 13 + (i * k) % 5) % 5;
        V.set(fx.control.id, i === 2 ? fx.demo.state ?? 0 : r < 2 ? 0 : r === 4 && hasHit(fx) ? 2 : 1); }
    }
    for (const [id, c] of CELL) if (!V.has(id)) V.set(id, c.demoValue ?? c.default ?? clampC(c, 0));
    V.set(HIT, 0);
  }

  // ── preset + sync with the pedal ─────────────────────────────────────────
  const names = Object.assign({}, L.store.get("pa-preset-names") || {});   // number → name, learned while browsing
  const P = { num: 12, name: DEMO_NAMES[2], live: false };
  let demoIdx = 2; try { const s = sessionStorage.getItem("pa-demo-preset"); if (s !== null && DEMO_NAMES[+s]) demoIdx = +s; } catch {}
  loadDemo(demoIdx); P.num = demoIdx + 10; P.name = DEMO_NAMES[demoIdx];
  const cacheKey = n => "pa-vals-" + n;
  function saveCache() { if (!P.live || P.num == null) return; try { sessionStorage.setItem(cacheKey(P.num), JSON.stringify([...V])); } catch {} }
  function loadCache(n) { try { const a = JSON.parse(sessionStorage.getItem(cacheKey(n))); if (a) { for (const [id, v] of a) V.set(id, v); return true; } } catch {} return false; }
  const recent = id => performance.now() - (touched.get(id) || 0) < 1500;   // don't overwrite what the user is dragging
  // Read order: what makes the views look right first (on/off, styles, HIT), then every value.
  const firstIds = () => [HIT, ...FX.flatMap(f => [f.control && f.control.id, f.styleCell && f.styleCell.id]).filter(x => x != null)];
  const allIds = () => [...new Set([...firstIds(), ...CELL.keys()])];
  let gen = 0, syncing = false;
  async function sync() {
    if (!L.ready) return; const g = ++gen; syncing = true; emit("syncing", { on: true });
    const alive = () => g === gen && L.ready;
    try {
      const n = await L.get(PRESET); if (!alive()) return;
      if (n != null && n !== P.num) { P.num = n; P.name = names[n] ?? null; if (loadCache(n)) emit("sync", {}); emit("preset", preset()); }
      if (n != null && names[n] == null) { const nm = await L.presetName(); if (!alive()) return; if (nm != null) { names[n] = nm; L.store.set("pa-preset-names", names); } P.name = names[n] ?? null; emit("preset", preset()); }
      const apply = (id, v) => { if (!recent(id)) V.set(id, v); };
      if (!(await L.getMany(firstIds(), alive, apply))) return; emit("sync", {});
      if (!(await L.getMany(allIds().filter(id => !firstIds().includes(id)), alive, apply))) return;
      saveCache(); emit("sync", {});
    } finally { if (g === gen) { syncing = false; emit("syncing", { on: false }); } }
  }
  let syncT = null; const syncSoon = (ms = 400) => { clearTimeout(syncT); syncT = setTimeout(sync, ms); };
  L.on("ready", () => { P.live = true; P.num = null; P.name = "…"; emit("preset", preset()); emit("link", linkState()); sync(); });
  L.on("status", () => { if (!L.ready && P.live) { P.live = false; } emit("link", linkState()); paintBar(); });
  L.on("program", () => { gen++; syncSoon(120); });
  L.on("panel", e => { if (!e.self) syncSoon(e.e0 === 0xAE ? 500 : 250); });   // something was used on the unit itself
  const preset = () => ({ ...P, names });
  const linkState = () => ({ status: L.status, message: L.message, ready: L.ready });

  // Preset stepping uses the pedal's own front arrows (they step presets on its preset screen).
  function waitProgram(ms = 900) { return new Promise(res => { const off = L.on("program", p => { off(); clearTimeout(t); res(p); }); const t = setTimeout(() => { off(); res(null); }, ms); }); }
  async function stepPreset(d) {
    if (!P.live) { demoIdx = (demoIdx + d + DEMO_NAMES.length) % DEMO_NAMES.length; try { sessionStorage.setItem("pa-demo-preset", demoIdx); } catch {}
      loadDemo(demoIdx); P.num = demoIdx + 10; P.name = DEMO_NAMES[demoIdx]; history.length = 0; emit("preset", preset()); emit("sync", {}); return; }
    history.length = 0; await L.press(d > 0 ? L.EVT.next : L.EVT.prev);
  }
  async function gotoPreset(n) {
    if (!P.live) { stepPreset(n - 10 - demoIdx); return; }
    let cur = P.num, guard = 0; if (cur == null || n === cur) return;
    emit("busy", { text: `Going to preset ${n}…` });
    while (cur !== n && guard++ < 400) {
      const w = waitProgram(); await L.press(n > cur ? L.EVT.next : L.EVT.prev);
      if ((await w) == null) break; cur = await L.get(PRESET); if (cur == null) break;
    }
    emit("busy", null); sync();
  }
  // Walk every preset once to learn the names (the pedal only reports the current preset's name), then go back.
  async function learnNames() {
    if (!P.live) return; const start = await L.get(PRESET); if (start == null) return;
    let cur = start; const seen = new Set([start]);
    for (let i = 0; i < 400; i++) {
      emit("busy", { text: `Learning preset names… ${seen.size}`, cancel: true }); if (cancelLearn) break;
      const w = waitProgram(); await L.press(L.EVT.next); if ((await w) == null) break;
      const n = await L.get(PRESET); if (n == null || seen.has(n)) break; seen.add(n); cur = n;
      const nm = await L.presetName(); if (nm != null) { names[n] = nm; L.store.set("pa-preset-names", names); }
    }
    cancelLearn = false; emit("busy", { text: "Going back…" }); await gotoPreset(start);
  }
  let cancelLearn = false;

  // ── gestures: tap / double-tap / hold / drag on one element ──────────────
  // o: {tap, double, hold, holdEnd, drag(dx, dy, e, start), dragEnd, threshold}. When `double` is set, `tap` waits 260 ms.
  function gesture(el, o) {
    let st = null, lastTap = 0, tapT = null;
    el.style.touchAction = o.drag ? "none" : "manipulation";
    el.addEventListener("pointerdown", e => {
      if (e.button > 0 || e.__pa) return; e.__pa = true;   // innermost gesture wins (a knob on a pedal, a switch on a tile)
      st = { x: e.clientX, y: e.clientY, mode: "press", held: false, id: e.pointerId };
      try { el.setPointerCapture(e.pointerId); } catch {}
      st.t = setTimeout(() => { if (st && st.mode === "press") { st.held = true; o.hold && o.hold(e); } }, o.holdMs || 450);
    });
    el.addEventListener("pointermove", e => {
      if (!st) return; const dx = e.clientX - st.x, dy = e.clientY - st.y;
      if (st.mode === "press" && Math.hypot(dx, dy) > (o.threshold || 8) && o.drag && !(st.held && o.holdEnd && !o.dragAfterHold)) { clearTimeout(st.t); st.mode = "drag"; o.dragStart && o.dragStart(e, st.held); }
      if (st.mode === "drag") o.drag(dx, dy, e, st);
    });
    const end = e => {
      if (!st) return; clearTimeout(st.t); const s = st; st = null;
      if (s.mode === "drag") { o.dragEnd && o.dragEnd(e); return; }
      if (s.held) { o.holdEnd && o.holdEnd(e); return; }
      if (e.type !== "pointerup") return;
      const now = performance.now();
      if (o.double && now - lastTap < 300) { clearTimeout(tapT); lastTap = 0; o.double(e); return; }
      lastTap = now;
      if (o.double) tapT = setTimeout(() => o.tap && o.tap(e), 260); else o.tap && o.tap(e);
    };
    el.addEventListener("pointerup", end); el.addEventListener("pointercancel", end);
    el.addEventListener("contextmenu", e => e.preventDefault());
  }
  // Delegated version for elements that are re-rendered: gestures on anything matching `sel` inside root.
  function gestureAll(root, sel, make) {
    const done = new WeakSet();
    const bind = () => root.querySelectorAll(sel).forEach(el => { if (!done.has(el)) { done.add(el); gesture(el, make(el)); } });
    bind(); new MutationObserver(bind).observe(root, { childList: true, subtree: true });
  }

  // ── Knob: drag (up or right = more), hold still first = fine, double-tap = default, wheel, arrow keys ──
  function knob(fx, label, o = {}) {
    const s = o.size || 44, c = cellOf(fx, label);
    return `<div class="knob" tabindex="0" role="slider" aria-label="${fx.name} ${label}" data-fx="${fx.id}" data-p="${label}" data-s="${s}" style="--kc:${o.color || color(fx)}">
      <svg width="${s}" height="${s}" viewBox="0 0 ${s} ${s}"></svg>${o.hideValue ? "" : `<span class="kv"></span>`}${o.hideLabel ? "" : `<span class="kl">${o.label || label}</span>`}</div>`;
  }
  const polar = (cx, cy, r, a) => [cx + r * Math.cos((a - 90) * Math.PI / 180), cy + r * Math.sin((a - 90) * Math.PI / 180)];
  function arc(cx, cy, r, a0, a1) {
    if (Math.abs(a1 - a0) < .5) return "";
    const [x0, y0] = polar(cx, cy, r, Math.min(a0, a1)), [x1, y1] = polar(cx, cy, r, Math.max(a0, a1));
    return `M${x0},${y0} A${r},${r} 0 ${Math.abs(a1 - a0) > 180 ? 1 : 0} 1 ${x1},${y1}`;
  }
  function drawKnob(el) {
    const fx = byId[el.dataset.fx], c = cellOf(fx, el.dataset.p); if (!c) return;
    const v = fx.vals[c.label], s = +el.dataset.s;
    const t = (v - c.min) / (c.max - c.min || 1), a = -135 + 270 * t, r = s / 2 - 3, cx = s / 2;
    const zero = c.min < 0 && c.max > 0 && c.format !== "dB" ? -135 + 270 * (-c.min / (c.max - c.min)) : -135;
    const [px, py] = polar(cx, cx, r * .62, a), [qx, qy] = polar(cx, cx, r * .2, a);
    el.querySelector("svg").innerHTML =
      `<path d="${arc(cx, cx, r, -135, 135)}" stroke="#ffffff1a" stroke-width="3" fill="none" stroke-linecap="round"/>
       <path d="${arc(cx, cx, r, zero, a)}" stroke="var(--kc)" stroke-width="3" fill="none" stroke-linecap="round"/>
       <circle cx="${cx}" cy="${cx}" r="${r - 5}" fill="url(#kg)" stroke="#000" stroke-opacity=".5"/>
       <line x1="${qx}" y1="${qy}" x2="${px}" y2="${py}" stroke="#fff" stroke-width="2" stroke-linecap="round"/>`;
    const kv = el.querySelector(".kv"); if (kv) kv.textContent = fmt(c, v);
    el.setAttribute("aria-valuenow", v); el.setAttribute("aria-valuetext", fmt(c, v));
  }
  const redrawKnobs = (fxId, label) => document.querySelectorAll(`.knob[data-fx="${fxId}"][data-p="${CSS.escape(label)}"]`).forEach(drawKnob);
  function initKnobs(root = document) { root.querySelectorAll(".knob").forEach(drawKnob); }
  document.addEventListener("DOMContentLoaded", () => {
    document.body.insertAdjacentHTML("afterbegin", `<svg width="0" height="0" style="position:absolute"><defs><radialGradient id="kg" cx="40%" cy="35%"><stop offset="0" stop-color="#4a525d"/><stop offset="1" stop-color="#1c2027"/></radialGradient></defs></svg>`);
    gestureAll(document.body, ".knob", k => {
      const fx = byId[k.dataset.fx], label = k.dataset.p, c = () => cellOf(fx, label); let v0, fine;
      return { double: () => { set(fx.id, label, c().default ?? 0); toast(`${fx.name} ${label} reset`); },
        hold: () => { fine = true; k.classList.add("fine"); }, holdEnd: () => { fine = false; k.classList.remove("fine"); }, dragAfterHold: true,
        dragStart: (e, held) => { v0 = fx.vals[label]; fine = held; k.classList.add("active"); if (fine) k.classList.add("fine"); },
        drag: (dx, dy) => { const span = c().max - c().min; set(fx.id, label, v0 + (dx - dy) / (fine ? 900 : 180) * span); },
        dragEnd: () => { k.classList.remove("active", "fine"); } };
    });
  });
  document.addEventListener("wheel", e => {
    const k = e.target.closest(".knob"); if (!k) return; e.preventDefault();
    const fx = byId[k.dataset.fx]; set(k.dataset.fx, k.dataset.p, fx.vals[k.dataset.p] + (e.deltaY < 0 ? 1 : -1));
  }, { passive: false });
  document.addEventListener("keydown", e => {
    const k = e.target.closest && e.target.closest(".knob"); if (!k) return;
    const d = { ArrowUp: 1, ArrowRight: 1, ArrowDown: -1, ArrowLeft: -1 }[e.key]; if (!d) return; e.preventDefault();
    const fx = byId[k.dataset.fx]; set(k.dataset.fx, k.dataset.p, fx.vals[k.dataset.p] + d * (e.shiftKey ? 10 : 1));
  });

  // ── Fader: horizontal bar; drag anywhere on it (relative, so a touch never jumps the value), double-tap = default,
  //    hold the value text to type a number. Works for FX parameters (fx, label) or any registered parameter (id). ──
  function fader(ref, o = {}) {
    const c = typeof ref === "number" ? CELL.get(ref) : cellOf(byId[ref.fx], ref.label);
    return `<div class="fader" data-id="${c.id}" style="--fc:${o.color || "var(--fc, var(--accent))"}"><div class="ftrack"><div class="ffill"></div></div><span class="fval"></span></div>`;
  }
  const getV = id => { const c = CELL.get(id); return V.get(id) ?? c.default ?? clampC(c, 0); };
  function drawFader(el) {
    const c = CELL.get(+el.dataset.id), v = getV(c.id), t = (v - c.min) / (c.max - c.min || 1);
    const z = c.min < 0 && c.max > 0 && c.format !== "dB" ? -c.min / (c.max - c.min) : 0;
    const f = el.querySelector(".ffill"); f.style.left = Math.min(z, t) * 100 + "%"; f.style.width = Math.abs(t - z) * 100 + "%";
    el.querySelector(".fval").textContent = fmt(c, v);
  }
  function initFaders(root = document) {
    root.querySelectorAll(".fader").forEach(drawFader);
    if (root.__faders) return; root.__faders = true;
    gestureAll(root, ".fader", el => {
      const id = +el.dataset.id, c = CELL.get(id); let v0, w;
      return { double: () => { setParam(id, c.default ?? clampC(c, 0)); drawFader(el); },
        tap: e => { if (e.target.closest(".fval")) typeValue(el, id); },
        dragStart: () => { v0 = getV(id); w = el.querySelector(".ftrack").offsetWidth; el.classList.add("active"); },
        drag: (dx) => { setParam(id, v0 + dx / w * (c.max - c.min)); drawFader(el); }, dragEnd: () => el.classList.remove("active") };
    });
  }
  function typeValue(el, id) {
    const c = CELL.get(id), span = el.querySelector(".fval"), inp = document.createElement("input");
    inp.className = "ftype"; inp.inputMode = "decimal"; inp.value = getV(id); span.replaceWith(inp); inp.focus(); inp.select();
    const done = ok => { if (ok) { const n = parseFloat(inp.value.replace("−", "-")); if (!isNaN(n)) setParam(id, n); } inp.replaceWith(span); drawFader(el); };
    inp.onkeydown = e => { if (e.key === "Enter") done(true); if (e.key === "Escape") done(false); };
    inp.onblur = () => done(true);
  }
  document.addEventListener("pa:change", e => document.querySelectorAll(`.fader[data-id="${e.detail.cell.id}"]`).forEach(drawFader));
  document.addEventListener("pa:param", e => document.querySelectorAll(`.fader[data-id="${e.detail.id}"]`).forEach(drawFader));
  document.addEventListener("pa:sync", () => { document.querySelectorAll(".fader").forEach(drawFader); document.querySelectorAll(".knob").forEach(drawKnob); });

  // ── toast ────────────────────────────────────────────────────────────────
  let toastEl, toastT;
  function toast(t, ms = 1100) {
    if (!toastEl) { toastEl = document.createElement("div"); toastEl.className = "patoast"; document.body.appendChild(toastEl); }
    toastEl.textContent = t; toastEl.classList.add("show"); clearTimeout(toastT); toastT = setTimeout(() => toastEl.classList.remove("show"), ms);
  }

  // ── Common top bar: connection · preset · views ──────────────────────────
  const VIEWS = [["1-pedalboard.html", "Board", "▦"], ["2-studio.html", "Editor", "☰"], ["3-signal-grid.html", "Grid", "⇶"], ["4-stage.html", "Stage", "◉"], ["5-voice-map.html", "Map", "☊"]];
  let bar;
  function nav(o = {}) {
    const here = location.pathname.split("/").pop() || "index.html";
    document.documentElement.classList.toggle("bigbar", !!o.big);
    document.body.insertAdjacentHTML("afterbegin", `<nav class="pbar ${o.big ? "big" : ""}">
      <div class="cwrap"><button class="conn" title="Pedal connection"><i></i><span></span></button>
        <div class="cpop" hidden><div class="cmsg"></div>
          <label>To pedal (MIDI out)<select data-port="out"></select></label><label>From pedal (MIDI in)<select data-port="inp"></select></label>
          <label class="chk"><input type="checkbox" data-ble> Through a Bluetooth MIDI adapter</label>
          <div class="crow"><button data-act="connect" class="pri">Connect</button><button data-act="names">Learn preset names</button></div>
          <div class="note">Hold ◀ ▶ to jump 10 presets. Effects follow the pedal live; turning a knob on the unit updates every view.</div></div></div>
      <div class="psel">
        <button class="pstep" data-step="-1" aria-label="Previous preset">◀</button>
        <button class="pname" aria-haspopup="listbox"><span class="pnum"></span><span class="pnm"></span><span class="car">▾</span></button>
        <button class="pstep" data-step="1" aria-label="Next preset">▶</button>
        <div class="plist" hidden><input type="search" placeholder="Find preset…" aria-label="Find preset"><div class="pitems" role="listbox"></div><div class="pfoot"></div></div>
      </div>
      ${o.big ? `<span class="pinfo"></span>` : ""}
      <span class="sp"></span><span class="busy" hidden></span>
      <div class="views">${VIEWS.map(([h, t, ic], i) => `<a href="${h}${location.search}" class="${h === here ? "on" : ""}" title="${t} (${i + 1})"><b>${ic}</b><span>${t}</span></a>`).join("")}</div>
    </nav>`);
    bar = document.querySelector(".pbar");
    const list = bar.querySelector(".plist"), q = list.querySelector("input"), items = list.querySelector(".pitems"), name = bar.querySelector(".pname");
    const entries = () => P.live ? Object.entries(names).map(([n, nm]) => ({ num: +n, name: nm })).sort((a, b) => a.num - b.num) : DEMO_NAMES.map((nm, i) => ({ num: i + 10, name: nm }));
    const fill = () => { const f = q.value.trim().toLowerCase(), all = entries();
      items.innerHTML = all.filter(p => !f || (p.num + " " + p.name).toLowerCase().includes(f)).map(p => `<button role="option" data-n="${p.num}" class="${p.num === P.num ? "sel" : ""}"><span>${p.num}</span>${p.name || "—"}</button>`).join("") || `<div class="none">No match</div>`;
      list.querySelector(".pfoot").innerHTML = P.live ? `<span class="note">${all.length} names known.</span> <button data-act="names">Learn all</button>` : `<span class="note">Demo presets: connect the pedal for yours.</span>`; };
    const open = v => { list.hidden = !v; name.setAttribute("aria-expanded", v); if (v) { q.value = ""; fill(); items.querySelector(".sel")?.scrollIntoView({ block: "center" }); } };
    gesture(name, { tap: () => open(list.hidden), drag: dx => { name.style.transform = `translateX(${Math.max(-60, Math.min(60, dx / 3))}px)`; },
      dragEnd: e => { name.style.transform = ""; } , threshold: 12 });
    // swipe the name: the drag handler above shows it moving; the step happens on release
    let sx = null; name.addEventListener("pointerdown", e => sx = e.clientX);
    name.addEventListener("pointerup", e => { if (sx != null && Math.abs(e.clientX - sx) > 50) stepPreset(e.clientX < sx ? 1 : -1); sx = null; });
    bar.querySelectorAll(".pstep").forEach(b => gesture(b, { tap: () => stepPreset(+b.dataset.step),
      hold: () => { const t = (P.num ?? 0) + 10 * +b.dataset.step; gotoPreset(P.live ? t : Math.max(10, Math.min(29, t))); } }));
    q.oninput = fill;
    q.onkeydown = e => { if (e.key === "Enter") { const b = items.querySelector("button"); if (b) { gotoPreset(+b.dataset.n); open(false); } } if (e.key === "Escape") open(false); };
    items.onclick = e => { const b = e.target.closest("[data-n]"); if (b) { gotoPreset(+b.dataset.n); open(false); } };
    list.querySelector(".pfoot").onclick = e => { if (e.target.closest("[data-act=names]")) { open(false); learnNames(); } };
    // connection popover
    const cpop = bar.querySelector(".cpop"), conn = bar.querySelector(".conn");
    const fillPorts = () => { const ps = L.ports(), ch = L.choice();
      cpop.querySelector('[data-port="out"]').innerHTML = `<option value="">—</option>` + ps.outputs.map(p => `<option value="${p.id}" ${p.id === ch.out ? "selected" : ""}>${p.name}</option>`).join("");
      cpop.querySelector('[data-port="inp"]').innerHTML = `<option value="">—</option>` + ps.inputs.map(p => `<option value="${p.id}" ${p.id === ch.inp ? "selected" : ""}>${p.name}</option>`).join("");
      cpop.querySelector("[data-ble]").checked = ch.ble; cpop.querySelector(".cmsg").textContent = L.message; };
    conn.onclick = async () => { if (cpop.hidden && !L.access) await L.start(); fillPorts(); cpop.hidden = !cpop.hidden; };
    cpop.onclick = async e => { const a = e.target.closest("[data-act]"); if (!a) return;
      if (a.dataset.act === "connect") { if (!L.access && !(await L.start())) { fillPorts(); return; } L.use(cpop.querySelector('[data-port="out"]').value, cpop.querySelector('[data-port="inp"]').value, cpop.querySelector("[data-ble]").checked); }
      if (a.dataset.act === "names") { cpop.hidden = true; learnNames(); } };
    L.on("ports", fillPorts); L.on("status", () => { if (!cpop.hidden) fillPorts(); });
    document.addEventListener("pointerdown", e => { if (!list.hidden && !e.target.closest(".psel")) open(false); if (!cpop.hidden && !e.target.closest(".cwrap")) cpop.hidden = true; });
    document.addEventListener("keydown", e => {
      if (e.target.closest && e.target.closest("input,select,textarea,.knob")) return;
      if (e.key === "[" || e.key === "PageUp") stepPreset(-1); else if (e.key === "]" || e.key === "PageDown") stepPreset(1);
      else if (/^[1-5]$/.test(e.key) && !e.metaKey && !e.ctrlKey) location.href = VIEWS[+e.key - 1][0];
    });
    document.addEventListener("pa:busy", e => { const b = bar.querySelector(".busy"); b.hidden = !e.detail; if (e.detail) b.innerHTML = e.detail.text + (e.detail.cancel ? ` <button>Stop</button>` : "");
      const s = b.querySelector("button"); if (s) s.onclick = () => (cancelLearn = true); });
    document.addEventListener("pa:preset", paintBar); document.addEventListener("pa:syncing", paintBar);
    paintBar();
    L.start({ auto: true });   // connect on load if the browser allows it
  }
  function paintBar() {
    if (!bar) return;
    bar.querySelector(".pnum").textContent = P.num ?? "··"; bar.querySelector(".pnm").textContent = P.name ?? "…";
    const c = bar.querySelector(".conn"), st = L.ready ? "ready" : L.status === "connecting" ? "connecting" : "demo";
    c.dataset.s = st; c.querySelector("span").textContent = st === "ready" ? (syncing ? "Syncing" : "Pedal") : st === "connecting" ? "Connecting" : "Demo";
    c.title = L.message; const pi = bar.querySelector(".pinfo"); if (pi) pi.textContent = keyInfo();
  }
  const keyInfo = () => { const h = byId.harmony, k = cellOf(h, "KEY"), d = byId.delay; return `KEY ${fmt(k, h.vals.KEY)} · ${d.vals.TEMPO} BPM`; };
  document.addEventListener("pa:sync", paintBar); document.addEventListener("pa:change", e => { if (["KEY", "TEMPO"].includes(e.detail.label)) paintBar(); });

  // ── Effect editor (all of one effect: state, style pictures, every knob) + a bottom sheet to show it in ──
  const statesOf = fx => fx.always ? [] : hasHit(fx) ? ["off", "on", "hit"] : ["off", "on"];
  function editorHTML(fx, o = {}) {
    const st = statesOf(fx);
    return `${o.head === false ? "" : `<div class="sh-head">${artHTML(img(fx))}<div><h3>${fx.name}</h3><div class="note">${styleName(fx)}</div></div>
        ${st.length ? `<div class="seg">${st.map(s => `<button data-s="${s}" class="${fx.state === s ? "sel" : ""}">${s.toUpperCase()}</button>`).join("")}</div>` : ""}
        ${o.close ? `<button class="x" aria-label="Close">✕</button>` : ""}</div>`}
      ${fx.styleCell ? `<div class="sh-sec"><h4>Style · ${fx.styleCell.values.length}</h4><div class="styles">${fx.styleCell.values.map((v, i) =>
        `<button data-i="${i}" class="${i === fx.style ? "sel" : ""}">${artHTML(fx.images[i] ?? fx.images[0])}${v}</button>`).join("")}</div></div>` : ""}
      <div class="sh-sec"><h4>Parameters</h4><div class="bigknobs">${fx.params.map(c => knob(fx, c.label, { size: o.size || 64 })).join("")}</div></div>
      ${fx.adv.length ? `<div class="sh-sec"><h4>Advanced</h4><div class="bigknobs">${fx.adv.map(c => knob(fx, c.label, { size: (o.size || 64) - 8 })).join("")}</div></div>` : ""}`;
  }
  function wireEditor(root, fx) {
    root.querySelectorAll(".seg button[data-s]").forEach(b => b.onclick = () => setState(fx.id, b.dataset.s));
    root.querySelectorAll(".styles button[data-i]").forEach(b => b.onclick = () => setStyle(fx.id, +b.dataset.i));
    initKnobs(root);
  }
  function refreshEditor(root, fx) {   // update in place (keeps scroll position and any drag in progress)
    root.querySelectorAll(".seg button[data-s]").forEach(b => b.classList.toggle("sel", b.dataset.s === fx.state));
    root.querySelectorAll(".styles button[data-i]").forEach(b => b.classList.toggle("sel", +b.dataset.i === fx.style));
    const h = root.querySelector(".sh-head"); if (h) { h.querySelector(".art").outerHTML = artHTML(img(fx)); h.querySelector(".note").textContent = styleName(fx); }
    initKnobs(root);
  }
  let sheetEl, sheetBg, sheetFx = null;
  function openSheet(fx) {
    if (!sheetEl) { document.body.insertAdjacentHTML("beforeend", `<div class="sheet" id="pasheet"></div><div class="sheet-bg" id="pasheetbg"></div>`);
      sheetEl = document.getElementById("pasheet"); sheetBg = document.getElementById("pasheetbg"); sheetBg.onclick = closeSheet;
      const upd = e => { if (sheetFx && (!e.detail || !e.detail.fx || e.detail.fx === sheetFx)) refreshEditor(sheetEl, sheetFx); };
      ["state", "style", "sync"].forEach(t => document.addEventListener("pa:" + t, upd)); document.addEventListener("pa:preset", closeSheet); }
    sheetFx = fx; sheetEl.style.setProperty("--pc", color(fx)); sheetEl.innerHTML = editorHTML(fx, { close: true });
    wireEditor(sheetEl, fx); sheetEl.querySelector(".x").onclick = closeSheet;
    sheetEl.classList.add("open"); sheetBg.classList.add("open"); sheetEl.scrollTop = 0;
  }
  function closeSheet() { if (!sheetEl) return; sheetEl.classList.remove("open"); sheetBg.classList.remove("open"); sheetFx = null; }

  window.PA = { editorHTML, wireEditor, refreshEditor, openSheet, closeSheet, statesOf, FX, byId, cellOf, fmt, seconds, styleName, img, artHTML, color, set, setParam, setStyle, setState, nextState, hasHit, live,
    setHit, hitOn, getV, addParam, knob, initKnobs, drawKnob, fader, initFaders, gesture, gestureAll, toast, nav, emit, undo, snapshot, restore,
    stepPreset, gotoPreset, learnNames, keyInfo, link: L,
    vocal: FX.filter(f => f.side === "vocal"), guitar: FX.filter(f => f.side === "guitar"),
    get preset() { return preset(); }, get connected() { return L.ready; } };
})();
