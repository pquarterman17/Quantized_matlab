# OriginPro Feature Gap Analysis

Comparison of OriginPro features vs the MATLAB toolkit + Python port. All high and
medium priority items are implemented in MATLAB. Remaining work is Python porting
and one low-priority niche item.

**Status:** Active
**Created:** 2026-03
**Updated:** 2026-04-11

---

## Context

### How the pieces fit together
Features span multiple packages: `+fitting/` (curve fitting, bands, diagnostics, surface,
global, ODR), `+plotting/` (box/violin, ternary, polar contour), `+utilities/` (ANOVA, PCA,
filter rows), and `+bosonPlotter/` (undo manager, spreadsheet popup, toolbar config, drag
columns). Each MATLAB feature needs a corresponding Python implementation in
`thin_film_toolkit/`.

### Data / control flow
```
OriginPro feature → MATLAB implementation (+fitting, +plotting, +utilities, +bosonPlotter)
                  → Python port (thin_film_toolkit backend → FastAPI → Vue 3 frontend)
```

### Dependency map
All Python ports are independent of each other. Each requires the MATLAB implementation
as a reference (all complete).

---

## Tier 1 — High Impact

1. **Fit Comparison Metrics (AIC / BIC / F-test)** — rank competing models objectively
   - [ ] Port to Python (`thin_film_toolkit`)
   - [ ] Test Python implementation

2. **Plot Templates (Save / Reuse Custom Styles)** — user-defined reusable formatting
   - [ ] Port to Python
   - [ ] Test Python implementation

3. **Box / Violin / Bee-Swarm Plots** — distribution visualization
   - [ ] Port to Python
   - [ ] Test Python implementation

4. **Auto-Recalculate on Parameter Change** — reactive data flow
   - [ ] Port to Python
   - [ ] Test Python implementation

5. **Global Parameter Sharing Across Datasets** — shared constraints in curve fitting
   - [ ] Port to Python
   - [ ] Test Python implementation

6. **Confidence / Prediction Bands on Curve Fits** — fit uncertainty visualization
   - [ ] Port to Python
   - [ ] Test Python implementation

## Tier 2 — Medium Impact

7. **Unlimited Undo** — full undo history for all operations
   - [ ] Port to Python
   - [ ] Test Python implementation

8. **Data Filter (Conditional Row Visibility)** — expression-based row filtering
   - [ ] Port to Python
   - [ ] Test Python implementation

9. **Fit Residual Diagnostics** — Q-Q plot, Durbin-Watson, runs test
   - [ ] Port to Python
   - [ ] Test Python implementation

10. **Surface / 3D Fitting** — z = f(x, y) for RSM peak extraction
    - [ ] Port to Python
    - [ ] Test Python implementation

11. **Spreadsheet Popup** — native table view with uispreadsheet
    - [ ] Port to Python
    - [ ] Test Python implementation

12. **Customizable Toolbar** — dynamic toolbar builder, persist to prefs
    - [ ] Port to Python
    - [ ] Test Python implementation

13. **Drag Columns to Plot** — column drag from data table to axes
    - [ ] Port to Python
    - [ ] Test Python implementation

## Tier 3 — Nice-to-Have

14. **Column formulas (auto-recalc)** — MATLAB done (`+dataWorkspace/FormulaEngine.m`), Python pending
    - [ ] Design approach for Python
    - [ ] Implement

---

## Already at parity (MATLAB)

Multi-format import, curve fitting (23 models), peak analysis, batch processing,
publication figures (journal templates, vector export), data corrections, session
save/load, spreadsheet view, dataset math, export (CSV/Excel/PDF/SVG), waterfall
plots, 2D contour/heatmap. Plus features Origin lacks: EM viewer, EELS/EDS
quantification, materials property calculator, neutron reflectometry.

---

## Completed

- ~~**Fit Comparison Metrics**~~ (MATLAB) — `+fitting/fitCompare.m`, 28 tests
- ~~**Plot Templates**~~ (MATLAB) — `+plotting/plotTemplate.m` + `templateDialog.m`, 7 tests
- ~~**Box / Violin / Bee-Swarm**~~ (MATLAB) — `+plotting/boxViolinSwarm.m`, 12 tests
- ~~**Auto-Recalculate**~~ (MATLAB) — "Auto" checkbox + debounced timer in BosonPlotter
- ~~**Global Parameter Sharing**~~ (MATLAB) — `+fitting/globalCurveFit.m`, 18 assertions
- ~~**Confidence / Prediction Bands**~~ (MATLAB) — `+fitting/fitBands.m`, 8 tests
- ~~**Unlimited Undo**~~ (MATLAB) — `+bosonPlotter/UndoManager.m`, 9 tests
- ~~**Data Filter**~~ (MATLAB) — `+bosonPlotter/filterRows.m`, 15 tests
- ~~**Fit Residual Diagnostics**~~ (MATLAB) — `+fitting/residualDiagnostics.m`, 9 tests
- ~~**Surface / 3D Fitting**~~ (MATLAB) — `+fitting/surfaceFit.m` + 7 models, 15 tests
- ~~**Spreadsheet Popup**~~ (MATLAB) — `+bosonPlotter/spreadsheetPopup.m`, 11 tests
- ~~**Customizable Toolbar**~~ (MATLAB) — `+bosonPlotter/toolbarConfig.m`, 7 tests
- ~~**Drag Columns to Plot**~~ (MATLAB) — column drag to X/Y/Y2 drop zones, 7 tests
- ~~**Ternary plots**~~ (MATLAB) — `+plotting/ternaryPlot.m`, 10 tests
- ~~**Polar contour plots**~~ (MATLAB) — `+plotting/polarContour.m`, 10 tests
- ~~**ANOVA**~~ (MATLAB) — `+utilities/anova1.m`, 8 tests
- ~~**PCA**~~ (MATLAB) — `+utilities/pcaAnalysis.m`, 10 tests
- ~~**ODR**~~ (MATLAB) — `+fitting/odrFit.m`, 10 tests (13x more accurate than OLS)
- ~~**Column formulas**~~ (MATLAB, 2026-04-12) — `+dataWorkspace/FormulaEngine.m`, col() references, circular ref detection, auto-recalc on data change
