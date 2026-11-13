# Play Acoustic firmware: analysis notes

Firmware 1.4.00 Build 51 unless noted. Reverse-engineered from the stock `.syx` images; the stock files in `stock/` are read-only recovery copies and match their `SHA256SUMS`.

> **Safety**
> - Never change **MIDI CTRL (0x278)** or **FILTER (0x27B)**: either can make the pedal ignore USB SysEx after the next power-up, and the Play Acoustic has no 5-pin MIDI socket to undo it (§16). `tools/pa-remote.html` refuses both.
> - **Factory reset** = hold **STORE + BACK** while powering on. It erases settings **and user presets/favorites** (§16).
> - Close **VoiceSupport** before using SysEx tools; while connected it corrupts incoming SysEx.
> - Flashing: see §5. The recovery path from a broken DSP image is untested.

**Status in one paragraph:** the firmware runs on a Freescale DSP56300-family DSP that holds the whole UI, menus, MIDI and SysEx; an Atmel AVR does USB. Live control works on the **stock** firmware through the built-in SysEx commands `22` (set parameter) and `47` (get parameter). The menu tables, parameter descriptors, value names, display images and FX-page layout are decoded, and `tools/pa-remote.html` mirrors the pedal's front panel from them. The earlier MIDI CC approach (a patched CC map) was abandoned because the AVR drops incoming CCs; it is archived in `legacy/cc-approach/`. What has and hasn't been tried on the unit: `tools/verify.html` and §19.

## Contents
- **Firmware files:** §1 decode correction · §2 container · §3 CPU · §4 section layout · §5 boot, update and flash safety · §6 build diffs · §7 provenance · §8 DSP vs AVR
- **Tools:** §9 disassembly · §10 emulation · §11 REA notes
- **Control:** §12 the oddeyez editor · §13 SysEx live control · §14 parameters · §15 current preset · §16 USB lock-out and factory reset
- **Menus and display:** §17 menu tables · §18 display graphics and FX pages
- **Hardware log:** §19 confirmed on the unit
- **Legacy:** MIDI CC approach → `legacy/cc-approach/README.md`; first-pass decode → `legacy/v1/`

# Firmware files

## 1. Decode correction: the v1 `PA-*.unpacked.bin` files are wrong
`legacy/v1/PA-*.unpacked.bin` (v1) mis-decoded the payload in two ways:
1. **Alignment.** Each 0x52 payload starts with a **1-byte subcommand** (`00` data, `02` section separator, `01` end). It comes *before* the 8-in-7 groups. v1 treated it as a flag byte, so every group was shifted by one byte.
2. **Bit order.** The flag byte is **MSB-first**: flag bit `6-k` supplies bit 7 of data byte `k`. v1 used LSB-first.

Proof: with the v2 decode, `ff 7f` drops from 896 occurrences to 1, `7f 7f` and `80 80` drop to 0, `ROCKABILLY SLAP` decodes cleanly, and entropy falls from 5.88 to 5.51 bits/byte.
The decoder is `tools/tch_unpack.py` in this folder. Leave the v1 files in place for history, but don't use them.

## 2. Container format (all 7 images)
```
F0 00 01 38 00 60 51 00 F7            bootloader enter        (x2)
F0 00 01 38 00 60 52 02 <27 zero> F7  section separator
F0 00 01 38 00 60 52 00 <packed> F7   data (sec0: 1 msg)
F0 00 01 38 00 60 52 02 ... F7        separator
F0 00 01 38 00 60 52 00 <packed> F7   data (sec1: ~2,238 msgs)
F0 00 01 38 00 60 52 02 ... F7        separator
F0 00 01 38 00 60 52 01 F7            end
```
This gives two sections per image: `*.sec0.bin` (981 B for PA, 984 B for PE) and `*.sec1.bin` (the main image, 914–980 KB).

## 3. CPU: Motorola/Freescale DSP56300 family (24-bit, big-endian)
This is not ARM, Blackfin or SHARC. The evidence comes from opcodes at 3-byte word alignment:
- `0A F0 80 aaaaaa` = `JMP` to an absolute address; `0B F0 80 aaaaaa` = `JSR` to an absolute address.
- `00 00 0C` = `RTS`.
- `44 F4 00 iiiiii` = `MOVE #imm,X0`; the `0C`/`0D` short-form jumps and calls also appear.

The opcode density in code blocks is 8–46 hits/kB at a single 3-byte phase, versus about 0 in data blocks.
TC Electronic has a long history with DSP56k parts. The exact part number (DSP56371/56374/56720…) is not determined. A board photo or the PCB silkscreen would settle it.

## 4. Section layout (1.4.00 Build 51)

### sec0: second-stage loader (identical in every PA build: sha256 prefix `d2ea11d5…`)
This is DSP56300 bootstrap format: `count=0x000145` (325 words), `load=P:0x000000`, then 325 × 24-bit words, for 981 B exactly.
It is a small loader that the bootloader runs first. It then receives sec1 and presumably writes it to flash.

