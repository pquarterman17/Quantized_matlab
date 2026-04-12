# Codebase Organization Roadmap

Structural improvements for maintainability — monolith decomposition, documentation coverage, test organization.

**Status:** Active
**Created:** 2026-03
**Updated:** 2026-04-11

---

## Context

### How the pieces fit together
`BosonPlotter.m` is a ~13,659-line single-function file containing ~317 nested functions.
The `+bosonPlotter/` package holds extracted subsystems that are called from the parent via
function handles or direct package calls. Extraction reduces the parent's line count and
makes subsystems independently testable.

`FermiViewer.m` (~12k lines) follows the same nested-function pattern but is better
organized internally with clear section dividers — lower priority for extraction.

### Data / control flow
```
BosonPlotter.m (parent)
  ├── closure state (appData, widget handles)
  ├── calls → +bosonPlotter/renderPlot.m (via context struct)
  ├── calls → +bosonPlotter/peakCallbacks.m (via context struct)
  ├── calls → +bosonPlotter/curveFitting.m, figureBuilder.m, ...
  └── ~1,500 lines of layout construction (creates 200+ widgets)
```

### Dependency map
- Items 1-2 are independent
- Item 1 (further extraction) is the long pole — each extraction makes other work easier

---

## Tier 1 — High Impact

1. **Continue `+bosonPlotter/` extraction — drive parent below 8k lines**
   - [ ] Extract table model (edit + units sync, ~360 lines at ~11140-11500)
   - [ ] Extract neutron sibling propagation (~45 lines at 5602-5647)
   - [ ] Extract undo state helpers (~60 call sites, deduplicate into `captureUndoState.m`)
   - [ ] Extract hysteresis dialog (~200 lines at 12430+)
   - [ ] Extract batch fit / global fit / track peak (~50 lines at 12581-12628)

## Tier 2 — Medium Impact

2. **Documentation coverage — package READMEs**
   - [ ] Rewrite `+bosonPlotter/README.md` (5/37 functions documented)
   - [ ] Expand `+plotting/README.md` (3/15 documented)
   - [ ] Expand `+utilities/README.md` (16/38 documented)
   - [ ] Expand `+parser/README.md` (15/27 documented)
   - [ ] Add `template` + `palette` to `+styles/README.md` (2/4 documented)
   - [ ] Expand `+imaging/README.md` (~46/52 documented)
   - [ ] Add 3 missing entries to `+scripts/README.md` (4/7 documented)

---

## Completed

- ~~**Extract renderPlot.m**~~ (2026-04-10) — ~902 lines, main 1D/2D rendering loop
- ~~**Extract peakCallbacks.m**~~ (2026-04-10) — ~978 lines, 14 callbacks via context struct
- ~~**Extract drawOverlays.m**~~ (2026-03-26) — peak markers, fit curves, annotations
- ~~**Extract peakTools.m**~~ (2026-03-26) — lattice refinement, phase matching, FFT thickness dialogs
- ~~**Extract buildPeakWindow.m + buildMap2DPanel.m**~~ (2026-03-26) — widget construction
- ~~**Merge session dialogs into sessionManager.m**~~ (2026-03-26)
- ~~**Extract colorMaps.m + safeEvalMathExpr.m**~~ (2026-03) — colormap generation + expression parser
- ~~**Previously extracted subsystems**~~ — curveFitting, figureBuilder, graphDigitizer, roiAnalysis, multiPanel, actionLog, datasetGroups, applyCorrections, correctionParams, reflFitting
- ~~**Create `+fitting/README.md`**~~ (2026-04-11) — 19 functions + 23-model catalog
- ~~**Test organization**~~ — clean subdirectories: parser/, gui/, imaging/, calc/, batch/, fitting/
- ~~**`+calc/README.md`**~~ — 11 sub-packages documented
- ~~**Per-package READMEs created**~~ — +parser/, +imaging/, +calc/, +utilities/, +scripts/
