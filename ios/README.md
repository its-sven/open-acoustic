# Open Acoustic for iPhone and iPad

A small native app that runs the open-acoustic web tools on iPhone and iPad, **fully offline**, with **Web MIDI (incl. SysEx) bridged to CoreMIDI**. No third-party "Web MIDI browser" app and no internet connection are needed.

- **Remote** (`tools/pa-remote.html`), **Touch Views** (`tools/views/`), the **simulated pedal** (`views/?sim`) and **Verify** (`tools/verify.html`), picked from a start screen
- USB-MIDI through a camera adapter, or **Bluetooth MIDI** (pairing screen built in, e.g. for a CME WIDI)
- Made for the stage: the screen stays on, full screen, portrait and landscape, no pinch or double-tap zoom, the MIDI link status always visible in the corner menu
- Universal (iPhone and iPad), iOS/iPadOS 15 or newer, no dependencies

> _**Unofficial** community project. Not affiliated with, endorsed by, or supported by TC‑Helicon / Music Tribe. "Play Acoustic", "Play Electric" and "TC‑Helicon" are trademarks of their respective owner, used here only descriptively. Use at your own risk._

> ### ⚠️ MIDI CTRL and FILTER
> The web tools **refuse** to change **MIDI CTRL (`0x278`)** and **FILTER (`0x27B`)**: either can make the pedal ignore USB SysEx after its next power-up, and there is no MIDI socket to undo it (only a factory reset, which erases your presets). The app runs the web files exactly as they are in `tools/`, protections included, and sends nothing to MIDI on its own.

## How it works

| Piece | Where | What it does |
|---|---|---|
| Bundling | `scripts/bundle-web.sh` (build phase) | Copies the HTML/JS/CSS from `../tools` into the app at **every build**. The files are not duplicated in the repository, so upstream changes to `tools/` ship with the next build. |
| Offline server | `Web/AppSchemeHandler.swift` | Serves the bundle over `app://open-acoustic/…` (not `file://`), so relative links, `localStorage`, scripts and `fetch` behave as on a web server. All `http(s)` requests are blocked. The one remote resource, the LCD web font on `pa-remote.html`, comes from the bundle instead (`Silkscreen`, SIL OFL 1.1). |
| Web MIDI | `Resources/WebMIDIShim.js` | `navigator.requestMIDIAccess({ sysex })` with `MIDIAccess`, `MIDIInput`, `MIDIOutput`, maps, `statechange` / `midimessage` events, `open()` / `close()`, `send(data, timestamp)`, `clear()`, following the W3C spec (and Chrome where the spec leaves room). Injected at document start into every frame. |
| Bridge | `Web/WebMIDIBridge.swift` | JS → Swift through `WKScriptMessageHandler(WithReply)`, Swift → JS through `evaluateJavaScript` (bytes as Base64, batched). Only the app's own pages get MIDI. |
| CoreMIDI | `MIDI/` | One client with a notify callback (hot-plug → `statechange`). Input via `MIDIInputPortCreateWithProtocol` (MIDI 1.0 UMP), turned back into MIDI 1.0 bytes and reassembled by `MIDI1StreamParser`: SysEx split over any number of packets, real-time bytes in between, running status. Output strictly in order: SysEx through `MIDISendSysex` (any size, paced by CoreMIDI), short messages as UMP via `MIDISendEventList`. |
| App | `App/` | SwiftUI start screen, the web screen with a small corner menu (Home, Reload, Bluetooth MIDI…, status dot), `CABTMIDICentralViewController` for Bluetooth pairing. |

The web files are not modified. `Resources/AppPageShim.js` only adds app-level tweaks at load time (no zoom, no long-press callout, the bundled font).

## Requirements

- A Mac with **Xcode 16 or newer** (the project uses folder-synchronized groups)
- An iPhone or iPad with **iOS/iPadOS 15** or newer
- An **Apple ID** (a free one is enough to run the app on your own devices)

## Hardware

- **USB:** Play Acoustic (mini-USB) → USB‑A to mini‑USB cable → Apple **Lightning to USB 3 Camera Adapter** (the one with a charging port) or a **USB‑C** adapter/hub → iPhone/iPad. Power the adapter if the device complains that the accessory needs too much power.
- **Bluetooth:** a USB-host Bluetooth MIDI adapter on the pedal's USB port (e.g. **CME WIDI Uhost**). Pair it in the app: corner menu or start screen ▸ **Bluetooth MIDI…** ▸ tap the adapter ▸ *Connected*. It then shows up as an ordinary MIDI port; the web tools detect it and switch to their Bluetooth timing.
- **Quit VoiceSupport** on any computer connected to the pedal at the same time.