### sec1: main image (968,910 B)
| sec1 offset | kind | notes |
|---|---|---|
| 0x000000 | record header | `count=0x0076F1` (30,449 words), `load=P:0x000000` |
| 0x000006–0x0164D9 | **CODE: internal P-RAM program** | vector table at P:0 (`JMP 0xCB` …); dense code |
| 0x0164D9 | record | `count=12`, `load=P:0x37C5` (patch or overlay record) |
| 0x016503– | **records in a different format** | the simple [count, addr] chain stops here; code calls `JSR 0x40FFFD` / `JMP 0x40xxxx`, i.e. code that runs from external memory at about P:0x400000 |
| ~0x016500–0x046000 | CODE | external-memory code (overlays / slow-path code) |
| 0x044000–0x04C000 | DATA (zero-heavy) | low-entropy tables/padding (the old v1 offsets 0x46000–0x4A000) |
| 0x04C000–0x058000 | DATA (printable-looking bytes) | about 55% bytes in the 0x20–0x7E range, but **not text**; likely bitmap/font or 7-bit coefficient tables |
| 0x058000–0x070000 | CODE | |
| 0x070000–0x078000 | DATA | |
| 0x07C000–0x088000 | CODE | |
| 0x088000–0x0C8000 | DATA | mixed tables, zero-heavy (likely DSP coefficient / IR / parameter tables) |
| 0x0C8000–0x0E4000 | CODE | |
| 0x0E2xxx–end | **DATA: factory presets** | preset name table (`ROCKABILLY SLAP` at sec1 offset 0xE255A) plus parameter records |

Region boundaries are 16 KiB-granular (from `tools/exploration/codemap.py`). The best-scoring 3-byte alignment changes between regions, which shows they are separate records with their own headers. The header format after 0x016503 is defined by the sec0 loader. It was resolved later with the real disassembler: see "Boot path" below.

### Boot path: the AVR boots the DSP over the host port
- `sec0` (325 words at P:0) is a **HI08 host-port loader**. Each word arrives via `M_HRX` and is acknowledged on `M_HTX`. The host is the AVR co-processor. The DSP has no firmware storage of its own: the AVR streams the image into it at power-up.
- Record format of `sec1` (corrects the table above): `[count][addr][type]` + `count` words. Type 0 goes to `P:addr` if `addr < 0x10000`, else to `X:addr`. Type 4 means jump to `addr`. `tools/hi08_records.py` walks it: 12 records, then start at **P:0x00CB**.

| rec | load addr | words | content |
|---|---|---|---|
| 0 | P:000000 | 30,449 | internal program (vectors, ISRs, ESAI audio I/O, DSP kernels) |
| 1 | X:031600 | 14,277 | internal X data |
| 2 | X:400000 | 8,565 | external code |
| 3 | X:40C000 | 130,742 | external code (main app, C runtime) |
| 4–8 | X:42BEB9… | small | data |
| 9 | X:42C560 | 55,959 | initialised data/strings (run address = load + **0x2A8CC**) |
| 10 | X:43A000 | 257 | data |
| 11 | X:43A180 | 80,980 | external code (UI, MIDI, SysEx) |

External RAM is unified (code runs at P:0x40xxxx–0x44xxxx). Strings are referenced at their relocated address (load + 0x2A8CC, which is 197 statistical hits; confirmed by the assert call below).


## 5. Boot, update and flash safety
### How boot and update actually work
- **Normal power-up (no AVR involvement in loading):** the DSP boot ROM (mask ROM) boots from a byte-wide **AMD/JEDEC parallel NOR flash at X:$C00000**. The first record (P:0, 0x1BB words) contains a flash loader (P:$7D–$AB) that copies the remaining `[count][addr][words]` records into P/X RAM, then jumps to the application (P:$1AF → main). **No checksum or signature is checked.**
- **Update** (oddeyez `firmware.js` + DSP code):
  1. Host sends the raw `…60 51` message, and the device enters "bootloader mode", answering on device-ID `0x60`.
  2. Per block: header `60 7E <7-bit sum> <size>`, then the block, then `60 7D`; the device acks `60 7F 01` (00 = retry). The checksum covers **transfer only** and is computed by the sender from the file.
  3. The blocks boot the DSP over the HI08 host port: `sec0` (325-word HI08 loader, shipped in every file), then the `sec1` records into RAM, then start at P:$CB.
  4. The **DSP-resident flash writer** (P:$4161DB) runs:
     - patches P:$1AE→$1AF so the flashed copy boots the app;
     - checks the flash ID (`01/F6`, AMD/Spansion; command `90`);
     - streams the sections in the table at P:$416204 to the NOR as 3 bytes per word. Each 64 KB sector is erased when a write reaches its boundary (`80…`), each byte is programmed with `A0` and data-poll verified, and writes are refused at or above $1F0000 (signed);
     - reports `0x800001` (start) and `0x800003` (done) to the host over HI08, then halts. The device reboots and answers identity.

### Generic flashing risk (same as any official update)
- Interrupting the transfer or the flash write (USB unplug, power loss, host sleep) leaves the NOR partly erased. The DSP then cannot boot.

