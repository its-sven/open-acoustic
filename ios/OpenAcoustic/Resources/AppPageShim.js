// Page tweaks for the Open Acoustic iOS app, injected at document end. The web files themselves stay as
// upstream ships them; this only adapts them to a full-screen app:
//   - no pinch or double-tap zoom (the pages are laid out for the screen; zoom on stage only gets in the way)
//   - no long-press callout (link preview / copy menu) on controls
//   - the LCD font "Silkscreen" from the app bundle, so pa-remote.html looks right offline
(() => {
  "use strict";
  const head = document.head || document.documentElement;
  if (!head) return;
  let vp = document.querySelector('meta[name="viewport"]');
  if (!vp) { vp = document.createElement("meta"); vp.name = "viewport"; vp.content = "width=device-width, initial-scale=1"; head.appendChild(vp); }
  if (!/user-scalable/.test(vp.content)) vp.content += ", maximum-scale=1, user-scalable=no";
  const style = document.createElement("style");
  style.id = "open-acoustic-app";
  style.textContent = `
@font-face { font-family: "Silkscreen"; src: url("/_app/Silkscreen-Regular.ttf") format("truetype"); font-display: swap; }
html { touch-action: manipulation; -webkit-text-size-adjust: 100%; }
body { -webkit-touch-callout: none; }
* { -webkit-tap-highlight-color: transparent; }`;
  head.appendChild(style);
})();
