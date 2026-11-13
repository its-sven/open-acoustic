# Menus: firmware 1.4.00 vs the unit and User Manual V1.0

> **Which part is authoritative:** the sections at the end ("Mix menu…", "Setup menu on the unit…", "Vocal FX and Guitar FX on the unit…") come from the complete menu extraction and are checked against the unit. The manual cross-reference before them was written from an earlier extraction that missed every parameter above 0x2BF, so its "no firmware page" notes for Product Info and Switch-3 are wrong: both pages exist (Setup 10/10 and 7/10). The remote's editable layout is `tools/pa-menus.js`.

Manual: TC-Helicon *Play Acoustic User Manual* V1.0 (M_TH_0726-AAI, PDF). Firmware: menu page tables (ANALYSIS.md §20–§22). Firmware labels are built the way the display builds them: instance label + parameter name. Slots are the soft-button rows (1–3) and side (left/right).

- ✅ manual parameter found on the matching firmware page
- ↪ manual parameter found, but on a different firmware page (moved in a later firmware)
- ➕ firmware parameter on that page not described in the V1.0 manual (usually added later)
- Manual option values (Off/On, style names) are omitted. PDF text extraction mixes two-page spreads, so a few manual entries may be listed under a neighbouring page.

## Input (1/7) → Setup › INPUT
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Input | 0x272 | INPUT | row 1 left |
| ✅ RoomSense | 0x2a7 | ROOMSENSE | row 2 left |
| ✅ Guitar | 0x283 | GUITAR | row 3 left |
| ↪ Loop | 0x2ac | LOOP LEVEL | Home › HOME, row 3 left |
| ✅ Tone Style | 0x2a9 | TONE STYLE | row 2 right |
| ↪ Lead Delay | 0x28c | LEAD DELAY | Setup › SYSTEM, row 3 left |
| ↪ Tune Reference | 0x281 | TUNE REFERENCE | Setup › SYSTEM, row 1 right |
| ↪ Aux to Main Out | 0x2ab | AUX TO MAIN OUT | Setup › SYSTEM, row 2 right |
| ↪ Aux In Type | 0x2aa | AUX IN TYPE | Setup › SYSTEM, row 3 right |
| ↪ Global Key | 0x287 | GLOBAL KEY | Setup › SYSTEM, row 1 left |
| ↪ Global Tempo | 0x28b | GLOBAL TEMPO | Setup › SYSTEM, row 2 left |
| ✅ RoomSense LoCut | 0x2a7 | ROOMSENSE | row 2 left |
| ✅ Guitar Gate | 0x283 | GUITAR | row 3 left |
| ✅ Pitch Cor Amt | 0x270 | PITCH CORRECTION | row 3 right |

## Output (2/7) → Setup › OUTPUT
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Output | 0x0e9 | OUTPUT | row 1 left |
| ✅ Lead Mute | 0x28d | LEAD MUTE | row 2 right |
| ↪ Headphone Lim | 0x0be | HEADPHONE LEVEL | Home › HOME, row 2 right |

## System (3/7) → Setup › SYSTEM
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ LCD Contrast | 0x29f | LCD CONTRAST | row 1 left |
| ➕ | 0x281 | TUNE REFERENCE | row 1 right |
| ➕ | 0x2a0 | UP/DN FUNCTION | row 2 left |
| ➕ | 0x2ab | AUX TO MAIN OUT | row 2 right |
| ➕ | 0x28c | LEAD DELAY | row 3 left |
| ➕ | 0x2aa | AUX IN TYPE | row 3 right |
| ➕ | 0x287 | GLOBAL KEY | row 1 left |
| ➕ | 0x28b | GLOBAL TEMPO | row 2 left |
| ➕ | 0x286 | GLOBAL GUITAR FX | row 1 left |

## Product Info (7/7) → *no firmware page with this title*