### Recovery path and its key assumption
- **What the update path depends on:** AVR firmware (never part of any update image), the DSP mask boot ROM (HI08 host boot) and `sec0` (sent from the file). **None of these is stored in the NOR sectors being rewritten.** So a broken DSP image should be recoverable by flashing a stock `.syx` again.
- **Key assumption (unproven on hardware):** the AVR enters bootloader mode on `…60 51` by itself, without the DSP application.
  - *For:* the update starts with the host booting the DSP over HI08, which needs host control of DSP reset and boot mode (the AVR). The DSP app has no `0x51`/`0x60` handling, and its SysEx filter (`func_449801`) matches `00 01 38 <ch|7F> <own product|7F>`. The bootloader answers as device-ID 0x60 "regardless of product" (editor comment), consistent with an AVR-level bootloader shared by PA and PE.
  - *Unknown:* the AVR firmware isn't available to inspect, and nobody has tested recovery from a dead DSP image.
- **Factory reset** (hold STORE + BACK at power-on, §16) resets user data via the DSP app. It is **not** a firmware recovery and won't help if the DSP image is broken.
- **Last resort if the assumption fails:** hardware. Reprogram the NOR (byte-wide, AMD command set) with a programmer, or load via the DSP's OnCE/JTAG port. This means opening the unit.
- **Done on this unit:** flashing with TC VoiceSupport (patched CCtest1, then stock 1.4.00 again) worked both times. A failed flash and its recovery have not been tested.

## 6. Section-aware diff across PA builds
P-RAM program record (`rec0`), compared word by word (24-bit) with `tools/exploration/secdiff.py`:

| step | rec0 words | identical words | changed hunks |
|---|---|---|---|
| 1.0.04 → 1.1.00 | 30,364 → 30,345 | 98.3% | 462 |
| 1.1.00 → 1.2.00 | 30,345 → 30,345 | 98.9% | 309 |
| 1.2.00 → 1.3.00 | 30,345 → 30,449 | 97.3% | 496 |
| 1.3.00 → 1.4.00 | 30,449 → 30,449 | 98.9% | 330 |

Almost all hunks are single-word replacements at the same offsets, such as P:0x4, P:0x6, P:0x38 and P:0x1AF. That is the pattern of relinked absolute jump/call targets, with only small real code changes in internal P-RAM. This **overturns** the v1 note that builds share only about 1 KB: that result came from the broken unpack.

External remainder (after rec0), measured by 48-byte chunk carry-over (a lower bound, because relocation breaks chunks):
- 1.0.04 → 1.1.00: 66.9% carried over
- **1.1.00 → 1.2.00: 49.0%**. This is the biggest release: +45 KB, with new blocks around rest offsets 0x0CBA00, 0x08F910 and 0x034F50. It lines up with the manifest's large feature drop in 1.2.
- 1.2.00 → 1.3.00: 68.4%
- 1.3.00 → 1.4.00: 68.5%. The largest new runs are at rest offsets 0x035100 (37 KB) and 0x091470 (31 KB).

## 7. Provenance: official server vs oddeyez.se
- `firmware/official/` (from `https://www.tchelicon.com/VoiceSupport2/Firmware/<Product>/<file>.syx`): PA 1.2.00 and PA 1.3.00 are **byte-identical** (same SHA-256) to the oddeyez.se copies.
- Probing the same URL pattern on the official server: **PA 1.2.00, PA 1.3.00 and PE 1.2.00 return HTTP 200**. PA 1.0.04, PA 1.1.00, **PA 1.4.00** and **PE 1.3.00** return 403 (not present).
- 1.0.04 and 1.1.00 look like superseded official builds, internally consistent with later ones.
- PA 1.4.00 / PE 1.3.00 are not on the VoiceSupport2 path, and a web search found no public release notes for them. Internally they look like genuine TC-Helicon builds:
  - The sec0 loader is identical to the official builds.
  - 98.9% of the P-RAM program is shared with 1.3.00.
  - The change set is small and coherent: +9 strings, namely `MIDI CC 102`…`107` (matching the manifest note), plus undocumented `DAW TRACKING` and `SLV.MODE`.
  - They were compiled from a **different build path**: `C:\Projects\PlayAcoustic\…` and `Y:\Project\PlayElectric\…`, where every earlier build uses `D:\Project\…`. That points to a later rebuild on a different machine or by a different engineer.
- The format has **no signature or authenticity check**, only a 7-bit checksum, so authenticity can't be proven from the bytes. Treat 1.4.00 / PE 1.3.00 as **unverified, probably genuine late or limited releases**.

