# DataPlotter Roadmap

Remaining improvements for `DataPlotter.m` and the `+dataplotter/` package.

---

## GUI Layout: Corrections Panel ✅ DONE

Collapsible sections, merged rows, min-width constraints, and label
truncation fix all implemented. Column 1 widened from 72→80px.

---

## XRR / Neutron Reflectivity Fitting

**Source:** xrr-reflectivity-fitting.md
**Priority:** Medium-high — fills a major gap for reflectometry users
**Effort:** Large (4 phases)

### Phase 1: Core engine
- `+fitting/parrattRefl.m` — Parratt recursion for specular reflectivity
- `+fitting/sldProfile.m` — SLD depth profile from layer stack
- `+fitting/reflSLDPresets.m` — material SLD lookup table (Si, SiO₂, Au, Ni, ...)
- Unit tests against known analytical solutions

### Phase 2: GUI dialog
- "Fit R(Q)" button in DataPlotter peak panel advanced row
- Layer table (editable): thickness, SLD real, SLD imag, roughness
- Material preset dropdown per layer
- Simulate button → overlay model R(Q) on data

### Phase 3: Fitting
- Parameter assembly from layer table → vector for `fitting.curveFit`
- Log-space objective function (reflectivity spans orders of magnitude)
- Parameter bounds from physical constraints

### Phase 4: Polish
- Live simulation (update plot as user edits layers)
- Residuals subplot
- Export layer table
- Resolution smearing (optional)
- Superlattice repeat shortcuts

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

### Remaining (ordered by priority)
- [ ] Lazy Q-space: move Qx/Qz out of parser, compute on demand (~2 hr)
- [ ] File size warning before import (~15 min)
- [ ] Cache 2D graphics handle for faster replot (~30 min)
- [ ] Pre-allocate scan arrays in importXRDML (~30 min)
- [ ] Memory usage display in status bar (~30 min)
- [ ] Chunked file reading for XRDML > 20 MB (~1 day, highest risk)
- [ ] Stride-based decimation for very large maps (~1 hr)
- [ ] "Clear 2D Matrix" button to reclaim memory (~1 hr)
- [ ] Optional `single` precision for intensity matrices