## Harmony (1/7) → Effects › HARMONY, EffectsAdvanced › HARMONY
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Style | 0x06b | STYLE | row 1 left |
| ➕ | 0x0b9 | LEVEL | row 2 left |
| ➕ | 0x075 | KEY | row 2 right |
| ➕ | 0x078 | SCALE | row 1 left |
| ➕ | 0x071 | HUMANIZE | row 1 right |
| ➕ | 0x093 | PORTAMENTO | row 2 left |

## Loop (5/7) → Setup › LOOP
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Input | 0x11b | INPUT | row 1 left |
| ✅ Undo | 0x2a2 | UNDO | row 2 left |
| ✅ Loop Feedback | 0x2a1 | LOOP FEEDBACK | row 3 left |

## Switch-3 (6/7) → *no firmware page with this title*
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ↪ Feedback | 0x167 | FEEDBACK | Effects › DELAY, row 2 right |
| ↪ Tempo | 0x158 | TEMPO | EffectsAdvanced › DELAY, row 1 right |

## Reverb (4/7) → Effects › REVERB
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ↪ Style | 0x06b | STYLE | Effects › HARMONY, row 1 left |
| ✅ Decay | 0x19f | DECAY | row 2 right |
| ➕ | 0x19a | REVERB STYLE | row 1 left |
| ➕ | 0x0d5 | LEVEL | row 2 left |

## HardTune (5/7) → Effects › HARDTUNE
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Style | 0x266 | STYLE | row 1 left |
| ✅ Shift | 0x26b | SHIFT | row 2 left |
| ✅ Gender | 0x271 | GENDER | row 2 right |
| ↪ Key | 0x075 | KEY | Effects › HARMONY, row 2 right |
| ↪ Scale | 0x078 | SCALE | EffectsAdvanced › HARMONY, row 1 left |
| ↪ Portamento | 0x093 | PORTAMENTO | EffectsAdvanced › HARMONY, row 2 left |
| ↪ Humanize | 0x071 | HUMANIZE | EffectsAdvanced › HARMONY, row 1 right |

## Double (2/7) → Effects › DOUBLE
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Style | 0x09d | STYLE | row 1 left |
| ➕ | 0x0ba | LEVEL | row 2 left |

## Delay (3/7) → Effects › DELAY, EffectsAdvanced › DELAY
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ↪ Style | 0x06b | STYLE | Effects › HARMONY, row 1 left |
| ➕ | 0x150 | DELAY STYLE | row 1 left |
| ➕ | 0x0d4 | LEVEL | row 2 left |
| ➕ | 0x167 | FEEDBACK | row 2 right |
| ➕ | 0x17d | FILTER | row 1 left |
| ➕ | 0x158 | TEMPO | row 1 right |
| ➕ | 0x159 | DELAY TIME | row 1 right |

## Guitar Reverb (1/7) → Guitar › GUITAR REVERB, GuitarAdvanced › GUITAR REVERB
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ↪ Style | 0x06b | STYLE | Effects › HARMONY, row 1 left |
| ↪ Decay | 0x19f | DECAY | Effects › REVERB, row 2 right |
| ➕ | 0x19b | REVERB | row 1 left |
| ➕ | 0x0d8 | REVERB LEVEL | row 2 left |
| ➕ | 0x1a0 | REVERB DECAY | row 2 right |
| ➕ | 0x1a3 | REVERB PRE DLY | row 1 left |

## Guitar Mod (2/7) → *no firmware page with this title*
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ↪ Style | 0x06b | STYLE | Effects › HARMONY, row 1 left |
| ↪ Speed | 0x130 | SPEED | Effects › uMOD, row 2 right |
| ↪ Depth | 0x12c | DEPTH | GuitarAdvanced › GUITAR uMOD, row 1 left |

## BodyRez EQ (3/7) → Guitar › BODYREZ EQ, GuitarAdvanced › BODYREZ EQ
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Style | 0x2ad | STYLE | row 1 left |
| ➕ | 0x2af | AMOUNT | row 2 left |
| ➕ | 0x2b3 | LOW GAIN | row 2 right |
| ➕ | 0x2b7 | HI GAIN | row 2 2 |

