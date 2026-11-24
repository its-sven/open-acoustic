// Web MIDI API for the Open Acoustic iOS app, bridged to CoreMIDI.
// Injected by the app at document start into every frame. WebKit on iOS has no Web MIDI; this follows the
// W3C Web MIDI API (https://www.w3.org/TR/webmidi/) closely, and Chrome where the spec leaves room:
//   - navigator.requestMIDIAccess({ sysex }) → MIDIAccess { inputs, outputs, onstatechange, sysexEnabled }
//   - the inputs/outputs maps hold the ports that are present; an unplugged port turns "disconnected" and
//     leaves the maps, and the same MIDIPort object comes back if the device does
//   - MIDIInput: onmidimessage / "midimessage" events ({ data: Uint8Array, timeStamp }); listening opens it
//   - MIDIOutput: send(data, timestamp), clear(); sending opens it
//   - MIDIPort: id, name, manufacturer, version, type, state, connection, open(), close(), onstatechange
// Native side: window.webkit.messageHandlers.oaMIDIAccess (with reply) and .oaMIDI; the app calls back
// into window.__oaMIDI.
(() => {
  "use strict";
  const handlers = window.webkit && window.webkit.messageHandlers;
  if (!handlers || !handlers.oaMIDI || !handlers.oaMIDIAccess || window.__oaMIDI) return;
  const post = msg => { try { handlers.oaMIDI.postMessage(msg); } catch (e) { console.error("MIDI bridge:", e); } };
  const frameToken = Math.random().toString(36).slice(2) + Date.now().toString(36);

  // host clock (ms, from the app) → performance.now(): learned from each reply, then kept fixed
  let hostOffset = null;
  const toPerf = hostMs => hostOffset == null ? performance.now() : hostMs + hostOffset;
  const toHost = perfMs => hostOffset == null ? null : perfMs - hostOffset;

  // ── events ───────────────────────────────────────────────────────────────
  class MIDIMessageEvent extends Event {
    constructor(type, init = {}) { super(type, init); this._data = init.data || null; }
    get data() { return this._data; }
  }
  class MIDIConnectionEvent extends Event {
    constructor(type, init = {}) { super(type, init); this._port = init.port || null; }
    get port() { return this._port; }
  }
  // An "on<type>" attribute that behaves like a real event handler attribute.
  function handlerAttr(proto, type, onSet) {
    const key = Symbol("on" + type);
    Object.defineProperty(proto, "on" + type, {
      configurable: true, enumerable: true,
      get() { return this[key] ? this[key].fn : null; },
      set(fn) {
        if (this[key]) this.removeEventListener(type, this[key].wrap);
        this[key] = null;
        if (typeof fn === "function") {
          const wrap = e => fn.call(this, e);
          this[key] = { fn, wrap }; this.addEventListener(type, wrap);
          if (onSet) onSet.call(this);
        }
      }
    });
  }

  // ── ports ────────────────────────────────────────────────────────────────
  const priv = new WeakMap();   // port → { access }
  class MIDIPort extends EventTarget {
    constructor(info, access) {
      super();
      Object.defineProperties(this, {
        id: { value: info.id, enumerable: true }, type: { value: info.type, enumerable: true },
        name: { value: info.name, enumerable: true }, manufacturer: { value: info.manufacturer, enumerable: true },
        version: { value: info.version, enumerable: true }
      });
      this._state = "connected"; this._connection = "closed";
      priv.set(this, { access });
    }
    get state() { return this._state; }
    get connection() { return this._connection; }
    open() {
      if (this._connection === "closed") this._setConnection(this._state === "connected" ? "open" : "pending");
      return Promise.resolve(this);
    }
    close() {
      if (this._connection !== "closed") this._setConnection("closed");
      return Promise.resolve(this);
    }
    _setConnection(c) {
      if (c === this._connection) return;
      this._connection = c;
      if (this.type === "input") post({ op: c === "open" ? "open" : "close", port: this.id, frame: frameToken });
      this._fireState();
    }
    _setState(s) {
      if (s === this._state) return;
      this._state = s;
      // an open port waits ("pending") while its device is away and is open again when it returns
      if (s === "disconnected" && this._connection === "open") this._connection = "pending";
      else if (s === "connected" && this._connection === "pending") this._connection = "open";
      this._fireState();
    }
    _fireState() {
      const p = priv.get(this);
      this.dispatchEvent(new MIDIConnectionEvent("statechange", { port: this }));
      if (p.access) p.access.dispatchEvent(new MIDIConnectionEvent("statechange", { port: this }));
    }
  }
  handlerAttr(MIDIPort.prototype, "statechange");

  class MIDIInput extends MIDIPort {
    addEventListener(type, fn, opts) {
      super.addEventListener(type, fn, opts);
      if (type === "midimessage" && fn) this.open();   // like Chrome: listening opens the port
    }
  }
  handlerAttr(MIDIInput.prototype, "midimessage", function () { this.open(); });

  class MIDIOutput extends MIDIPort {
    send(data, timestamp) {
      const bytes = toBytes(data);
      const access = priv.get(this).access;
      validate(bytes, access ? access.sysexEnabled : false);
      if (this._state === "disconnected") throw new DOMException("The port is disconnected", "InvalidStateError");
      this.open();
      const at = timestamp && timestamp > performance.now() ? toHost(timestamp) : null;
      post({ op: "send", port: this.id, data: bytes, at });
    }
    clear() { post({ op: "clear", port: this.id }); }
  }

  function toBytes(data) {
    if (data == null || typeof data.length !== "number") throw new TypeError("MIDIOutput.send: data must be a sequence of bytes");
    const out = new Array(data.length);
    for (let i = 0; i < data.length; i++) {
      const v = Number(data[i]);
      if (!Number.isInteger(v) || v < 0 || v > 255) throw new TypeError(`MIDIOutput.send: ${data[i]} is not a byte`);
      out[i] = v;
    }
    return out;
  }
  // The spec requires complete, valid messages (no running status); SysEx only with sysex access.
  function validate(b, sysex) {
    const len = s => s >= 0xF8 ? 1 : s === 0xF1 || s === 0xF3 ? 2 : s === 0xF2 ? 3 : s === 0xF6 ? 1 : (s & 0xF0) === 0xC0 || (s & 0xF0) === 0xD0 ? 2 : s < 0xF0 ? 3 : 0;
    let i = 0;
    while (i < b.length) {
      const s = b[i];
      if (s < 0x80) throw new TypeError("MIDIOutput.send: running status is not allowed");
      if (s === 0xF0) {
        if (!sysex) throw new DOMException("System exclusive messages need sysex access", "InvalidAccessError");
        let j = i + 1;
        while (j < b.length && (b[j] < 0x80 || b[j] >= 0xF8)) j++;   // real-time bytes may sit inside a SysEx
        if (j >= b.length || b[j] !== 0xF7) throw new TypeError("MIDIOutput.send: SysEx must end with F7");
        i = j + 1; continue;
      }
      const n = len(s);
      if (!n) throw new TypeError(`MIDIOutput.send: ${s.toString(16)} is not a valid status byte`);
      for (let k = 1; k < n; k++) if (i + k >= b.length || b[i + k] >= 0x80) throw new TypeError("MIDIOutput.send: incomplete message");
      i += n;
    }
  }

  // ── access ───────────────────────────────────────────────────────────────
  class MIDIPortMap {
    constructor(ports) { this._m = new Map(ports.map(p => [p.id, p])); }
    get size() { return this._m.size; }
    get(id) { return this._m.get(id); }
    has(id) { return this._m.has(id); }
    keys() { return this._m.keys(); }
    values() { return this._m.values(); }
    entries() { return this._m.entries(); }
    forEach(cb, thisArg) { this._m.forEach((v, k) => cb.call(thisArg, v, k, this)); }
    [Symbol.iterator]() { return this._m.entries(); }
  }
  class MIDIInputMap extends MIDIPortMap {}
  class MIDIOutputMap extends MIDIPortMap {}

  const accesses = new Set();
  class MIDIAccess extends EventTarget {
    constructor(sysex) {
      super();
      this._ports = new Map();   // id → MIDIPort, including disconnected ones (so they come back as the same object)
      Object.defineProperty(this, "sysexEnabled", { value: !!sysex, enumerable: true });
    }
    get inputs() { return new MIDIInputMap([...this._ports.values()].filter(p => p.type === "input" && p.state === "connected")); }
    get outputs() { return new MIDIOutputMap([...this._ports.values()].filter(p => p.type === "output" && p.state === "connected")); }
    _update(list, quiet) {
      const seen = new Set();
      for (const info of list) {
        seen.add(info.id);
        const p = this._ports.get(info.id);
        if (!p) {
          const np = new (info.type === "input" ? MIDIInput : MIDIOutput)(info, this);
          this._ports.set(info.id, np);
          if (!quiet) np._fireState();
        } else p._setState("connected");
      }
      for (const p of this._ports.values()) if (!seen.has(p.id)) p._setState("disconnected");
    }
  }
  handlerAttr(MIDIAccess.prototype, "statechange");

  async function requestMIDIAccess(options) {
    const sysex = !!(options && options.sysex);
    const reply = await handlers.oaMIDIAccess.postMessage({ op: "requestAccess", sysex, frame: frameToken });
    if (!reply || reply.error) throw new DOMException(reply && reply.error || "MIDI is not available", "NotSupportedError");
    hostOffset = performance.now() - reply.now;
    const access = new MIDIAccess(sysex);
    access._update(reply.ports, true);
    accesses.add(access);
    return access;
  }

  // ── called by the app ────────────────────────────────────────────────────
  const b64 = s => { const bin = atob(s), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u; };
  window.__oaMIDI = {
    frame: frameToken,
    ports(list) { for (const a of accesses) a._update(list, false); },
    // batch: [[portId, hostMs, base64], …]
    deliver(batch) {
      for (const [id, hostMs, data] of batch) {
        const bytes = b64(data), ts = toPerf(hostMs);
        for (const a of accesses) {
          const p = a._ports.get(id);
          if (!p || p.connection !== "open" || p.type !== "input") continue;
          if ((bytes[0] === 0xF0) && !a.sysexEnabled) continue;
          const e = new MIDIMessageEvent("midimessage", { data: bytes.slice() });
          Object.defineProperty(e, "timeStamp", { value: ts });
          p.dispatchEvent(e);
        }
      }
    }
  };

  // Install like a native API: on Navigator.prototype, writable, so a page may still replace it
  // (the views' simulated pedal does).
  Object.defineProperty(Navigator.prototype, "requestMIDIAccess", { value: requestMIDIAccess, writable: true, configurable: true, enumerable: true });
  for (const [n, c] of Object.entries({ MIDIAccess, MIDIPort, MIDIInput, MIDIOutput, MIDIInputMap, MIDIOutputMap, MIDIMessageEvent, MIDIConnectionEvent }))
    if (!(n in window)) Object.defineProperty(window, n, { value: c, writable: true, configurable: true });
})();
