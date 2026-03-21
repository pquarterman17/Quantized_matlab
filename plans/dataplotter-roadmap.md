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

### Remaining
- [ ] Lazy Q-space: move Qx/Qz out of parser, compute on demand (~2 hr)
- [ ] Cache 2D graphics handle for faster replot (~30 min)
- [ ] Chunked file reading for XRDML > 20 MB (~1 day, highest risk)
- [ ] Stride-based decimation for very large maps (~1 hr)
- [ ] "Clear 2D Matrix" button to reclaim memory (~1 hr)
- [ ] Optional `single` precision for intensity matrices
