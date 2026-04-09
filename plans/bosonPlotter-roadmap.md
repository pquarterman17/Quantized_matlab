# BosonPlotter Roadmap

Remaining improvements for `BosonPlotter.m` and the `+bosonPlotter/` package.

---

## GUI Layout: Corrections Panel ✅ DONE

Collapsible sections, merged rows, min-width constraints, and label
truncation fix all implemented. Column 1 widened from 72→80px.

---

## XRR / Neutron Reflectivity Fitting ✅ IMPLEMENTED

Core engine + GUI dialog + fitting. Phase 4 polish (live sim, resolution
smearing, superlattice shortcuts) deferred as nice-to-have.

Files: `+fitting/parrattRefl.m`, `sldProfile.m`, `reflSLDPresets.m`,
`+bosonPlotter/reflFitting.m`. 19 tests passing.

---

## Scripting / Macro Recorder ✅ INTEGRATED

Record button in status bar, wired to file load, corrections, and CSV
export. Toggle record/stop, export as .m script. API: `getMacroLog`,
`startMacroRecord`, `stopMacroRecord`.

---

## Performance: Large 2D Data ✅ COMPLETE

All 11 planned optimizations landed. No open items; kept for historical reference.

- [x] Skip corrections copy for 2D datasets
- [x] Eliminate redundant meshgrid in draw2DMap
- [x] File size warning before import (>50 MB)
- [x] Pre-allocate scan arrays in importXRDML
- [x] Memory usage display after loading
- [x] Lazy Q-space: wavelength stored at parse, Qx/Qz computed on first 2D activation (2026-03-26)
- [x] Cache 2D graphics handle for faster heatmap replot (skip cla on 2D→2D) (2026-03-26)
- [x] Chunked file reading: early xml release + per-block cleanup in importXRDML (2026-03-26)
- [x] Stride-based decimation for maps > 2000px per axis (2026-03-26)
- [x] "Clear 2D Matrix" button to discard intensity + Qx/Qz and reclaim RAM (2026-03-26)
- [x] Optional single precision checkbox for intensity matrices (½ RAM) (2026-03-26)
