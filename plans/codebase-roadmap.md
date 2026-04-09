# Codebase Organization Roadmap

Structural improvements for maintainability.

---

## 1. Break up monolithic GUIs

**BosonPlotter.m:** reduced from ~14,836 to ~14,514 lines by extracting:
- `+bosonPlotter/colorMaps.m` — colormap generation (viridis, plasma, inferno + builtins)
- `+bosonPlotter/safeEvalMathExpr.m` — safe recursive-descent expression parser

Previously extracted subsystems in `+bosonPlotter/`:
- `curveFitting.m`, `figureBuilder.m`, `graphDigitizer.m`
- `roiAnalysis.m`, `multiPanel.m`, `actionLog.m`, `datasetGroups.m`
- `applyCorrections.m`, `correctionParams.m`, `reflFitting.m`

### Extracted (2026-03-26)
- `+bosonPlotter/drawOverlays.m` — peak markers, fit curves, annotations, ref lines (~200 lines from drawToAxes)
- `+bosonPlotter/peakTools.m` — analysis dialogs (lattice refinement, phase matching, FFT thickness, reflectivity FFT, Williamson-Hall)
- `+bosonPlotter/buildPeakWindow.m` — peak window widget construction
- `+bosonPlotter/buildMap2DPanel.m` — 2D map panel widget construction
- Session save/load dialog wrappers merged into `+bosonPlotter/sessionManager.m`

### Remaining candidates (lower priority)
- Core peak detection/fitting callbacks (~1,000 lines) — deep bidirectional coupling with appData + click handlers
- Main GUI layout construction (~1,500 lines) — creates ~200 widget handles captured by closure
- drawToAxes main rendering loop (~900 lines after overlay extraction)

### Fermion.m (~12k lines)
Less urgent — well-organized internally with clear section dividers.

---

## 2. Documentation

- `+calc/README.md` ✅ already exists (11 sub-packages documented)
- CLAUDE.md is ~100 lines (healthy)
- Per-package READMEs exist for: `+parser/`, `+imaging/`, `+calc/`, `+utilities/`, `+scripts/`

---

## 3. Test organization

Already in clean subdirectories: `parser/`, `gui/`, `imaging/`, `calc/`, `batch/`, `fitting/`. No changes needed.