## Transducer (6/7) → Effects › TRANSDUCER, EffectsAdvanced › TRANSDUCER
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Style | 0x249 | STYLE | row 1 left |
| ✅ Drive | 0x24b | DRIVE | row 2 left |
| ✅ Filter | 0x263 | FILTER | row 2 right |
| ✅ Routing | 0x24a | ROUTING | row 1 left |
| ↪ Output | 0x0e9 | OUTPUT | Setup › OUTPUT, row 1 left |
| ✅ Gate Threshold | 0x05e | GATE THRESHOLD | row 2 left |
| ✅ Gain | 0x24f | GAIN | row 1 right |

## Mod (7/7) → *no firmware page with this title*
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ↪ Style | 0x06b | STYLE | Effects › HARMONY, row 1 left |
| ↪ Speed | 0x130 | SPEED | Effects › uMOD, row 2 right |
| ↪ Notch Freq | 0x05a | NOTCH FREQ | Setup › GUITAR ANTI-FEEDBACK, row 2 right |

## Mix (1/2) → Mixer › MIX
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Harmony | 0x0c1 | HARMONY | row 1 right |
| ✅ Guitar Level | 0x0bb | GUITAR LEVEL | row 1 left |
| ✅ Out Level | 0x0bc | OUT LEVEL | row 3 right |
| ✅ Delay/Reverb level | 0x0c0 | DELAY/REVERB | row 2 right |
| ✅ Headphone Level | 0x0be | HEADPHONE LEVEL | row 1 right |
| ✅ RoomSense | 0x276 | ROOMSENSE | row 3 left |
| ✅ Aux Level | 0x275 | AUX | row 3 left |
| ➕ | 0x2ac | LOOP LEVEL | row 2 left |
| ➕ | 0x0bf | USB IN LEVEL | row 1 left |
| ➕ | 0x0bd | USB OUT LEVEL | row 2 left |

## Mix (2/2) → Mixer › MIX
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ USB In Level | 0x0bf | USB IN LEVEL | row 1 left |
| ✅ USB Out Level | 0x0bd | USB OUT LEVEL | row 2 left |
| ↪ Low Gain | 0x2b3 | LOW GAIN | Guitar › BODYREZ EQ, row 2 right |
| ↪ Hi Gain | 0x2b7 | HI GAIN | Guitar › BODYREZ EQ, row 2 2 |
| ➕ | 0x0bb | GUITAR LEVEL | row 1 left |
| ➕ | 0x0be | HEADPHONE LEVEL | row 1 right |
| ➕ | 0x2ac | LOOP LEVEL | row 2 left |
| ➕ | 0x275 | AUX | row 3 left |
| ➕ | 0x0bc | OUT LEVEL | row 3 right |
| ➕ | 0x0c1 | HARMONY | row 1 right |
| ➕ | 0x0c0 | DELAY/REVERB | row 2 right |
| ➕ | 0x276 | ROOMSENSE | row 3 left |

## BodyRez Shelf EQ (4/7) → GuitarAdvanced › BODYREZ SHELF EQ
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ➕ | 0x033 | LOW FREQ | row 1 left |
| ➕ | 0x051 | HI FREQ | row 1 right |
| ➕ | 0x2b3 | LOW GAIN | row 2 left |
| ➕ | 0x2b7 | HI GAIN | row 2 right |

## BodyRez Parametric EQ (5/7) → GuitarAdvanced › BODYREZ PARAMETRIC EQ
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ➕ | 0x032 | PARA 1 FREQ | row 1 left |
| ➕ | 0x050 | PARA 2 FREQ | row 1 right |
| ➕ | 0x038 | PARA 1 WIDTH | row 2 left |
| ➕ | 0x056 | PARA 2 WIDTH | row 2 right |
| ➕ | 0x2b1 | PARA 1 GAIN | row 3 left |
| ➕ | 0x2b5 | PARA 2 GAIN | row 3 right |

