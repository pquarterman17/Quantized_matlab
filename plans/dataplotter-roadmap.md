# DataPlotter Roadmap

Remaining improvements for `DataPlotter.m` and the `+dataplotter/` package.

---

## GUI Layout: Corrections Panel ✅ DONE

Collapsible sections, merged rows, min-width constraints, and label
truncation fix all implemented. Column 1 widened from 72→80px.

---

## XRR / Neutron Reflectivity Fitting ✅ IMPLEMENTED

Core engine + GUI dialog + fitting. Phase 4 polish (live sim, resolution
smearing, superlattice shortcuts) deferred as nice-to-have.

Files: `+fitting/parrattRefl.m`, `sldProfile.m`, `reflSLDPresets.m`,
`+dataplotter/reflFitting.m`. 19 tests passing.

---

## Scripting / Macro Recorder ✅ INTEGRATED

Record button in status bar, wired to file load, corrections, and CSV
export. Toggle record/stop, export as .m script. API: `getMacroLog`,
`startMacroRecord`, `stopMacroRecord`.

---

## Performance: Large 2D Data

**Source:** large-data-performance.md (2/10 steps done)
**Priority:** Medium — affects users with 100+ MB XRDML files

### Completed
- [x] Skip corrections copy for 2D datasets
- [x] Eliminate redundant meshgrid in draw2DMap
- [x] File size warning before import (>50 MB)
- [x] Pre-allocate scan arrays in importXRDML
- [x] Memory usage display after loading

### Completed (2026-03-26)
- [x] Lazy Q-space: wavelength stored at parse, Qx/Qz computed on first 2D activation
- [x] Cache 2D graphics handle for faster heatmap replot (skip cla on 2D→2D)
- [x] Chunked file reading: early xml string release + per-block cleanup in importXRDML
- [x] Stride-based decimation for maps > 2000px per axis
- [x] "Clear 2D Matrix" button to discard intensity + Qx/Qz and reclaim RAM
- [x] Optional single precision checkbox for intensity matrices (½ RAM)
