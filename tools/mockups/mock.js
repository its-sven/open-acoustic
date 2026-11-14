// Shared model + helpers for the Remote UI mockups. Mockups only: values live in memory, nothing is sent to the pedal.
// Effect pages, labels, ranges, style lists and pictures come from the real ../pa-menus.js and ../pa-images.js.
(function () {
  const M = window.PA_MENUS, IM = window.PA_IMAGES || {};
  const pageOf = (menu, title) => (M[menu] && M[menu].pages.find(p => p.title === title)) || null;
  const cellsOf = p => (p ? (p.rows || []).flat().filter(Boolean) : []);

  // Demo preset. Signal order follows the firmware's send parameters (LEAD TO UMOD, UMOD TO DELAY, DELAY TO REVERB, GTR TO UMOD ...).
  const DEF = [
    { id: "hardtune",   side: "vocal",  name: "HardTune",   color: "--c-hardtune",   page: ["VOCAL", "HARDTUNE"],   state: "off", style: 3, vals: { SHIFT: 0, GENDER: 0 } },
    { id: "transducer", side: "vocal",  name: "Transducer", color: "--c-transducer", page: ["VOCAL", "TRANSDUCER"], adv: [["VOCAL ADV", "TRANSDUCER"]], state: "hit", style: 0, vals: { DRIVE: 62, FILTER: 40, ROUTING: 0, GAIN: 0, "GATE THRESHOLD": -40 } },
    { id: "double",     side: "vocal",  name: "Double",     color: "--c-double",     page: ["VOCAL", "DOUBLE"],     state: "on",  style: 1, vals: { LEVEL: -6 }, voices: true },
    { id: "harmony",    side: "vocal",  name: "Harmony",    color: "--c-harmony",    page: ["VOCAL", "HARMONY"],    adv: [["VOCAL ADV", "HARMONY"]], state: "on", style: 6, vals: { LEVEL: -4, KEY: 0, SCALE: 0, HUMANIZE: 35, PORTAMENTO: 40 }, voices: true },
    { id: "umod",       side: "vocal",  name: "uMOD",       color: "--c-umod",       page: ["VOCAL", "uMOD"],       state: "off", style: 4, vals: { LEVEL: -12, SPEED: 180 } },
    { id: "delay",      side: "vocal",  name: "Delay",      color: "--c-delay",      page: ["VOCAL", "DELAY"],      adv: [["VOCAL ADV", "DELAY"]], state: "on", style: 1, vals: { LEVEL: -14, FEEDBACK: 28, FILTER: 1, TEMPO: 96 } },
    { id: "reverb",     side: "vocal",  name: "Reverb",     color: "--c-reverb",     page: ["VOCAL", "REVERB"],     state: "on",  style: 9, vals: { LEVEL: -10, DECAY: 24 } },
    { id: "g-bodyrez",  side: "guitar", name: "BodyRez",    color: "--c-bodyrez",    page: ["GUITAR", "BODYREZ EQ"], adv: [["GUITAR", "BODYREZ SHELF EQ"], ["GUITAR", "BODYREZ PARAMETRIC EQ"]], state: "on", always: true, style: 5, vals: { AMOUNT: 6, "LOW GAIN": -2, "HI GAIN": 3, "LOW FREQ": 60, "HI FREQ": 180, "PARA 1 FREQ": 95, "PARA 2 FREQ": 150, "PARA 1 WIDTH": 16, "PARA 2 WIDTH": 12, "PARA 1 GAIN": -4, "PARA 2 GAIN": 2 } },
    { id: "g-comp",     side: "guitar", name: "Comp",       color: "--c-comp",       page: ["GUITAR", "BODYREZ COMPRESSOR"], state: "on", always: true, img: 9, vals: { THRESHOLD: -18, RATIO: 8, ATTACK: 6, RELEASE: 10, "MAKEUP GAIN": 4, AMBIENCE: -12 } },
    { id: "g-umod",     side: "guitar", name: "uMOD",       color: "--c-umod",       page: ["GUITAR", "GUITAR uMOD"],   adv: [["GUITAR ADV", "GUITAR uMOD"]], state: "on", style: 0, vals: { "UMOD LEVEL": -10, SPEED: 120, DEPTH: 60 } },
    { id: "g-delay",    side: "guitar", name: "Delay",      color: "--c-delay",      page: ["GUITAR", "GUITAR DELAY"],  adv: [["GUITAR ADV", "GUITAR DELAY"]], state: "off", style: 2, vals: { "DELAY LEVEL": -16, FEEDBACK: 22, TEMPO: 96, FILTER: 1 } },
    { id: "g-reverb",   side: "guitar", name: "Reverb",     color: "--c-reverb",     page: ["GUITAR", "GUITAR REVERB"], adv: [["GUITAR ADV", "GUITAR REVERB"]], state: "on", style: 0, vals: { "REVERB LEVEL": -12, "REVERB DECAY": 30, "REVERB PRE DLY": 20 } },
  ];

  const FX = DEF.map(d => {
    const p = pageOf(...d.page), cells = cellsOf(p);
    const styleCell = d.img ? null : cells.find(c => c.format === "list" && c.values && c.values.length > 3) || null;
    const seen = new Set(cells.map(c => c.param));
    const adv = (d.adv || []).flatMap(a => cellsOf(pageOf(...a))).filter(c => !seen.has(c.param) && seen.add(c.param));
    const fx = { ...d, pageObj: p, control: p && p.control, styleCell, images: (p && p.images) || [],
      params: cells.filter(c => c !== styleCell), adv, vals: {} };
    for (const c of [...fx.params, ...fx.adv]) fx.vals[c.label] = d.vals[c.label] ?? c.default ?? Math.max(c.min, Math.min(c.max, 0));
    return fx;
  });
  const byId = Object.fromEntries(FX.map(f => [f.id, f]));

  const cellOf = (fx, label) => [...fx.params, ...fx.adv].find(c => c.label === label);
  // Value formats: the pedal's own formatter is not decoded yet (TODO.md §2), so time/speed are plausible stand-ins.
  function fmt(c, v) {
    if (!c) return String(v);
    switch (c.format) {
      case "list": return c.values[v] ?? v;
      case "dB": return (v > 0 ? "+" : v < 0 ? "−" : "") + Math.abs(v) + " dB";
      case "time": return (v / 10).toFixed(1) + " s";
      case "scale": return (v / 100).toFixed(2) + " Hz";
      case "BPM": return v + " BPM";
      case "ms": return v + " ms";
      case "%": return v + "%";
      default: return (c.min < 0 && v > 0 ? "+" : "") + String(v).replace("-", "−");
    }
  }
  const styleName = fx => (fx.styleCell ? fx.styleCell.values[fx.style] : fx.name.toUpperCase());
  const img = fx => fx.img ?? fx.images[fx.style] ?? fx.images[0];
  const artHTML = (n, cls = "", extra = "") => `<i class="art ${cls}" style="--m:url('${IM[n] || ""}');${extra}" title="firmware picture ${n}"></i>`;
  const color = fx => `var(${fx.color})`;

  const emit = (type, detail) => document.dispatchEvent(new CustomEvent("pa:" + type, { detail }));
  function set(id, label, v) {
    const fx = byId[id], c = cellOf(fx, label); if (!c) return;
    v = Math.max(c.min, Math.min(c.max, Math.round(v)));
    if (fx.vals[label] === v) return; fx.vals[label] = v;
    emit("change", { fx, label, v, cell: c });
    document.querySelectorAll(`.knob[data-fx="${id}"][data-p="${CSS.escape(label)}"]`).forEach(drawKnob);
  }
  function setStyle(id, i) { const fx = byId[id]; const n = fx.styleCell.values.length; fx.style = ((i % n) + n) % n; emit("style", { fx }); }
  function setState(id, s) { const fx = byId[id]; if (fx.always) return; fx.state = s; emit("state", { fx }); }
  const nextState = fx => (fx.state === "off" ? "on" : "off");
  const hasHit = fx => !!(fx.control && fx.control.values.includes("HIT"));

  // ── Knob ─────────────────────────────────────────────────────────────────
  // HTML: knob(fx, label, {size, hideLabel}). Drag up/down, wheel, arrow keys (Shift = fine), double-click = default.
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
    const fx = byId[el.dataset.fx], c = cellOf(fx, el.dataset.p), v = fx.vals[c.label], s = +el.dataset.s;
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
  function initKnobs(root = document) { root.querySelectorAll(".knob").forEach(drawKnob); }
  // shared gradient for knob caps
  document.addEventListener("DOMContentLoaded", () => {
    document.body.insertAdjacentHTML("afterbegin", `<svg width="0" height="0" style="position:absolute"><defs><radialGradient id="kg" cx="40%" cy="35%"><stop offset="0" stop-color="#4a525d"/><stop offset="1" stop-color="#1c2027"/></radialGradient></defs></svg>`);
  });
  let drag = null;
  document.addEventListener("pointerdown", e => {
    const k = e.target.closest(".knob"); if (!k) return;
    const fx = byId[k.dataset.fx]; drag = { k, y: e.clientY, v: fx.vals[k.dataset.p], c: cellOf(fx, k.dataset.p) };
    k.setPointerCapture(e.pointerId); e.preventDefault();
  });
  document.addEventListener("pointermove", e => {
    if (!drag) return; const span = drag.c.max - drag.c.min;
    set(drag.k.dataset.fx, drag.k.dataset.p, drag.v + (drag.y - e.clientY) / (e.shiftKey ? 600 : 160) * span);
  });
  document.addEventListener("pointerup", () => (drag = null));
  document.addEventListener("dblclick", e => { const k = e.target.closest(".knob"); if (!k) return; const c = cellOf(byId[k.dataset.fx], k.dataset.p); set(k.dataset.fx, k.dataset.p, c.default ?? 0); });
  document.addEventListener("wheel", e => {
    const k = e.target.closest(".knob"); if (!k) return; e.preventDefault();
    const fx = byId[k.dataset.fx]; set(k.dataset.fx, k.dataset.p, fx.vals[k.dataset.p] + (e.deltaY < 0 ? 1 : -1));
  }, { passive: false });
  document.addEventListener("keydown", e => {
    const k = e.target.closest && e.target.closest(".knob"); if (!k) return;
    const d = { ArrowUp: 1, ArrowRight: 1, ArrowDown: -1, ArrowLeft: -1 }[e.key]; if (!d) return; e.preventDefault();
    const fx = byId[k.dataset.fx]; set(k.dataset.fx, k.dataset.p, fx.vals[k.dataset.p] + d * (e.shiftKey ? 10 : 1));
  });

  // ── Long press helper (tap vs hold) ──────────────────────────────────────
  function press(el, { tap, hold, holdEnd, ms = 450 }) {
    let t = null, held = false;
    el.addEventListener("pointerdown", e => { held = false; t = setTimeout(() => { held = true; hold && hold(e); }, ms); });
    const end = e => { clearTimeout(t); if (held) holdEnd && holdEnd(e); else if (e.type === "pointerup") tap && tap(e); held = false; };
    el.addEventListener("pointerup", end); el.addEventListener("pointerleave", e => { if (held) end(e); else clearTimeout(t); });
    el.addEventListener("contextmenu", e => e.preventDefault());
  }

  // ── Common top bar: preset selector + view switcher ─────────────────────
  // One component on every view. The current preset is kept in sessionStorage so it survives switching views.
  const PRESETS = ["Open Mic Warm", "Ballad Hall", "Coffee House Duet", "Big Chorus Stack", "Slapback Country", "Octave Doubler", "Radio Verse",
    "Megaphone Bridge", "Tight Double", "Church Choir", "Tape Echo Folk", "Robot HardTune", "Shimmer Room", "Dry Talk", "Arena Anthem",
    "Bossa Nylon", "Campfire", "Spring Surf", "Unplugged Set", "Encore"].map((name, i) => ({ num: i + 10, name }));
  const HOME = 2, ORIG = Object.fromEntries(FX.map(f => [f.id, f.state]));
  const store = { get() { try { const v = sessionStorage.getItem("pa-mock-preset"); return v === null ? NaN : +v; } catch { return NaN; } },
    set(v) { try { sessionStorage.setItem("pa-mock-preset", v); } catch {} } };
  let cur = Number.isInteger(store.get()) && PRESETS[store.get()] ? store.get() : HOME;
  // each demo preset gets its own on/off/HIT pattern so a preset change is visible in every view
  function applyPreset(i) {
    FX.forEach((f, k) => { if (f.always) return;
      if (i === HOME) { f.state = ORIG[f.id]; return; }
      const r = (i * 7 + k * 13 + (i * k) % 5) % 5; f.state = r < 2 ? "off" : r === 4 && hasHit(f) ? "hit" : "on"; });
  }
  applyPreset(cur);
  const preset = () => ({ ...PRESETS[cur], key: "AUTO → G", tempo: 96, index: cur, count: PRESETS.length });
  function selectPreset(i) {
    cur = ((i % PRESETS.length) + PRESETS.length) % PRESETS.length; store.set(cur); applyPreset(cur);
    paintBar(); emit("preset", preset()); FX.forEach(fx => emit("state", { fx }));
  }
  const VIEWS = [["1-pedalboard.html", "Board", "▦"], ["2-studio.html", "Editor", "☰"], ["3-signal-grid.html", "Grid", "⇶"],
    ["4-stage.html", "Stage", "◉"], ["5-voice-map.html", "Map", "☊"]];
  let bar;
  function nav(o = {}) {
    const here = location.pathname.split("/").pop() || "index.html";
    document.documentElement.classList.toggle("bigbar", !!o.big);
    document.body.insertAdjacentHTML("afterbegin", `<nav class="pbar ${o.big ? "big" : ""}">
      <a class="home" href="index.html" title="Overview of the mockups"><span class="tag">MOCKUP</span></a>
      <div class="psel">
        <button class="pstep" data-step="-1" aria-label="Previous preset" title="Previous preset ( [ )">◀</button>
        <button class="pname" aria-haspopup="listbox" title="Choose a preset · swipe for prev/next"><span class="pnum"></span><span class="pnm"></span><span class="car">▾</span></button>
        <button class="pstep" data-step="1" aria-label="Next preset" title="Next preset ( ] )">▶</button>
        <div class="plist" hidden><input type="search" placeholder="Find preset…" aria-label="Find preset"><div class="pitems" role="listbox"></div></div>
      </div>
      ${o.big ? `<span class="pinfo">KEY G (auto) · 96 BPM</span>` : ""}
      <span class="sp"></span>
      <div class="views" role="tablist">${VIEWS.map(([h, t, ic], i) => `<a href="${h}" class="${h === here ? "on" : ""}" title="${t} view (${i + 1})"><b>${ic}</b><span>${t}</span></a>`).join("")}</div>
    </nav>`);
    bar = document.querySelector(".pbar");
    const list = bar.querySelector(".plist"), q = list.querySelector("input"), items = list.querySelector(".pitems"), name = bar.querySelector(".pname");
    const fill = () => { const f = q.value.trim().toLowerCase();
      items.innerHTML = PRESETS.map((p, i) => ({ p, i })).filter(({ p }) => !f || (p.num + " " + p.name).toLowerCase().includes(f))
        .map(({ p, i }) => `<button role="option" data-i="${i}" class="${i === cur ? "sel" : ""}" aria-selected="${i === cur}"><span>${p.num}</span>${p.name}</button>`).join("") || `<div class="none">No match</div>`; };
    const open = v => { list.hidden = !v; name.setAttribute("aria-expanded", v); if (v) { q.value = ""; fill(); q.focus(); items.querySelector(".sel")?.scrollIntoView({ block: "center" }); } };
    let x0 = null, swiped = false;
    name.addEventListener("pointerdown", e => { x0 = e.clientX; swiped = false; });
    name.addEventListener("pointerup", e => { if (x0 != null && Math.abs(e.clientX - x0) > 40) { swiped = true; selectPreset(cur + (e.clientX < x0 ? 1 : -1)); } x0 = null; });
    name.addEventListener("click", () => { if (!swiped) open(list.hidden); });
    bar.querySelectorAll(".pstep").forEach(b => b.onclick = () => selectPreset(cur + +b.dataset.step));
    q.oninput = fill;
    q.onkeydown = e => { if (e.key === "Enter") { const b = items.querySelector("button"); if (b) { selectPreset(+b.dataset.i); open(false); } } if (e.key === "Escape") open(false); };
    items.onclick = e => { const b = e.target.closest("[data-i]"); if (b) { selectPreset(+b.dataset.i); open(false); } };
    document.addEventListener("pointerdown", e => { if (!list.hidden && !e.target.closest(".psel")) open(false); });
    document.addEventListener("keydown", e => {
      if (e.target.closest && e.target.closest("input,select,textarea,.knob")) return;
      if (e.key === "[" || e.key === "PageUp") selectPreset(cur - 1);
      else if (e.key === "]" || e.key === "PageDown") selectPreset(cur + 1);
      else if (/^[1-5]$/.test(e.key) && !e.metaKey && !e.ctrlKey) location.href = VIEWS[+e.key - 1][0];
    });
    paintBar();
  }
  function paintBar() { if (!bar) return; bar.querySelector(".pnum").textContent = PRESETS[cur].num; bar.querySelector(".pnm").textContent = PRESETS[cur].name; }

  window.PA = { FX, byId, cellOf, fmt, styleName, img, artHTML, color, set, setStyle, setState, nextState, hasHit, knob, initKnobs, drawKnob, press, nav, emit,
    vocal: FX.filter(f => f.side === "vocal"), guitar: FX.filter(f => f.side === "guitar"),
    PRESETS, selectPreset, get preset() { return preset(); } };
})();