## BodyRez Compressor (6/7) → GuitarAdvanced › BODYREZ COMPRESSOR
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Threshold | 0x2bb | THRESHOLD | row 1 left |
| ✅ Makeup Gain | 0x2bd | MAKEUP GAIN | row 3 left |
| ✅ Ambience | 0x2b9 | AMBIENCE | row 3 right |

## Guitar Anti-Feedback (7/7) → Setup › GUITAR ANTI-FEEDBACK
| Manual | ID | Firmware label | Position |
|---|---|---|---|
| ✅ Notch Gain | 0x03f | NOTCH GAIN | row 1 right |
| ➕ | 0x05a | NOTCH FREQ | row 2 right |

## Firmware pages with no V1.0 manual page
- **Effects › uMOD**: 0x124 uMOD STYLE, 0x0d3 LEVEL, 0x130 SPEED
- **Guitar › GUITAR DELAY**: 0x151 DELAY, 0x0d7 DELAY LEVEL, 0x168 FEEDBACK
- **Guitar › GUITAR uMOD**: 0x125 uMOD, 0x0d6 UMOD LEVEL, 0x131 SPEED
- **GuitarAdvanced › GUITAR DELAY**: 0x158 TEMPO, 0x17e FILTER, 0x15a DELAY TIME, 0x151 DELAY, 0x0d7 DELAY LEVEL, 0x168 FEEDBACK
- **GuitarAdvanced › GUITAR uMOD**: 0x12c DEPTH, 0x125 uMOD, 0x0d6 UMOD LEVEL, 0x131 SPEED
- **Home › HOME**: 0x0bb GUITAR LEVEL, 0x0be HEADPHONE LEVEL, 0x2ac LOOP LEVEL
- **Setup › MIC CONTROL**: 0x29e MP75 CONTROL

## Mix menu in firmware 1.4.00 (page data X:7E8F6A; variants 7E8F7A/7E8F8A swap AUX for ROOMSENSE or drop it: AUX only while a cable is in AUX IN, sensed by 0x295)

| Firmware page | Position | ID | Firmware label | V1.0 manual |
|---|---|---|---|---|
| 1 | row 1 left | 0x0bb | GUITAR LEVEL | Guitar Level (p1) |
| 1 | row 1 right | 0x0be | HEADPHONE LEVEL | Headphone Level (p1) |
| 1 | row 2 left | 0x2ac | LOOP LEVEL | (not in V1.0; looper level added later) |
| 1 | row 3 left | 0x275 | AUX | Aux Level (p1) |
| 1 | row 3 right | 0x0bc | OUT LEVEL | Out Level (p1) |
| 2 | row 1 left | 0x0bf | USB IN LEVEL | USB In Level (p2) |
| 2 | row 1 right | 0x0c1 | HARMONY | Harmony (p1) |
| 2 | row 2 left | 0x0bd | USB OUT LEVEL | USB Out Level (p2) |
| 2 | row 2 right | 0x0c0 | DELAY/REVERB | Delay/Reverb level (p1) |

In firmware 1.4.00, **Harmony** and **Delay/Reverb** moved from Mix page 1 to page 2, making room for **LOOP LEVEL**. All 9 V1.0 Mix controls are present; the hardware confirmed GUITAR LEVEL (0x0BB) and LOOP LEVEL (0x2AC).

## Setup menu on the unit (firmware 1.4.00), verified against photos

Confirmed against photos of a real unit on 2026-11-13. The earlier cross-reference above dropped every menu item whose parameter ID is above 0x2BF (e.g. HEADPHONE LIM, VOCAL CANCEL, MIC BOOST). The parameter table actually covers 0x000–0x3B3. Pages 6 and 7 depend on Setup › FOOTSWITCH (0x39F): SWITCH-6 shows *SYSTEM (SWITCH-6 MODE)* and *SWITCH-6*; SWITCH-3 shows *SYSTEM (CONTROL)* and *SWITCH-3*.

