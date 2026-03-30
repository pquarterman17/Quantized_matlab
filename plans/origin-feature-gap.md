# OriginPro Feature Gap Analysis

Comparison of OriginPro features vs thin_film_toolkit (MATLAB + Python port).
Focused on features relevant to thin film / magnetometry / XRD / EM workflows.

## Already at Parity

Multi-format import, curve fitting (23 models), peak analysis, batch processing,
publication figures (journal templates, vector export), data corrections, session
save/load, spreadsheet view, dataset math, export (CSV/Excel/PDF/SVG), waterfall
plots, 2D contour/heatmap. Plus features Origin lacks: EM viewer, EELS/EDS
quantification, materials property calculator, neutron reflectometry.

---

## High Priority (Relevant to Our Users)

### 1. Fit Comparison Metrics (AIC / BIC / F-test)
- [x] Implemented (MATLAB) — `+fitting/fitCompare.m`, Compare Models button in curveFitting
- [x] Tested (MATLAB) — `tests/fitting/test_fitCompare.m` (28 tests)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Ranks competing models by AIC, BIC, F-test, adjusted R².
**Us:** R² and RMSE only. No way to objectively pick between e.g. Gaussian vs Voigt.
**Effort:** Small — compute AIC/BIC from residuals + parameter count.

### 2. Plot Templates (Save / Reuse Custom Styles)
- [x] Implemented (MATLAB) — `+plotting/plotTemplate.m`, `+plotting/templateDialog.m`, wired into figureBuilder
- [x] Tested (MATLAB) — `tests/plotting/test_plotTemplate.m` (7 tests)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Save axis formatting, colors, labels as reusable templates. Apply to new data.
**Us:** Journal presets only (APS, Nature, ACS, Elsevier). No user-defined templates.
**Effort:** Medium — serialize axis props, line styles, colors to .mat/.json, apply on load.

### 3. Box / Violin / Bee-Swarm Plots
- [x] Implemented (MATLAB) — `+plotting/boxViolinSwarm.m`, new type in figureBuilder
- [x] Tested (MATLAB) — `tests/plotting/test_boxViolinSwarm.m` (12 tests)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Built-in statistical plot types for distribution visualization.
**Us:** None. Useful for showing measurement spread across samples or conditions.
**Effort:** Medium — box plot is straightforward; violin needs kernel density estimation.

### 4. Auto-Recalculate on Parameter Change
- [x] Implemented (MATLAB) — "Auto" checkbox + debounced timer in DataPlotter.m
- [x] Tested (MATLAB) — manual verification (timer-based, hard to automate)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Change a correction or fit parameter, downstream plots update live.
**Us:** Manual "Apply" button required. No reactive data flow.
**Effort:** Large — requires event-driven architecture or listener callbacks on all widgets.

### 5. Global Parameter Sharing Across Arbitrary Datasets
- [x] Implemented (MATLAB) — `+fitting/globalCurveFit.m`, Global Fit button in curveFitting with constraint UI
- [x] Tested (MATLAB) — `tests/fitting/test_globalCurveFit.m` (18 assertions across 8 groups)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Share fit parameters (e.g., peak width) across multiple datasets in one fit.
**Us:** Global fit exists but only for XRD multi-peak. Not generalized.
**Effort:** Medium — extend fitting engine to accept shared parameter constraints.

### 6. Confidence / Prediction Bands on Curve Fits
- [x] Implemented (MATLAB) — `+fitting/fitBands.m`, Show Bands checkbox in curveFitting
- [x] Tested (MATLAB) — `tests/fitting/test_fitBands.m` (8 tests)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Overlay confidence and prediction intervals on fitted curves.
**Us:** `confidenceBand` utility exists for repeat datasets, but not for fit uncertainty.
**Effort:** Small — compute from Jacobian covariance matrix after fit.

---

## Medium Priority

### 7. Unlimited Undo
- [x] Implemented (MATLAB) — `+dataplotter/UndoManager.m` handle class, full wiring in DataPlotter.m with Redo button + Ctrl+Z/Y
- [x] Tested (MATLAB) — `tests/gui/test_undoManager.m` (9 tests)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Full undo history for all operations.
**Us:** 5-level undo, corrections only. No undo for peak edits, figure changes, etc.
**Effort:** Medium — generalize undo stack to all state-mutating operations.

### 8. Data Filter (Conditional Row Visibility)
- [x] Implemented (MATLAB) — `+dataplotter/filterRows.m` (recursive descent parser), filter bar in DataPlotter
- [x] Tested (MATLAB) — `tests/gui/test_filterRows.m` (15 tests)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Show/hide rows by column condition (e.g., "T > 300 K").
**Us:** Manual mask selection only. No expression-based filtering.
**Effort:** Small — parse simple conditions, apply as mask.

### 9. Fit Residual Diagnostics
- [x] Implemented (MATLAB) — `+fitting/residualDiagnostics.m`, Diagnostics button in curveFitting
- [x] Tested (MATLAB) — `tests/fitting/test_residualDiagnostics.m` (9 tests)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Residual plots, Q-Q plots, Durbin-Watson, runs test.
**Us:** Residual overlay only. No statistical diagnostics.
**Effort:** Small-Medium — add Q-Q plot and basic residual statistics.

### 10. Surface / 3D Fitting
- [x] Implemented (MATLAB) — `+fitting/surfaceFit.m`, `surfaceModels.m` (7 models), `surfaceFitDialog.m`, wired into 2D map panel
- [x] Tested (MATLAB) — `tests/fitting/test_surfaceFit.m` (15 tests)
- [ ] Implemented (Python)
- [ ] Tested (Python)

**Origin:** Fit z = f(x, y) surfaces to 2D data (e.g., RSM peak fitting).
**Us:** No 2D fitting. Would be useful for RSM substrate/film peak extraction.
**Effort:** Medium — extend curveFit to 2D, add 2D model catalog.

---

## Additional Features Implemented (Beyond Original Gap List)

### 11. Spreadsheet Popup (Native MATLAB Table)
- [x] Implemented (MATLAB) — `+dataplotter/spreadsheetPopup.m` with uispreadsheet (R2025a+) / uitable fallback
- [x] Tested (MATLAB) — `tests/gui/test_spreadsheetPopup.m` (11 tests)

### 12. Customizable Toolbar
- [x] Implemented (MATLAB) — `+dataplotter/toolbarConfig.m`, dynamic toolbar builder, persist to prefdir
- [x] Tested (MATLAB) — `tests/gui/test_toolbarConfig.m` (7 tests)

### 13. Drag Columns to Plot
- [x] Implemented (MATLAB) — Column drag from data table to axes (X/Y/Y2 drop zones)
- [x] Tested (MATLAB) — `tests/gui/test_dragToPlot.m` (7 tests)

---

## Low Priority (Less Relevant to Our Domain)

- [ ] Ternary plots — useful for phase diagrams but niche
- [ ] Polar contour plots — rare in thin film work
- [ ] ANOVA / t-tests / non-parametric tests — stats package territory
- [ ] PCA / cluster analysis — niche for our users
- [ ] Column formulas (auto-recalc) — partially addressed by spreadsheet popup
- [ ] ODR (orthogonal distance regression) — niche but useful for errorbar-heavy data

---

## Status

**All high and medium priority items are implemented in MATLAB.** Only Python ports and low-priority niche features remain.
