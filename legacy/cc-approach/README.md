# Legacy: the MIDI CC approach (abandoned)

**Status: abandoned on 2026-11-13.** The goal was live parameter control by MIDI CC. The firmware's CC engine works, and a patched image (CCtest1) mapped new CCs, but the pedal's USB co-processor (AVR) **drops all incoming channel messages** (CC and Program Change) before they reach the DSP. Live control now uses the firmware's built-in SysEx "set parameter" command instead (`docs/SYSEX.md`, `tools/pa-remote.html`). Nothing here is needed for that.

Kept for the record:

| File | What |
|---|---|
| `PlayAcoustic 1.4.00 Build51 CCtest1.syx` | Patched 1.4.00 image: CC 30/31/114 remapped, "CC-MOD1" marker strings. Flashed once on the unit (2026-11-13), then stock was reflashed. `SHA256SUMS` alongside. |
| `PATCH-README.md` | The original notes for the patched image. |
| `tools/patch_ccmap.py` | Rewrites the CC map and same-length strings inside a `.syx` (8-in-7 repack of only the touched messages). |
| `tools/ccscan.py` | Data-table scan for a CC map (found nothing useful; see below). |
| `emulation/run-CCtest1-60M.txt` | Emulator run of the patched image. |

Section references like "§17" point to `docs/ANALYSIS.md` at the time; the main analysis has since been reorganised.

## 1. Search for the CC map (QSCCMapList)
- **Manual:** the Play Acoustic reference manual (2014-07-16) has **no MIDI implementation chart**. The CC map has to come from the firmware.
- **Data-table scan (`tools/ccscan.py`):** increasing runs of values 0..127 at 1–8-word strides turn up only math/lookup tables (odd/even sequences, interpolation tables). None is clearly a CC map.
- **A false lead, recorded so nobody repeats it:** sec1 0x01AFC4–0x01B0CF holds `0A708C, 4E`, `0A708C, 4F` … `0A708C, 7B`, which looked like a (handler, CC 78–123) switch table. The same `0A7xxx, small-value` pairs occur hundreds of times across all code, so they are ordinary 2-word instructions (likely bit ops on low X/Y-memory variables; operand = address), **not** a CC table.
- **Conclusion:** locating `QSCCMapList` needs real DSP56300 disassembly. Find the handler that references the assertion string, then follow the table pointer. Candidate tool: the open-source DSP56300 emulator/disassembler in the gearmulator project (dsp56300 core). Not yet built.

## 2. The MIDI CC engine: generic CC → any parameter
- The MIDI module sits at P:0x443000–0x44A400. The SysEx preset/setup accept/reject handlers are at 0x4492DA–0x4495AA (`PRESET MODIFIED VIA SYSEX` at 0x4494A2/B5).
- **`func_44a280(a=controller, b=value)` is the CC handler** (called from the incoming-MIDI loop at 0x449AED):
  - `QSCCMapList[0].map` = X:**0x7E89AD**, `.mapsize` = X:**0x7E89AE**. It runs `assert(controller < mapsize)` with `MIDIhand.c` line 0x588 (pointers 0x45A6C0 / 0x45A6F7 = load + 0x2A8CC).
  - Each map entry is **2 words, indexed by CC number**. Word 0 = parameter ID; `0xFFFFFF` = unmapped, so the CC is ignored.
  - Per-CC rate limiter: counter array X:0x7EC04F, 70 entries, decremented by `func_44a305`.
  - It looks up the parameter descriptor (`func_442bb9`), scales the 0–127 value by parameter type (tables X:0x7E85C4/C6/C8, 5 words per type, `func_0005d3`/`func_442423`/`func_442ac0`), then **sets the parameter via `func_005137`**.
- **Implication:** the stock firmware already has a generic CC-to-parameter engine. Which parameters respond to which CC depends only on the map contents.
- **Open:** nothing in the image writes 0x7E89AD/AE by direct address, and the 0x7Exxxx region is not in any load record or the section table at P:0x416204. So the map pointer is set at run time through a base pointer, or computed. Static data contains no obvious CC-indexed array.
- **Next step:** run the firmware in the dsp56300 emulator (same project) up to the main loop, stubbing the HI08/ESAI waits, then read X:0x7E89AD/AE and the map. Or trace writes into 0x7E8900–0x7E89FF.