| # | Page | Row 1 | Row 2 | Row 3 |
|---|---|---|---|---|
| 1 | INPUT | INPUT `0x272` \| — | ROOMSENSE `0x2A7` \| TONE STYLE `0x2A9` | GUITAR `0x283` \| PITCH CORRECTION `0x270` |
| 2 | OUTPUT | OUTPUT `0x0E9` \| HEADPHONE LIM `0x312` | VOCAL CANCEL `0x317` \| LEAD MUTE `0x28D` | — \| — |
| 3 | SYSTEM | LCD CONTRAST `0x29F` \| TUNE REFERENCE `0x281` | UP/DN FUNCTION `0x2A0` \| AUX TO MAIN OUT `0x2AB` | LEAD DELAY `0x28C` \| AUX IN TYPE `0x2AA` |
| 4 | SYSTEM | GLOBAL KEY `0x287` \| GUITAR GATE `0x329` | GLOBAL TEMPO `0x28B` \| MIC BOOST `0x352` | ROOMSENSE LOCUT `0x35A` \| BODYREZ EDITING `0x362` |
| 5 | GUITAR ANTI-FEEDBACK | PHASE INVERT `0x347` \| GAIN `0x03F` | LOW CUT `0x348` \| NOTCH FREQ `0x05A` | — \| — |
| 6 | SYSTEM | GLOBAL GUITAR FX `0x286` \| — | GUITAR BOOST AMT `0x349` \| — | FOOTSWITCH `0x39F` \| SWITCH-6 MODE `0x3A0` |
| — | SYSTEM (SWITCH-3) | GLOBAL GUITAR FX `0x286` \| — | GUITAR BOOST AMT `0x349` \| — | FOOTSWITCH `0x39F` \| CONTROL `0x35B` |
| — | SWITCH-3 (SWITCH-3) | SWITCH 1 `0x393` \| — | SWITCH 2 `0x394` \| — | SWITCH 3 `0x395` \| — |
| 7 | SWITCH-6 | SWITCH 1 `0x3A7` \| SWITCH 2 `0x3A8` | SWITCH 3 `0x3A9` \| SWITCH 4 `0x3AA` | SWITCH 5 `0x3AB` \| SWITCH 6 `0x3AC` |
| 8 | MIC CONTROL | MP76 CONTROL `0x39A` \| MP75 CONTROL `0x29E` | MP76 TOP `0x39E` \| MP76 BOTTOM `0x39C` | MP76 LEFT `0x39D` \| MP76 RIGHT `0x39B` |
| 9 | LOOP | INPUT `0x11B` \| — | UNDO `0x2A2` \| — | LOOP FEEDBACK `0x2A1` \| — |
| 10 | PRODUCT INFO | firmware version, serial number, manufacture date (text page) | | |

Rows are shown in the order the item list stores them. Value names (DYNAMIC MIC, AMBIENT, LOOPING, 1 BTN LOOPER, …) come from the firmware's value-list pointer table at X:457795, indexed by descriptor word 12. `tools/menu_dump.py` regenerates all menus with names, ranges and value lists into `data/menus-1.4.00.json`.

## Vocal FX and Guitar FX on the unit (firmware 1.4.00)

Layout confirmed on the Harmony page: picture left, STYLE on the bottom-left soft button, right column = the other cells top to bottom on the right soft buttons, then CONTROL (OFF / ON / HIT) on the bottom-right button. The other pages follow the same firmware layout but have not been compared with the unit yet (`tools/verify.html`).