## Build and install with a free Apple ID

1. **Xcode ▸ Settings ▸ Accounts** ▸ **+** ▸ Apple ID ▸ sign in. A **Personal Team** appears.
2. Signing is kept out of the repository. Copy the example config and fill in your team ID (shown in Xcode ▸ Settings ▸ Accounts, or on the Membership page at developer.apple.com) and a bundle ID of your own:
   ```bash
   cp ios/Config/Local.xcconfig.example ios/Config/Local.xcconfig
   ```
   ```
   DEVELOPMENT_TEAM = ABCDE12345
   OA_BUNDLE_ID = io.github.<your-github-user>.openacoustic
   ```
   `Local.xcconfig` is git-ignored. Don't set the team in the target's *Signing & Capabilities* tab: Xcode would write it into the project file.
3. Open `ios/OpenAcoustic.xcodeproj`, select the **OpenAcoustic** scheme and your device (connected by cable; the first time, tap **Trust** on the device).
4. On the device, turn on **Developer Mode**: Settings ▸ Privacy & Security ▸ Developer Mode ▸ on ▸ restart ▸ confirm. (The switch appears once Xcode has seen the device.)
5. **Run** (⌘R). The first launch is blocked until you trust the certificate: Settings ▸ General ▸ VPN & Device Management ▸ your Apple ID ▸ **Trust**.

### The 7-day limit
Apps signed with a free account expire after **7 days**; the app then won't start until you run it from Xcode again (your saved settings stay). A free account can have at most 3 such apps per device. To renew automatically without a Mac at hand, sideload the app with [SideStore](https://sidestore.io) or [AltStore](https://altstore.io) and let them refresh it in the background.

### With a paid Apple Developer account
- **TestFlight:** archive (Product ▸ Archive), upload to App Store Connect and invite testers. Builds run 90 days and need no cable.
- **AltStore PAL** (EU): distribute as a notarized alternative-marketplace app.
- Either way the app is signed for one year instead of seven days. Note the license of the web tools (below) before distributing builds to others.

## Tests

```bash
cd ios
xcodebuild test -project OpenAcoustic.xcodeproj -scheme OpenAcoustic -destination 'platform=iOS Simulator,name=iPad (A16)'
```

- `MIDI1StreamParserTests`, `UMPTests`: SysEx reassembly across packets, real-time bytes inside SysEx and between status and data, running status, broken and oversized messages, UMP ↔ MIDI 1.0 conversion, event-list walking.
- `WebMIDIBridgeTests`: the whole path in a real `WKWebView` (page JS → shim → Swift → CoreMIDI → virtual loopback → CoreMIDI → Swift → page), incl. a 3 kB SysEx round trip, `send()` validation and `statechange` on unplug.

iOS only lets apps with the *audio* background mode create virtual MIDI ports, so **Debug builds** carry `UIBackgroundModes = audio` (`Config/Info-Debug.plist`) for the loopback test. Release builds don't.

## Project layout

```
ios/
├── OpenAcoustic.xcodeproj      project (folder-synchronized: new files in the folders below are picked up)
├── Config/                      Base.xcconfig (shared), App.xcconfig, Tests.xcconfig, Local.xcconfig (yours, ignored)
├── scripts/bundle-web.sh        copies ../tools into the app at build time
├── OpenAcoustic/
│   ├── App/                     SwiftUI: start screen, web screen, Bluetooth pairing
│   ├── Web/                     WKWebView setup, app:// scheme handler, Web MIDI bridge
│   ├── MIDI/                    CoreMIDI client, MIDI 1.0 stream parser, UMP, ordered sender
│   └── Resources/               WebMIDIShim.js, AppPageShim.js, Fonts/ (Silkscreen, OFL)
└── OpenAcousticTests/
```

## License

The iOS code in this folder follows the license of the repository. The bundled font **Silkscreen** is © The Silkscreen Project Authors, licensed under the SIL Open Font License 1.1 (`OpenAcoustic/Resources/Fonts/OFL.txt`).