## 8. The DSP holds the UI/MIDI layer; an Atmel AVR does USB
- The DSP stores code-side strings **one character per 24-bit word** (`00 00 'A' 00 00 'B' …`), so a plain ASCII grep misses them. There are about 1,360 such strings in `data/strings-1.4.00-24bit.txt`.
- They include menu text (`GLOBAL`, `SETUP`, `MIDI`, `SWITCH`, `BODYREZ`, `MP-76`, `CONTRAST`, `Tuner`), display fonts (`Font_ArialBlack7`, `Font_Impact19`, …), printf-style formats (`USER #%d:  %s`) and module names (`WaveToMidi`, `ChordDetect`, `InterCoreWrite`/`InterCoreRead`). The inter-core names suggest a dual-core DSP, such as the DSP5672x "Symphony" parts. **So the menus, display, MIDI mapping and preset logic run on the DSP**, consistent with the release notes delivering UI changes only through these files.
- `AVR Version: %d.%d` and `VERSION:%s… AVR:%d` show an **Atmel AVR co-processor**. With `USB CONNECTION PROBLEM` and `Utility Usb_Sense`, it is most likely the USB interface (and possibly the knob/button scanning). The DSP only *reads* its version.
- **No AVR firmware is embedded in any of the 7 images.** Searches for vector tables, `RET`, `RJMP` tables and Intel HEX came up empty in raw, 1-byte-per-word and 2-bytes-per-word packings. There are no reflash strings either. The AVR appears to be factory-programmed and never field-updated.
- The AVR forwards SysEx to the DSP but **drops incoming channel messages** (CC, Program Change), so live control has to use SysEx (§13; details in `legacy/cc-approach/README.md` §8).
- **VoiceSupport must be closed:** while it is running and connected, incoming SysEx is lost ("SYSEX SETUP REJECTED: PACKAGES LOST OR OUT OF SYNC").

# Tools

## 9. Disassembly (dsp56300 disassembler from the gearmulator project, GPLv3)
Tool: `github.com/dsp56300/dsp56300` @ 8b73196, target `dsp56kDisassemble`, built locally (CMake/clang). Listings of every record are in `disasm/1.4.00/` (`r00_P_000000.asm` … `r11_X_43a180.asm`, `sec0_loader.asm`, `strings_addr.txt`). The MIDI/UI/SysEx code is in record 11 (P:443000–44A400 for MIDI; source file names `MIDIhand.c`, `MIDIEXCL.C`).

## 10. Emulation
Harness `tools/emulator/emu_harness.cpp` links the dsp56300 emulator library: `Memory(P=16M words, XY bridged to P from $400000)`, `Peripherals56362` plus `Peripherals56367` (second ESAI). It loads the 12 records and runs the **interpreter** (the JIT crashed on the first instruction with this memory layout). The run is reproducible: `INTERP=1 ./harness <recdir> 60`. Changes needed to get past start-up:
1. **Flash-writer vs normal boot.** Entry P:$00CB jumps to `func_4161db`, which streams every section out over bit-banged Port C (into serial flash) and patches P:$1AE to $1AF so the *flashed* copy takes the normal path. The harness applies that one-word patch: `mem.set(P,0x1ae,0x1af)`.
2. Y:$FFFFE5 bit 23 (external ready) reads as set.
3. **Second-core handshake** at P:$40CA86–$40CAFE: the DSP pushes code blocks for the other core through X:$3C000 and polls Y:$FFFFD1. Modelled as: `0x5A0` while Y:$FFFFD0 bit 23 is set, `0xA5A5A` in the final wait, `0` otherwise. The second core itself is **not** emulated. The UI/MIDI code runs on this core.
4. ESAI clock disabled (otherwise audio interrupts starve the main code).

After 60M instructions the RAM dumps in `emulation/1.4.00/ram_X_*.bin` hold the initialised tables used throughout this document (parameter map and descriptors, menu tables, value lists). Run log: `emulation/1.4.00/run-stock-60M.txt`.

## 11. What REA could and couldn't do here
- **Worked:** `inspect_byte_entropy` gave the entropy maps (evidence `ev_04374fa9…` for the v1 bin and `ev_98b24edd…` for the v2 sec1).
- **Unavailable on this Mac:** `execute_rizin_command` and `inspect_firmware_regions`. The first needs `rizin` on PATH (ENOENT). Binwalk/unblob in REA are Linux-only.
- **Not applicable even if installed:** neither Rizin nor Ghidra ships a DSP56300 processor module. `open_binary` with `raw-binary` therefore can't disassemble this ISA. Next step for real disassembly: a third-party DSP56k module for Ghidra, or the Motorola `dsp56300` disassembler/`asm56300` toolchain, run on sec0 (325 words, the loader) first to learn the record format.

# Control

## 12. How the oddeyez.se editor (v0.7.2) controls the device
From its readable JS (`midi-client.js`, `tch-format.js`, `param-defs.js`; main page script):
- **There is no per-parameter message.** The editor changes the device only through bulk SysEx writes, each waiting for an ACK:
  - **Setup (global) block:** `F0 00 01 38 00 <pid 70/71> 13 01 2A <chunk 0-6> <25 params x 4 bytes (encode28)> <sum&7F> F7`. That is 7 packets of 112 B. Even one setting (e.g. looper input = packet 1, byte 41, via `sendSetupByte`) re-sends **all 7 packets**.
  - **Preset:** `buildPresetSysex` sends a full preset (header + 5 packets). "Live" mode overwrites one **Live Slot** with each song's preset ("the preset data changes underneath it").
