# Play Acoustic firmware set — cross-version analysis

Same method as `ANALYSIS.md`, applied to all five PA images.

## Per-build summary

| Build | File bytes | SysEx msgs | 0x52 data | high-bit bytes | unpacked bytes | unpacked entropy /8 | raw7 strings ≥5 |
|---|---|---|---|---|---|---|---|
| 1.0.04 Build 21 | 1,065,188 | 2,119 | 2,117 | 0 | 917,203 | 5.923 | 6,774 |
| 1.1.00 Build 27 | 1,071,379 | 2,132 | 2,130 | 0 | 922,529 | 5.930 | 7,137 |
| 1.2.00 Build 38 | 1,123,916 | 2,236 | 2,234 | 0 | 967,771 | 5.881 | 6,304 |
| 1.3.00 Build 48 | 1,127,635 | 2,243 | 2,241 | 0 | 970,976 | 5.880 | 6,609 |
| 1.4.00 Build 51 | 1,129,106 | 2,246 | 2,244 | 0 | 972,242 | 5.881 | 6,714 |

All five are identical in structure:
- Header `00 01 38 00 60 <type>` on every message; `0x51` enter/exit markers + `0x52` data blocks.
- Zero data bytes ≥ 0x80 → clean 7-bit MIDI.
- 8-in-7 LSB packing (496 payload → 434 bytes per 504-byte block).
- Unpacked entropy ~5.88–5.93 bits/byte with non-uniform histograms → **unencrypted, structured** in every build. None is packed/encrypted.
- Plaintext factory preset/effect-name table present in every build (grep: SLAP / REVERB / MEGAPHONE / TAPE / ECHO all hit).

## Version relationship
Unpacked size grows monotonically with version (917 KB → 972 KB), matching the manifest's feature additions (MP-76 support, guitar delay, longer looper, Switch-3/6 MIDI, etc.).

Byte-level shared prefix between consecutive versions is only ~1 KB. That is **not** evidence they are unrelated: these are compiled images, so any size change near the top shifts every following byte and defeats a naive prefix/offset diff. A meaningful code diff would require locating the image's section layout first (load address, code vs data vs string-table boundaries) and aligning on that — out of scope for this pass.

## Artifacts (per build, in this folder)
- `PA-<ver>.unpacked.bin` — unpacked payload (8-in-7 reconstruction; minor alignment quirk in the ASCII name-table region, as noted in `ANALYSIS.md`).
- `PA-<ver>.strings-raw7.txt` — strings from the raw 7-bit stream (cleanest for the ASCII tables).

## Not done
- No per-version feature/string diff beyond "table present". Say the word if you want a proper section-aware diff.
- Nothing flashed; all stock `.syx` files remain read-only recovery images.
