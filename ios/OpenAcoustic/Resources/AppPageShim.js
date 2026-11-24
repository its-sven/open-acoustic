// Page tweaks for the Open Acoustic iOS app, injected at document end. The web files themselves stay as
// upstream ships them; this only adapts them to a full-screen app:
//   - page size like a browser's zoom: the page is laid out for (view width ÷ zoom) CSS pixels and scaled
//     to fit, so it reflows and fills the screen at any size (window.__oaZoom, set by the app)
//   - no pinch or double-tap zoom (the pages are laid out for the screen; zoom on stage only gets in the way)
//   - no long-press callout (link preview / copy menu) on controls
//   - the LCD font "Silkscreen" from the app bundle, so pa-remote.html looks right offline
(() => {
  "use strict";
  const head = document.head || document.documentElement;
  if (!head) return;
  let vp = document.querySelector('meta[name="viewport"]');
  if (!vp) { vp = document.createElement("meta"); vp.name = "viewport"; vp.content = "width=device-width, initial-scale=1"; head.appendChild(vp); }
  const fit = /viewport-fit\s*=\s*cover/.test(vp.content) ? ", viewport-fit=cover" : "";
  const deviceWidth = "width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1, user-scalable=no" + fit;

  // z: zoom (1 = 100 %); w: width of the web view in points, from the app (falls back to the page's own).
  window.__oaApplyZoom = (z, w) => {
    z = Number(z) > 0 ? Number(z) : 1;
    if (Math.abs(z - 1) < 0.001) { vp.content = deviceWidth; return; }
    if (!(w > 0)) { vp.content = deviceWidth; w = document.documentElement.clientWidth; }
    vp.content = `width=${Math.round(w / z)}, initial-scale=${z}, minimum-scale=${z}, maximum-scale=${z}, user-scalable=no${fit}`;
  };
  window.__oaApplyZoom(window.__oaZoom || 1);

  const style = document.createElement("style");
  style.id = "open-acoustic-app";
  style.textContent = `
@font-face { font-family: "Silkscreen"; src: url("/_app/Silkscreen-Regular.ttf") format("truetype"); font-display: swap; }
html { touch-action: manipulation; -webkit-text-size-adjust: 100%; }
body { -webkit-touch-callout: none; }
* { -webkit-tap-highlight-color: transparent; }`;
  head.appendChild(style);
})();