- The "FX automation" boxes (learnable CC, e.g. CC20-23) are computed in the browser and sent as Setup writes. The defaults toggle only global guitar FX on/off (`gtr-delay`, `gtr-reverb`, `gtr-umod`).
- Device-originated CCs: CC28 (HIT toggle), CC32 (bank LSB on preset change), and CC102-107 from Switch-3/6 (1.4.00 feature).
- Consequence: the stock firmware gives *switch-like* control (preset swap, setup toggles), **not continuous knob-style parameter control**. A continuous sweep would mean re-sending about 784 B (setup) or a full preset per step, plus an ACK. Update rate and audible artefacts are untested.

## 13. Built-in SysEx live control (stock firmware)
The stock firmware **already has a "set parameter" SysEx command** (found while designing a patch for one).
- **SysEx command table:** 18 entries `{cmd, payload length, handler}`, run X:7EBFF5, count at X:7EC02C. In the image it sits in rec9 at load X:439F50. Commands: 54, 7E, 20, 21, 45, 13 (setup packet), 15 (request setup), **22**, **47**, 51, 31 (no-op), 55 (front-panel event tunnel), 53, 46, 50, 57 (sync), 7A, 58.
- **0x22 = set parameter** (handler P:449760 → `func_448f85`): payload `p1 p0 v3 v2 v1 v0`, with param = `p1<<7 | p0` and value = 28-bit (`v3<<21|v2<<14|v1<<7|v0`, two's complement as in the editor's `encode28`). It calls the central setter `func_005137(param, value, flags=3)` unless descriptor word 11 is non-zero.
- **0x47 = get parameter** (handler P:449779): payload `p1 p0`. The device replies `F0 00 01 38 <ch> 70 22 p1 p0 v3 v2 v1 v0 F7` (`func_448f6d`).
- **Full messages:** set = `F0 00 01 38 <ch> 70 22 p1 p0 v3 v2 v1 v0 F7`; get = `F0 00 01 38 <ch> 70 47 p1 p0 F7`. `<ch>` comes from the universal identity reply; `70` = Play Acoustic, `71` = Play Electric.
- **Coverage:** 698 of 704 parameter IDs are settable. Blocked (word 11 ≠ 0): 0x95–0x98 (MAP IN/OUT), 0x26D, 0x26E.
- **Full SysEx reference:** `docs/SYSEX.md`.
- **Tool:** `tools/pa-remote.html` (Play Acoustic Remote), "Live parameter control" panel (pick by name, read value, slider, sweep).
- Side finding: the section P/X:4163BA–41D4D8 contains an **embedded SysEx update stream** (same `00 01 38 00 60 52` framing, 3 bytes per word, about 87 KB). It is likely the image for another processor (second DSP core or the AVR). Not yet analysed.

### Hardware results
- **Confirmed on stock 1.4.00:** set/get works live in both directions for **HIT (0x2A8)** and **LOOP LEVEL (0x2AC)**. The pedal screen updates instantly, with no SysEx pop-up.
- 0x283 "GUITAR" is the **Setup** page value (Setup page 1: INPUT 0x272, ROOMSENSE 0x2A7, TONE STYLE 0x2A9, GUITAR 0x283, PITCH CORRECTION 0x270), not the Mix guitar level.
- **UI page table** at rec9 load X:436F85 (run +0x3B20FB): entries `{title string, page-data pointer, …}` for PRACTICE, Tuner, Effects, EffectsAdvanced, Guitar, GuitarAdvanced (×2), Home, Mixer (×3 pages), Setup, Splash, FrontTest, SetKey, Looper, Genre, Store, practice, Tuner. Each page lists items of 18 words with the parameter IDs per soft-button slot (`0x3B4` = empty).
- **Mixer page parameters:** 0x0BB, 0x0BE, 0x0BC, 0x0BF, 0x0BD (LEVEL, −36…0), 0x0C1, 0x0C0 (−36…+6), 0x2AC LOOP LEVEL, 0x275 AUX (page 2 shows 0x276 instead of AUX). The guitar mix level is one of the LEVEL entries; which one is to be identified on hardware.

Full SysEx reference: `docs/SYSEX.md`.

## 14. Parameters
- **Descriptor lookup** (from `func_442bb9`): `desc = X:7E91F3 + 16*(X:7E85F1[id] & 0xFFFF)`. Fields: [0] index, [1] **min**, [2] **max**, [4] **default** (matches the factory values seen on the unit), [5] image set for style parameters, [6] group/display type (unconfirmed), [8] **pointer to the on-screen name**, [11] non-zero = not settable via SysEx, [12] value-format code, [14] instance-label list. `data/params-1.4.00.csv` lists all 948 IDs (0x000–0x3B3) with display name, range, default, settable flag, format and value names. Names are display labels and repeat (e.g. "LEVEL" per voice/effect block), so neighbouring IDs give the context.
- **Physical controls (manual, 2014-07-16):** the Play Acoustic has **one Control knob** (an encoder that edits whichever parameter is selected via soft buttons/arrows) and a **Mic Gain** knob (analog preamp; not a firmware parameter). There are no per-parameter knobs. So "control like the knobs" means: reach any parameter the Control knob can edit, i.e. this list.
- **Same path as the UI:** `func_005137(param, value, flags)` is the central setter, with about 60 call sites across app and UI code. It writes the live value array X:7E2FB6[param], clamps to descriptor min/max, and if the value changed, notifies display, DSP and MIDI-out. The CC handler calls it with flags=0 (full notification), so a CC-mapped parameter behaves like a Control-knob edit.

