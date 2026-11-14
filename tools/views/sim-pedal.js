// Simulated Play Acoustic for trying the views without the pedal: open any view with ?sim in the URL.
// It stands in for Web MIDI and answers like the firmware: identity, 22 set, 47 get, 45 preset name,
// 55 panel tunnel (echoes injected events; front ◀ ▶ step presets and send a Program Change).
(function () {
  const NAMES = ["Studio Vocal", "Warm Ballad", "Coffee House Duet", "Big Chorus", "Country Slap", "Octave Up", "Radio Verse", "Megaphone",
    "Tight Double", "Church Choir", "Tape Echo", "Robot Tune", "Shimmer Room", "Dry Talk", "Arena", "Bossa Nylon", "Campfire", "Spring Surf"];
  const P = NAMES.map(() => new Map()); let cur = 2;
  const M = window.PA_MENUS || {}, cells = [];
  for (const m of Object.values(M)) for (const p of m.pages) { if (p.control) cells.push(p.control); for (const c of (p.rows || []).flat()) if (c) cells.push(c); }
  const seed = (i, s) => { let x = (i * 9301 + s * 49297) % 233280; return x / 233280; };
  P.forEach((vals, i) => cells.forEach((c, k) => { const id = parseInt(c.param, 16);
    vals.set(id, c.label === "CONTROL" ? Math.floor(seed(i, k) * (c.max + 1.6)) % (c.max + 1) : Math.round(c.min + seed(i + 3, k) * (c.max - c.min))); }));
  const global = new Map([[0x2A8, 0]]);
  const GLOBAL_IDS = new Set([0x2A8]);
  const get = id => id === 0x2A4 ? cur + 1 : GLOBAL_IDS.has(id) ? global.get(id) : P[cur].get(id) ?? 0;
  const set = (id, v) => GLOBAL_IDS.has(id) ? global.set(id, v) : P[cur].set(id, v);
  const enc28 = v => { if (v < 0) v += (1 << 28); return [(v >> 21) & 0x7f, (v >> 14) & 0x7f, (v >> 7) & 0x7f, v & 0x7f]; };
  const dec28 = (p, o) => { let v = (p[o] << 21) | (p[o + 1] << 14) | (p[o + 2] << 7) | p[o + 3]; if (v >= (1 << 27)) v -= (1 << 28); return v; };
  const input = { id: "sim-in", name: "Play Acoustic (simulated)", state: "connected", onmidimessage: null };
  // replies arrive on a message channel, not setTimeout: background tabs throttle timers to 1 s
  const ch = new MessageChannel(); ch.port1.onmessage = e => input.onmidimessage && input.onmidimessage({ data: Uint8Array.from(e.data) });
  const reply = d => ch.port2.postMessage(d);
  const H = [0xF0, 0x00, 0x01, 0x38, 0x00, 0x70];
  let tunnel = false;
  const output = { id: "sim-out", name: "Play Acoustic (simulated)", state: "connected", send(d) {
    d = [...d];
    if (d[1] === 0x7E && d[3] === 0x06 && d[4] === 0x01) return reply([0xF0, 0x7E, 0x00, 0x06, 0x02, 0x00, 0x01, 0x38, 0x70, 0x00, 0x01, 0x04, 0x00, 0xF7]);
    if (d[3] !== 0x38) return;
    const cmd = d[6], id = (d[7] << 7) | d[8];
    if (cmd === 0x22) set(id, dec28(d, 9));
    if (cmd === 0x47) window.simPedal.reads++;
    if (cmd === 0x47) reply([...H, 0x22, d[7], d[8], ...enc28(get(id)), 0xF7]);
    if (cmd === 0x45) { const n = [...NAMES[cur]].map(c => c.charCodeAt(0)); while (n.length < 15) n.push(0); reply([...H, 0x20, 0, 0, 0, 0, ...n, 0, 0, 0, 0, 0, 0xF7]); }
    if (cmd === 0x55 && d[7] === 0x01) tunnel = true;
    if (cmd === 0x55 && d[7] === 0x02) { const v = dec28(d, 8);
      if (tunnel) reply([...H, 0x55, ...enc28(v), 0xF7]);
      const e1 = (v >> 8) & 0xFF, e2 = v & 0xFF;
      if (e2 === 0x00 && (e1 === 0x04 || e1 === 0x05)) { cur = (cur + (e1 === 0x04 ? 1 : NAMES.length - 1)) % NAMES.length; reply([0xC0, cur]); }
      if (e2 === 0x00 && e1 === 0x0B) global.set(0x2A8, global.get(0x2A8) ? 0 : 1);
    }
  } };
  // "use" the pedal yourself: window.simPedal.turn(0x0B9, -3) changes a value and echoes a knob event, like the unit
  window.simPedal = { reads: 0, turn(id, d) { set(id, get(id) + d); if (tunnel) reply([...H, 0x55, ...enc28(0xAE0001), 0xF7]); }, next() { cur = (cur + 1) % NAMES.length; reply([0xC0, cur]); }, get, P };
  navigator.requestMIDIAccess = async () => ({ inputs: new Map([[input.id, input]]), outputs: new Map([[output.id, output]]), onstatechange: null });
})();
