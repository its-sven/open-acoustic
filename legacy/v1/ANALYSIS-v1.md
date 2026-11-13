# Play Acoustic firmware — analysis

Target: `PlayAcoustic 1.4.00 Build51.syx` (newest PA image; the one the editor treats as "required").

## File
- Size: 1,129,106 bytes
- SHA-256: `b272cba3ae04770a545146a5812f23a7c8763950db380c550e9147f99e710ef3`
- SysEx messages: 2,246, all clean (every one F0…F7, no bytes between messages, no data byte ≥ 0x80).

## Framing
Every message uses the TC-Helicon header `00 01 38 00 60 <type>`:
- `0x51` — 2 msgs (`F0 00 01 38 00 60 51 00 F7` / `…52 01 F7`): bootloader enter/exit markers. Sent raw, no handshake.
- `0x52` — the rest: data blocks. 2,237 are exactly 504 bytes; a few 40-byte and one 1,131-byte block; one 340-byte block.
  - Layout: `F0` + `00 01 38 00 60 52` + 496-byte payload + `F7`.
  - Per block the editor sends a header `…60 7E <checksum> <sizeHi> <sizeLo> F7` where `checksum = (sum of bytes[6..end-1]) & 0x7F`, then the block, then `…60 7D F7`, and waits for `…60 7F 01` (accepted) / `00` (retry). Device reboots and replies with its identity (`…70 7E 7F …`).

## Payload packing
Standard MIDI **8-in-7 (LSB-first)**: one flag byte carries bit 7 for the next up-to-7 data bytes. 496 payload bytes = 62 groups → 434 raw bytes per block. Unpacked total ≈ 972,242 bytes.
Confirmation: in the raw 7-bit stream the preset-name table reads directly with a gap every 8th character (the flag byte), e.g. `R·OCKABIL·LY SLAP` → `ROCKABILLY SLAP`.

## Entropy — unencrypted, structured
- Raw 7-bit stream: windowed entropy 0.2 … 6.96 bits/byte (7-bit ceiling = 7.0), mean 4.53.
- High-entropy region unpacked to true 8-bit: **6.68 bits/byte**, all 256 values present but max/mean count ratio ≈ 35× (very non-uniform).

Encrypted or compressed firmware sits near 7.95+/8 with a near-flat histogram and essentially zero strings. This image is nowhere near that: it is a dense compiled code/data region plus clearly structured low-entropy tables, i.e. **plain (unencrypted) firmware**, 7-bit-packed only for MIDI transport.

## Strings
Plaintext confirmed. The tail blocks (~2145–2250) are a **factory preset / effect name table**:
`ROCKABILLY SLAP`, `GORGEOUS HALL`, `BOUNCY ROOM`, `MEGAPHONE`, `LUCKY MAN ELP`, `JUST SEEN A FACE`, `CALI HOTEL`, `ROLLIN DEEP`, `BAREFOOT BLUEJN`, `BRICKWALL FLOYD`, `BOYS OF FALL`, `DEEP TALKER`, `TOTALLY ALIEN!`, `TOTAL IMMERSION`, `SPRING REVERB`, `LO FI ECHO`, `1/4 DELAY`, `LONG TRIP DELAY`, `MEGAPHONE ECHO`, `LONG TAPE ECHO`, `INHUMAN`, `OCTAVE GANG`, … plus `HARMONY`, `BUILDING`.
No explicit "1.4.00 / Build 51" version string was found in the body; the version lives in the manifest and in the device identity reply, not the image payload.

## Artifacts
- `PA-1.4.00-Build51.unpacked.bin` — unpacked payload (sha256 `9471f7f897a3545967cfa715a2d15efd58a4f4e2afe2e44b4b1993aa8160e1f7`). Note: the 8-in-7 reconstruction has a minor alignment quirk in the ASCII name-table region; the raw-stream reading above is the reliable one there.
- `strings-raw7.txt`, `strings-unpacked.txt`.

## How the site serves firmware (no server-side version check)
- List: static `https://oddeyez.se/app/firmware/manifest.json`.
- Images: `https://oddeyez.se/app/firmware/<filename>.syx`.
- The "required" version is hard-coded in the page; the server is never asked.