### Naming from the menu tables
- The parameter map word `X:7E85F1[id]` = `(instance << 16) | descriptor_index`. Many IDs share one descriptor and differ only by instance. Example: 0x0B9–0x0BF are all descriptor 0x6F "LEVEL", instances 14–20 (mixer channels). So the descriptor name alone can't distinguish them.
- **Menu tables:** the top-level page list (rec9 load X:436F85) → page data (8-word sub-page entries `{title, item list, …}`) → item lists (18 words = 3 rows × `{row, 0, param L, param R, …}`; `0x3B4` = empty). Sub-page titles give context ("GUITAR REVERB", "BODYREZ EQ", "HARMONY", "MIX", "HOME", "INPUT", …).
- `data/ui-map-1.4.00.csv`: every parameter reachable from the menus, with page, sub-page title, row/column (soft-button position), name, range and instance. 135 placements, 89 distinct parameters.
- **Mixer channels** (identified on screen by icons, not text): page 1 = 0x0BB **GUITAR (confirmed on hardware)** | 0x0BE; LOOP LEVEL 0x2AC; AUX 0x275 (or ROOMSENSE 0x276, depending on input mode) | 0x0BC. Page 2 = 0x0BF | 0x0C1, 0x0BD | 0x0C0. HOME shows 0x0BB, 0x0BE and LOOP LEVEL, so 0x0BE is very likely the vocal level (unverified).
- Parameters not on any menu (about 600) are preset internals (per-voice and per-block). They can be grouped by descriptor and instance, but naming each instance needs the block/voice layout; not yet done.

### Display labels for shared parameters
- **How the display labels instance parameters** (`func_4459b2`, `func_44716e`): `n = descriptor word 14`; list = `X:(7E91C3 + 2n)` (pairs `{list pointer, count}`); label = string at `X:(list + 3·instance)`; shown as "<instance label> <parameter name>".
  - LEVEL descriptor 0x6F (21 instances, list X:7E911E): 0x0BB GUITAR, 0x0BC OUT, 0x0BD USB OUT, 0x0BE HEADPHONE, 0x0BF USB IN, plus the send levels 0x0AB… LEAD/HARM/UMOD/DELAY TO …
  - Descriptor 0x70 (list X:7E91A5): 0x0C0 DELAY/REVERB, 0x0C1 HARMONY.
- `data/params-1.4.00.csv` carries `display_name`, `instance_label`, `descriptor` and `instance` for every ID.
- **Cross-reference with the official User Manual V1.0** (PDF M_TH_0726-AAI): `docs/MENUS.md`. Every V1.0 Mix control maps to a firmware parameter. Firmware 1.4 differences that match the release notes:
  - Guitar Anti-Feedback moved to Setup (1.2.00).
  - Guitar Delay added (1.2.00).
  - LOOP LEVEL added to Mix page 1, pushing Harmony and Delay/Reverb to page 2.

### Full ID range, value names and formats
- The parameter map `X:7E85F1[id]` has 0x3B4 entries (IDs 0x000–0x3B3); it ends where the CC map starts (X:7E89A5). IDs 0x2C0–0x3B3 are mostly global/system settings: HEADPHONE LIM 0x312, VOCAL CANCEL 0x317, GUITAR GATE 0x329, MIC BOOST 0x352, ROOMSENSE LOCUT 0x35A, BODYREZ EDITING 0x362, PHASE INVERT 0x347, LOW CUT 0x348, GUITAR BOOST AMT 0x349, FOOTSWITCH 0x39F, SWITCH-6 MODE 0x3A0, SWITCH 1–3 0x393–0x395 (Switch-3), SWITCH 1–6 0x3A7–0x3AC (Switch-6), MP76 CONTROL/TOP/BOTTOM/LEFT/RIGHT 0x39A/0x39E/0x39C/0x39D/0x39B.
- Settable gate (descriptor word 11 = 0) passes for all of these; 79 IDs are blocked in total (0x95–0x98, 0x26D–0x26E, 0x2D2–0x2EA, 0x304–0x30B, 0x36C–0x392, 0x3B3). SysEx 0x22/0x47 on the new IDs is unverified on hardware.
- Descriptor word 12 = value-format code. Codes below 0x36 index the value-name pointer table at X:457795 (e.g. 0x13 input types, 0x1A output modes, 0x2E footswitch functions, 0x30 SWITCH-3/SWITCH-6). Codes seen for numbers: 0x54/0x55/0x42 dB, 0x36 %, 0x41 Hz ×2 (TUNE REFERENCE 880 = 440.0 Hz), 0x5F/0x60 frequency tables (not decoded).
- Menu page variants: entries with the same title are alternatives the UI picks between. Mix is chosen in `func_442f62`: AUX page (X:7E8F6A) when a cable is in AUX IN (`Utility Aux_In_Sense` 0x295 = 1), else the ROOMSENSE page (7E8F7A), or the page with neither (7E8F8A) when ROOMSENSE 0x2A7 = 2. Confirmed on the unit: no aux cable → ROOMSENSE. Setup uses FOOTSWITCH 0x39F. Guitar FX shows the 4 basic pages, or the 7 pages from the GuitarAdvanced block when BODYREZ EDITING 0x362 = ADVANCED. The *Advanced* item lists for Harmony, Delay, Transducer, Guitar Reverb, Delay and uMod are overlay pages; how the unit shows them is not yet known.
- Verified against photos of the unit: preset screen, Mix 1/2 and 2/2, all 10 Setup pages. Vocal FX and Guitar FX pages not yet compared.
- `tools/menu_dump.py` → `data/menus-1.4.00.json` (raw). The remote's editable layout is `tools/pa-menus.js` (format: `tools/MENUS-FORMAT.md`).

