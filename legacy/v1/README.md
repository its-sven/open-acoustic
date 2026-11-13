# legacy/v1: first-pass analysis (superseded, decode is WRONG)

These files come from the first hand analysis. Their 8-in-7 decode is wrong in two ways, so the `PA-*.unpacked.bin` files are **not** valid firmware images:
1. They treat the 1-byte subcommand at the start of each payload as a flag byte, which shifts every group by one byte.
2. They read the flag bits LSB-first; the correct order is MSB-first.

Use `tools/tch_unpack.py` and `data/sections/` instead (see `docs/ANALYSIS.md` §0). The files are kept for history only.

`legacy/tools/` holds two superseded scripts:
- `dsp_records_2word.py` assumed 2-word record headers; the real headers have 3 words.
- `params_stride8.py` used a descriptor stride of 8; the correct stride is 16, so the names it prints are wrong.