| Menu | Page | STYLE (bottom-left) | Right column | CONTROL |
|---|---|---|---|---|
| VOCAL FX | HARMONY | STYLE `0x06B` | LEVEL `0x0B9`, KEY `0x075` | CONTROL `0x2CE` |
| VOCAL FX | DOUBLE | STYLE `0x09D` | LEVEL `0x0BA` | CONTROL `0x2CF` |
| VOCAL FX | DELAY | DELAY STYLE `0x150` | LEVEL `0x0D4`, FEEDBACK `0x167` | CONTROL `0x2CC` |
| VOCAL FX | REVERB | REVERB STYLE `0x19A` | LEVEL `0x0D5`, DECAY `0x19F` | CONTROL `0x2CD` |
| VOCAL FX | HARDTUNE | STYLE `0x266` | SHIFT `0x26B`, GENDER `0x271` | CONTROL `0x2D1` |
| VOCAL FX | TRANSDUCER | STYLE `0x249` | DRIVE `0x24B`, FILTER `0x263` | CONTROL `0x2D0` |
| VOCAL FX | uMOD | uMOD STYLE `0x124` | LEVEL `0x0D3`, SPEED `0x130` | CONTROL `0x2CB` |
| GUITAR FX | GUITAR REVERB (BodyRez basic) | REVERB `0x19B` | REVERB LEVEL `0x0D8`, REVERB DECAY `0x1A0` | CONTROL `0x353` |
| GUITAR FX | GUITAR DELAY (BodyRez basic) | DELAY `0x151` | DELAY LEVEL `0x0D7`, FEEDBACK `0x168` | CONTROL `0x355` |
| GUITAR FX | GUITAR uMOD (BodyRez basic) | uMOD `0x125` | UMOD LEVEL `0x0D6`, SPEED `0x131` | CONTROL `0x357` |
| GUITAR FX | BODYREZ EQ (BodyRez basic) | STYLE `0x2AD` | AMOUNT `0x2AF`, LOW GAIN `0x2B3` | — |
| GUITAR FX | GUITAR REVERB (BodyRez advanced) | REVERB `0x19B` | REVERB LEVEL `0x0D8`, REVERB DECAY `0x1A0` | CONTROL `0x353` |
| GUITAR FX | GUITAR DELAY (BodyRez advanced) | DELAY `0x151` | DELAY LEVEL `0x0D7`, FEEDBACK `0x168` | CONTROL `0x355` |
| GUITAR FX | GUITAR uMOD (BodyRez advanced) | uMOD `0x125` | UMOD LEVEL `0x0D6`, SPEED `0x131` | CONTROL `0x357` |
| GUITAR FX | BODYREZ EQ (BodyRez advanced) | STYLE `0x2AD` | AMOUNT `0x2AF`, LOW GAIN `0x2B3` | — |
| GUITAR FX | BODYREZ SHELF EQ (BodyRez advanced) (grid page) | — | LOW FREQ `0x033`, HI FREQ `0x051`, LOW GAIN `0x2B3`, HI GAIN `0x2B7` | — |
| GUITAR FX | BODYREZ PARAMETRIC EQ (BodyRez advanced) (grid page) | — | PARA 1 FREQ `0x032`, PARA 2 FREQ `0x050`, PARA 1 WIDTH `0x038`, PARA 2 WIDTH `0x056`, PARA 1 GAIN `0x2B1`, PARA 2 GAIN `0x2B5` | — |
| GUITAR FX | BODYREZ COMPRESSOR (BodyRez advanced) (grid page) | — | THRESHOLD `0x2BB`, RATIO `0x32A`, ATTACK `0x32D`, RELEASE `0x32E`, MAKEUP GAIN `0x2BD`, AMBIENCE `0x2B9` | — |

Advanced pages (shown by the remote behind its "Advanced pages" checkbox; how the unit opens them is not known):

| Menu | Page | Cells |
|---|---|---|
| VOCAL FX (advanced) | HARMONY | SCALE `0x078`, HUMANIZE `0x071`, PORTAMENTO `0x093` |
| VOCAL FX (advanced) | DELAY | FILTER `0x17D`, TEMPO `0x158` |
| VOCAL FX (advanced) | TRANSDUCER | ROUTING `0x24A`, GAIN `0x24F`, GATE THRESHOLD `0x05E` |
| GUITAR FX (advanced) | GUITAR REVERB | REVERB PRE DLY `0x1A3` |
| GUITAR FX (advanced) | GUITAR DELAY | TEMPO `0x158`, FILTER `0x17E` |
| GUITAR FX (advanced) | GUITAR uMOD | DEPTH `0x12C` |