## 3. The stock CC map, read in the emulator
After 60M instructions (`emulation/1.4.00/run-stock-60M.txt`, RAM dumps `emulation/1.4.00/ram_X_*.bin`):
```
QSCCMapList[0] @X:7E89AD = { map = X:7E89A5, size = 4 }   QSCCMapList[1] = {0,0}
  entry  param   CC
  0      0x075   30
  1      0x078   31
  2      0x285   114
  3      0x2A8   28    <- HIT (oddeyez editor: "device sends CC 28 every time HIT changes")
```
- The map is part of a contiguous initialised table (neighbours X:7E8998.. hold 0x244, 0x245, …), so it is **static**: 4 CC↔parameter pairs, not a user-configurable list.
- Entry = {param ID, CC#}. `func_44a1df` searches it by param (to *send* the CC when the parameter changes). `func_44a280` applies an incoming CC to the parameter (index < size, then `func_005137` set-parameter).
- Parameter lookup: **corrected in §13**. The stride is 16, not 8 (`maci` is a fractional multiply, so the result is doubled). The labels first reported here ("SMOOTH", "LOWCUT L", "TIME") were wrong. The correct names are 0x075 KEY, 0x078 SCALE, 0x285 BYPASS, and 0x2A8 is unnamed (on/off).
- **Conclusion for live control:** the stock firmware routes only these 4 CCs to parameters. The engine itself is generic, so a firmware patch that **replaces this static table** with more {param, CC} pairs (and the size word) would give knob-style CC control of any parameter. The table is in an initialised-data region whose image location still has to be pinned down before patching.

Stock CC table with names: CC 28 → 0x2A8 (HIT, on/off), CC 30 → 0x075 KEY (0–12), CC 31 → 0x078 SCALE (0–5), CC 114 → 0x285 BYPASS (0–1).

## 4. CC table: location, data flow and patch constraints
- **User observation (2026-11-12):** pressing up/down on the pedal sends **CC 28**. This matches map entry {param 0x2A8, CC 28}: when the parameter changes, the firmware *sends* the CC (`func_44a1df`). The table is confirmed live in both directions. Whether 0x2A8 is "HIT" or a footswitch state is open.
- **Data flow:**
  1. At MIDI init (`func_444126` → `func_44a311`), slot *i* = `map[i].CC` for *i* < size, written to a **70-slot table** at `struct+0x10` (struct pointer at X:$3950E) via `func_449e3b(slot, cc)`. `func_449e41` writes other slot assignments, clamped to 0..127.
  2. Receive (`func_44a334`): an incoming CC# is compared against the 70 slots. A match queues an event with the slot index.
  3. `func_44a280(slot, value)`: `assert(slot < size)`, param = `map[slot].param`, scale, `func_005137` (set parameter).
  4. Send (`func_44a1df`): param changed → look up its slot → transmit `map[slot].CC`.
  - In emulation (60M instr) the slot table was still all 0xFFFFFF because MIDI init had not run yet. That is expected.
- **Hard limit:** 70 entries (the slot table and per-slot rate-limit counters at X:$7EC04F are both sized `0x46`).
- **Location in the image (1.4.00):** the run-time map is X:$7E89A5 (8 words), pointer X:$7E89AD, size X:$7E89AE. It is initialised data: sec1 offset **0xA6BB7** (rec9 load X:$4368AA, run offset +0x3B20FB). In the `.syx`: **message #1583** (file offset 0x0C25AD), unpacked bytes 94–123 = msg bytes 116.. (8-in-7 group 13, pos 3); pointer at msg byte 143, size at msg byte 147. Verified by decoding.
  - Same 8-word map in 1.2.00 (sec1 0xA5DFB) and 1.3.00 (sec1 0xA695F), with a different pointer value. 1.0.04/1.1.00 differ.
- **Patch constraints (not attempted):**
  - The table cannot grow in place: other initialised data follows directly (X:$7E89AF onward, incl. the 117-entry param array at $7E89B1).
  - Option A: swap the 4 existing pairs for 4 other params. This is the smallest possible patch and needs only a re-pack of msg #1583.
  - Option B: a larger table (≤70) placed in unused initialised space, then retarget the pointer and size. This needs a verified-unused region *inside a section listed in the flash-writer's section table* (P:$416204). Records outside those sections are not written to flash and would vanish on reboot.
  - Either way: a param-ID → name/knob mapping is still needed to choose what to map, and nothing should be flashed before a recovery path is proven.

## 5. Test patch "CCtest1"
- File: `PlayAcoustic 1.4.00 Build51 CCtest1.syx`. sha256 in `SHA256SUMS`, which reads `ac9b7bbf…09ac` for the current build. Built by `tools/patch_ccmap.py IN OUT 30=0x283 31=0x158 114=0x270` from the stock 1.4.00 (stock file unchanged, sha256 `b272cba3…`).
- Mapping:

| CC | stock param | patched param | range |
|---|---|---|---|
| 28 | 0x2A8 (pedal on/off) | unchanged | 0–1 |
| 30 | 0x075 KEY | **0x283 GUITAR** (guitar level) | −31…+24 dB |
| 31 | 0x078 SCALE | **0x158 TEMPO** | 45…300 BPM |
| 114 | 0x285 BYPASS | **0x270 PITCH CORRECTION** | 0…100 |

- **Verification done:**
  1. File level: same size and message count. **7 bytes changed**, all in message #1583 (file 0x0C261D–0x0C2631). The repacker preserves the original padding flag bits.
  2. Decoded level (`tools/tch_unpack.py` on both): sec0 identical. sec1 differs in **exactly 3 words** (sec1 0xA6BB7/0xA6BBD/0xA6BC3: 0x075→0x283, 0x078→0x158, 0x285→0x270).
  3. Emulation: the patched image boots the same way. After 60M instructions RAM shows `QSCCMapList = {X:7E89A5, 4}` with entries {0x283,30}, {0x158,31}, {0x270,114}, {0x2A8,28} (`emulation/run-CCtest1-60M.txt`).
- **Not verified / risks:**
  - Incoming-CC → parameter was not exercised in emulation (no MIDI injection). The 0–127 scaling for dB/BPM parameters is untested.
  - There is no image signature, and per-block checksums are computed by the sender at flash time. **Unknown:** whether the AVR or the flash writer keeps an image checksum and would reject or flag a modified image.
  - Recovery assumption: the HI08 bootloader lives in the AVR, not in this DSP image, so a stock image could be re-flashed if the patched DSP firmware misbehaves. Plausible (the patch only changes data, not code), but **unproven on hardware**. Keep stock 1.4.00 and official 1.3.00 at hand before any flash.
  - KEY, SCALE and BYPASS lose their CCs in this build.

## 6. Build marker strings
- `tools/patch_ccmap.py` now also does same-length string edits (`--str "OLD=>NEW"`). Each must match exactly one whole NUL-delimited string, stored one char per 24-bit word.
- Applied: `FIRMWARE VERSION:` → `CC-MOD1  VERSION:` (sec1+0x091473, run X:459F60) and the short version format `%s%1d.%1d.%02d BUILD%d` → `…CCMOD%d` (sec1+0x091F50, run X:45A2FF), so the version shows as "1.4.00 CCMOD51".
- **Deliberately unchanged:** the long `VERSION:%s… BUILD%d  SVN:%s  AVR:%d` line (X:45A31B), which may be what an editor or report parses.
- Current CCtest1 sha256 `a0309acd…b093` (see `SHA256SUMS`). The file has 18 bytes changed in messages #1380, #1386 and #1583. Decoded: only the 2 strings and the 3 CC parameter words differ. In emulated RAM after boot the new strings are present at their run addresses and the CC map is as in §14.
- **Which screen:** `FIRMWARE VERSION:` is the only firmware-version label in the image. The function at P:4480F2 draws the **unit information screen** with `FIRMWARE VERSION:`, `SERIAL NUMBER:` (`%08lu`) and `MANUFACTURE DATE:` (`%4d.%02d.%02d` / `NOT SET`). In CCtest1 that label reads **`CC-MOD1  VERSION:`**. The user reports that the short "…BUILD%d" format (P:448C30) is not shown on screen; changing it is harmless.
- `Application Version: %s`, `AVR Version: %d.%d` and `SVN Version: %s` (P:448243–448275) belong to a factory test screen ("Lerdorf GTX Front Test", key/encoder tests), not the normal info page. They are unchanged.

## 7. Flash risk of the patch
- **Data-only change:** 3 words in the CC table and 2 same-length strings, all in initialised-data sections. The boot record, flash loader, flash writer, section table, record layout and size are **identical to stock 1.4.00**, so the same sectors are erased and written. In the emulator the patched image boots to the same state as stock.
- Nothing checks image integrity, so the modified image is accepted as-is.
- **Risk that the patch itself stops the unit booting: very low.** Remaining effects are runtime only (CC behaviour of GUITAR/TEMPO/PITCH CORRECTION untested; KEY/SCALE/BYPASS CCs lost).


### Verdict
- Low risk from the patch content. The overall risk is about that of a normal update, plus the unproven recovery assumption above.
- **Precautions:**
  1. Back up presets and setup with the editor ("Backup All").
  2. Keep stock 1.4.00 and official 1.3.00 `.syx` at hand (hashes in `stock/oddeyez/SHA256SUMS`).
  3. Use a direct USB port, with the laptop on mains power and sleep disabled; don't touch the unit during the update.
  4. **First flash stock 1.4.00 with the exact same tool and setup.** This proves the procedure end-to-end at minimal risk, since it's the version the unit already runs or was meant to run.
  5. Then flash CCtest1 and check the info screen for `CC-MOD1  VERSION:`.
- **If anything goes wrong:** power-cycle, then reflash stock 1.4.00 via the editor's Firmware Manager (it sends `0x51` without needing an identity reply). Next try the official TC VoiceSupport2 app with official 1.3.00. Only then consider hardware recovery.

## 8. Hardware result: incoming CCs never reach the DSP
- CCtest1 flashed via TC VoiceSupport (the oddeyez site can't load custom files). The marker strings show on the unit. Stock 1.4.00 was reflashed afterwards for A/B testing.
- **VoiceSupport must be closed:** while it is running and connected, incoming SysEx is lost ("SYSEX SETUP REJECTED: PACKAGES LOST OR OUT OF SYNC").
- The unit **sends** channel messages over USB (e.g. HIT → `B0 1C 40`, value 64 = on).
- On **stock and CCtest1 alike**, incoming CC 28 (HIT), other CCs and Program Change on all 16 channels have **no effect**. Incoming SysEx works (setup writes: "SYSEX SETUP ACCEPTED").
- Settings read from the unit's setup block (with the earlier CC tester, since removed): MIDI CTRL 0, MIDI CHAN 1, CC CHAN 1. MIDI CTRL 1 and 2 were also tried.
  - The setup block is a parameter *list*, not a contiguous ID range. Slots verified by defaults: AUX −5 @53, MIDI CTRL @56, MIDI CHAN @57, CC CHAN @58, PBRANGE 2 @61, TUNE REF 880 @65, HIT @82 (= oddeyez packet 3 byte 41).
- The DSP parser is fed USB-MIDI event packets from the AVR (`func_006e67` → `func_44a451`), and its CC path checks out statically. **Conclusion:** the AVR forwards SysEx to the DSP but filters incoming channel messages. This is consistent with the spec sheet ("USB: firmware updates, preset management, audio I/O") and with the oddeyez editor using SysEx setup writes instead of CCs. A DSP-only patch cannot enable CC receive.
- **Remaining route to live control:** SysEx, which reaches the DSP. Either full setup/preset rewrites (no firmware change), or a DSP patch that adds a compact "set parameter" SysEx command routed to the central setter `func_005137`.
