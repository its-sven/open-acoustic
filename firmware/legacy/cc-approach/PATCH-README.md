# CCtest1 patched image (original notes, now legacy)

> Superseded: see `README.md` in this folder. CCtest1 was later flashed once for testing (2026-11-13) and stock 1.4.00 reflashed.

These are modified copies of the stock 1.4.00 image, built at the user's direction (the project moved from analysis to modification on 2026-11-12). **None has been flashed or sent to a device.**

- `PlayAcoustic 1.4.00 Build51 CCtest1.syx` (sha256 in `SHA256SUMS`):
  - MIDI CC map: CC 30 → GUITAR level (0x283), CC 31 → TEMPO (0x158), CC 114 → PITCH CORRECTION (0x270). CC 28 is unchanged.
  - Build marker: the unit-information screen label `FIRMWARE VERSION:` reads **`CC-MOD1  VERSION:`**. The short version format reads "…CCMOD51" (reportedly not shown on screen).
  - Verified by file and decode diffs and in the dsp56300 emulator only. See `README.md` §5–§6 in this folder.
- No image checksum or signature is checked by the DSP flash writer or the flash boot loader (`docs/ANALYSIS.md` §17). **The recovery path is untested on hardware.**
- The stock images in `stock/oddeyez/` (and `stock/official/`) are the reference and recovery copies. They are unchanged and match their `SHA256SUMS`.