### Effect on/off: CONTROL parameters
- **CONTROL** = per-effect on/off with HIT option. Vocal (OFF/ON/HIT): 0x2CB uMOD, 0x2CC Delay, 0x2CD Reverb, 0x2CE Harmony, 0x2CF Double, 0x2D0 Transducer, 0x2D1 HardTune; each is copied to the effect's live enable (0x2C3–0x2CA) by the code at P:443F86. Guitar (OFF/ON): 0x353 Reverb, 0x355 Delay, 0x357 uMOD (0x354/0x356/0x358 are second instances, purpose unknown); 0x359 = guitar boost, 0x347 = guitar phase invert. Mapping from the footswitch-function switch at P:40C2AD… (values HARMONY, DELAY, uMOD, … GTR BOOST, GTR UMOD, GTR DELAY, GTR REVERB, GTR PHASE).

## 15. Current preset number and name
- Param 0x2A4 = current preset number (written by `func_444889` on preset load: X:3F16 = number, then `func_005137(0x2A4, number)`).
- X:3F1A–3F29 = current preset name, X:3F2A = preset flags (bit 0 toggled by the Favorite button, `func_444cf8`).
- `45 00 00` returns the current preset header (name + flags); see `docs/SYSEX.md`.
- Setup › ROOMSENSE (0x2A7) value names are AMBIENT / AMBIENT/AUTO (list at X:4577B4; its format code 0x95 doesn't index the value-list table). Confirmed on the unit.

## 16. USB SysEx lock-out and factory reset
- 2026-11-13: after a power cycle the unit stopped answering any SysEx over USB (not even the universal identity request); its own MIDI output (bank select + program change) still arrived. VoiceSupport and the oddeyez editor could not control it either. Most likely cause: a stored MIDI setting from the earlier setup-block experiments: **MIDI CTRL 0x278** (MERGE / MIDI / USB; MIDI = only the 5-pin input, which the Play Acoustic doesn't have) or **FILTER 0x27B** (NONE / PRGCHANGE / SYSEX / PC+SYSEX). Not proven.
- `tools/pa-remote.html` now refuses to set 0x278 and 0x27B.
- **Factory initialisation:** at power-on the DSP gets the held front-panel buttons as a mask (`func_40CD9F` → `func_4440C0`). Mask 0x60 sets X:7E6C67, which erases all three stored blocks (X:30BA, 30C9, 30D8: `func_44475A`, `func_444F4D`) and shows "FACTORY INITIALIZATION". So it resets settings **and user presets/favorites**; the firmware itself is untouched. **Confirmed on the unit (2026-11-13): holding STORE + BACK while powering on runs it**, and afterwards USB SysEx control worked again, which supports the stored-MIDI-setting explanation. Other boot masks: 0x09 ("USB CONNECTION FAILED" message), 0x30/0x06 (start on screen 11), 0x0E, 0x01 (other start-up routines, not decoded).

# Menus and display

## 17. Menu tables
See §14 ("Naming from the menu tables", "Full ID range") for the table format and variants. Cross-reference with the manual and the verified Setup layout: `docs/MENUS.md`. Editable layout used by the remote: `tools/pa-menus.js`.

## 18. Display graphics and the FX pages
### Fonts
- **Fonts:** descriptors in rec9 initialised data carry a 32-char name (`Font_ArialBlack7`, `Font_Haettenschweiler13/15/17`, `Font_Impact19`, `Font_VoicePrism5/10`, `Font_Notes28x17`), followed by first/last char (0x20/0x7E), height, a per-character width table and a glyph data pointer (e.g. ArialBlack7: widths X:7EC3F1, glyphs X:7EC450).
- **Pixel format:** 1 bit per pixel, one 24-bit word per column, LSB = top row (e.g. '!' = two columns of 0x1BFF); taller images are stored in 24-row bands (below).
- **Location:** the fonts and bitmaps live at the start of **record 11** (load X:43A180…, about X:43A180–X:43F000), copied at start-up to run X:7EBC77… (run = load + 0x3B1AF7). So they are inside the `.syx`, and the same 8-in-7 patch method applies.
- **Contents seen** (raw renders `graphics/fonts-1.4.00-part1.png`, `…part2`, `…part3`, `graphics/ram-X7EC000-fonts-bitmaps.png`; tall images appear sliced): all fonts, acoustic-guitar body pictures (styles 1–5), "COMPRESS"/"CUSTOM" labels, "CORONA" and "tc electronic" logos, music-notation symbols (notes, staves), people and audience icons, an "Error" graphic, amp and pedal icons, a "play" logo, "SHOW"/"ALT" badges, and many face/hair/collar pieces (avatar builder?).

### Images and FX-page pictures
- **Image table:** record 11 load X:43A1B3, 150 entries `{width, height, data pointer}` (pointer = run address, load = run − 0x3B1AF7). Entries 0–3 are font strips, 4–149 are images (mostly 92×48; also 128×64, 36×36, 60×22, icons). The C start-up copy table (r03 X:42BE50…) copies it to **X:3111**, so code refers to image *i* as `X:3111 + 3·i`; the font descriptors point there too (ArialBlack7 → X:3111).
- **Pixel format:** 1 bpp in 24-row bands: band 0 for all columns left to right, then band 1; LSB = top row of the band.
- `tools/extract_images.py` → `graphics/images-1.4.00/` (PNG per image, `index.json`, numbered `contact-sheet.png`).
- **Style pictures:** `func_446c06` picks the picture for Vocal FX / Guitar FX pages: set = sub-page index (Vocal FX 0–7, table X:7EBAC2) or 8 + sub-page (Guitar FX 0–4, X:7EBAD2); picture = set list[value of the page's first cell]; out of range → image 39 "Error". The 13 sets (load X:439A1D = {list, count}; lists at X:439954–439A1C) are Harmony, Double, Delay ×2, Reverb, HardTune, Transducer, uMOD, Guitar Reverb, Guitar Delay ×2, Guitar uMOD, BodyRez; each count equals that style parameter's value count.
- **Layout** (`func_446ce8`, rectangles at X:459E28/459E2C): picture at (0,7) 92×48, "STYLE: name" text box (0,57)–(90,63), right column x 94–127. Only sub-pages with flags = 2 use it (all basic Vocal/Guitar FX pages; not the advanced or BodyRez shelf/parametric/compressor pages).
- The remote draws these pages from `tools/pa-menus.js` (`"layout": "image"`, `"images": […]`) and `tools/pa-images.js`.

### FX page layout on the unit
- Photo of Harmony 1/7: picture left, "STYLE: HIGH" on the bottom-left soft button, right column = LEVEL (bar), "AUTO / KEY" (value over label), "HIT / CONTROL".
- The right column maps to the three right soft buttons (other cells in order, then CONTROL); STYLE is on the bottom-left button.

# Hardware log

## 19. Confirmed on the unit

| What | Result | Date |
|---|---|---|
| Flash CCtest1 via VoiceSupport, reflash stock 1.4.00 | Both worked; marker strings visible | 2026-11-13 |
| Incoming CC / Program Change (stock and CCtest1) | Ignored (AVR filters them) | 2026-11-13 |
| SysEx setup write | Accepted ("SYSEX SETUP ACCEPTED") | 2026-11-13 |
| SysEx `22`/`47` on HIT 0x2A8, LOOP LEVEL 0x2AC, Mix GUITAR 0x0BB | Work both ways, no pop-up | 2026-11-13 |
| Menu layout: preset screen, Mix 1/2 + 2/2, all 10 Setup pages, Harmony FX page | Matches the firmware tables | 2026-11-13 |
| Mix AUX/ROOMSENSE cell | ROOMSENSE without an aux cable | 2026-11-13 |
| ROOMSENSE values | AMBIENT / AMBIENT/AUTO | 2026-11-13 |
| USB SysEx lock-out after power cycle | Happened; fixed by factory reset (STORE + BACK) | 2026-11-13 |
| SysEx `55` front-panel tunnel for the footswitches | Did not work; reverted | 2026-11-13 |

Everything else (new Setup IDs, CONTROL params, preset name/number, other FX pages) is derived from the code and tracked in `tools/verify.html`.

## Files
- `tools/tch_unpack.py`: `.syx` → `*.sec0.bin` / `*.sec1.bin` (all 7 images).
- `tools/hi08_records.py`: `sec1` → the 12 load records.
- `tools/dump_params.py`, `tools/menu_dump.py`: parameter descriptors and menus (with value names) from emulated RAM.
- `tools/extract_images.py`: display images → PNGs, contact sheet, and `tools/pa-images.js` (`--js`).
- `tools/render_columns.py`: raw column-bitmap renderer (fonts).
- `tools/exploration/codemap.py`, `secdiff.py`: opcode-density map and build diff.
- `tools/emulator/emu_harness.cpp`: emulator harness (§10).
- `legacy/tools/dsp_records_2word.py`, `legacy/tools/params_stride8.py`: superseded first-pass scripts.
