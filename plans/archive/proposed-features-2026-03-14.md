# Proposed Features — thin_film_toolkit_matlab

Generated 2026-03-14. Organized by impact and effort.

---

## High Impact, Moderate Effort

### - [ ] 1. Dataset comparison / difference plots
When comparing two XRD scans (e.g. before and after annealing), a "Difference" mode that
plots `dataset_A − dataset_B` (with interpolation for mismatched x-grids) would immediately
surface subtle peak shifts, new phases, or intensity changes. This is standard in commercial
XRD software (HighScore, EVA) but missing here.

**Implementation:** A "Compare" button that takes two selected datasets, `interp1`-aligns
them onto a common x-grid, and creates a new synthetic dataset with the residual. Could
also support ratio mode (`A / B`) for normalization use cases.

**Touches:** `BosonPlotter.m` (new button + callback), dataset struct (synthetic flag).

---

### - [ ] 2. Peak database matching (XRD phase identification)
The peak finder already gives center positions and d-spacings. A natural next step is
matching those against a small built-in database of common materials (substrate peaks like
Si, Al₂O₃, SrTiO₃; common metals; simple oxides). Even a 50-entry lookup table with
strongest-line d-spacings would save the round-trip to an external database.

**Implementation:**
- A `.mat` or `.json` reference file in `+data/` with entries: `{name, spaceGroup, a, [{hkl, d, relIntensity}]}`
- "Match Peaks" button in peak panel that finds database entries within a d-spacing tolerance
- Vertical tick marks on the plot with mineral/phase labels at matched positions
- Tolerance slider (default ±0.02 Å)

**Touches:** New `+data/peak_database.mat`, `BosonPlotter.m` (peak panel button + overlay logic).

---

### - [ ] 3. Scripting / macro recorder
Power users will want to apply the same correction pipeline (trim to 20–80°, subtract
linear BG, normalize to peak, export CSV) to 50 files without clicking through the GUI
each time.

**Implementation:** A "Record Macro" toggle that captures GUI actions as a MATLAB script —
essentially generating calls to the programmatic API already built for the test harness.
Each button press appends a line like `api.setCorrection('xOffset', 0.15)` to a script
buffer. "Stop Recording" writes the buffer to a `.m` file. "Run Macro" executes it.

**Touches:** `BosonPlotter.m` (record toggle + script generation), programmatic API
(ensure all correction/export actions are callable).

---

### - [x] 4. Dataset math / arithmetic
Beyond difference plots: let users create derived datasets via expressions like `A / B`,
`A * B`, `log10(A)`, `derivative(A)`. Invaluable for normalizing by a monitor channel,
computing absorbance from transmission, or taking d(M)/d(T) from magnetometry sweeps.

**Implementation:** An expression dialog where datasets are referenced by index or name
(e.g. `D1 / D2`, `diff(D3)`). Parse the expression, apply element-wise operations on
y-values (with `interp1` alignment when x-grids differ), and insert the result as a new
synthetic dataset.

**Touches:** `BosonPlotter.m` (dialog + evaluator), `+utilities/` (safe expression parser).

---

## High Impact, Low Effort

### - [x] 5. Quick-export figure to clipboard
Scientists paste plots into PowerPoint and papers constantly. A "Copy to Clipboard" button
that renders the current axes to a high-DPI bitmap eliminates the screenshot workflow.

**Implementation:** MATLAB supports `print('-clipboard', '-dmeta')` on Windows — a one-liner
wrapped in a button callback. Add a small button (clipboard icon or "Copy Plot") to the
controls panel or toolbar.

**Touches:** `BosonPlotter.m` (one button + 3-line callback).

**Priority:** Trivial to implement, used ~10x/day.

---

### - [x] 6. Cursor readout with peak identification
The existing cursor text shows `(x, y)` on hover. Extend it to also show the nearest
peak's center, d-spacing, and fitted parameters when hovering near a peak marker.

**Implementation:** In `onMouseHover`, after computing `(x, y)`, check distance to each
peak in `ds.peaks`. If within a threshold (e.g. 2× FWHM), append peak info to the cursor
text string: `"2θ = 44.39° | d = 2.039 Å | FWHM = 0.12°"`.

**Touches:** `BosonPlotter.m` (`onMouseHover` callback, ~15 lines).

---

### - [x] 7. Dataset reordering (Move Up / Move Down)
Currently datasets are ordered by load sequence. Drag-to-reorder (or at minimum "Move Up" /
"Move Down" buttons) in the dataset list would let users control the waterfall stacking
order and legend sequence.

**Implementation:** Two small arrow buttons above/below the listbox. Callback swaps elements
in `appData.datasets` and rebuilds the list. Alternatively, support drag-and-drop reorder
within the listbox (MATLAB R2023a+ `lbDatasets.Sortable`).

**Touches:** `BosonPlotter.m` (2 buttons + swap logic in `appData.datasets`).

---

### - [x] 8. Auto-detect scan type from QD headers
The `importQDVSM` parser reads the `[Header]` block but doesn't extract the scan type
(M vs H, M vs T, AC susceptibility). Parsing the `SEQUENCE` or `STARTUPAXIS` header lines
to auto-set axis labels ("Field (Oe)" vs "Temperature (K)") would remove a manual step.

**Implementation:** In `importQDVSM`, scan header lines for `STARTUPAXIS` (contains
"Field" or "Temperature") and store in `metadata.parserSpecific.scanType`. The GUI's
`updateControlsForActiveDataset` can then auto-select the appropriate x-axis column and
set axis labels without user intervention.

**Touches:** `+parser/importQDVSM.m` (header parsing, ~20 lines), `BosonPlotter.m`
(auto-label logic).

---

## Medium Impact, Moderate Effort

### - [x] 9. Pseudo-Voigt peak model
Lorentzian and Gaussian are currently supported. A Pseudo-Voigt (η·L + (1−η)·G with
mixing parameter η) is the standard for XRD line-profile analysis — it captures the
physical reality that real diffraction peaks have both Gaussian (strain broadening) and
Lorentzian (size broadening) components.

**Implementation:** `+utilities/pseudoVoigt.m` already exists. Wire it into the fit engine
by adding `'Pseudo-Voigt'` to `ddFitModel` dropdown items. The fitter needs one extra
free parameter (η ∈ [0, 1]). Display η in the peak table alongside FWHM.

**Touches:** `BosonPlotter.m` (fit engine, peak table column), `+utilities/pseudoVoigt.m`
(verify API matches fit engine expectations).

---

### - [x] 10. Asymmetric peak fitting (split Pearson VII)
Thin-film XRD peaks from textured samples are frequently asymmetric (strain gradients,
composition gradients through film thickness). A split-peak model with independent left/right
width parameters handles this without resorting to multiple overlapping symmetric peaks.

**Implementation:** Split-Pearson VII: left half uses `(w_L, m_L)`, right half uses
`(w_R, m_R)`, joined at the center with continuous value and first derivative. Adds 2 free
parameters per peak. Add `'Split Pearson VII'` to `ddFitModel`. Display asymmetry ratio
`w_L / w_R` in the peak table.

**Touches:** New `+utilities/splitPearsonVII.m`, `BosonPlotter.m` (fit engine, dropdown,
peak table).

---

### - [x] 11. Texture / pole figure visualization
For the 2D XRDML data already parsed, adding a polar projection of integrated intensity vs
chi or phi would support basic texture analysis. The `map2D` struct already has axis vectors —
the missing piece is the angular coordinate transform and a polar heatmap renderer.

**Implementation:** "Pole Figure" button in the 2D map panel. Extract intensity at a chosen
2θ (user picks from a dropdown of detected peaks). Project onto a polar grid using
`polarplot` or `polaraxes` + `pcolor`. Supports stereographic or equal-area projection.

**Touches:** `BosonPlotter.m` (2D panel button + polar rendering), possibly new
`+plotting/poleFigure.m`.

---

### - [x] 12. Temperature / field series animation
When 20+ datasets are loaded from a temperature series, an "Animate" button that cycles
through them as frames (with a time slider) makes it easy to watch phase transitions,
peak shifts, or coercivity evolution.

**Implementation:** A playback bar (Play/Pause/Stop + frame slider) below the axes. A
MATLAB `timer` object calls `drawToAxes` with each dataset sequentially, toggling visibility.
Frame rate control (default 2 fps). "Export GIF" button writes frames to an animated GIF
via `imwrite(..., 'gif', 'WriteMode', 'append')`.

**Touches:** `BosonPlotter.m` (playback UI + timer callbacks), `+plotting/` (optional
GIF export helper).

---

## Lower Effort, Polish Items

### - [x] 13. Keyboard shortcuts
Power users want `Ctrl+S` (save session), `Ctrl+Z` (undo), `Delete` (remove dataset),
`←`/`→` (switch active dataset), `Ctrl+E` (export CSV), `Space` (toggle visibility).

**Implementation:** Set `fig.KeyPressFcn` to a dispatcher that checks `eventdata.Modifier`
and `eventdata.Key`, then calls the matching existing callback. ~30 lines for the
dispatcher + a help tooltip listing available shortcuts.

**Touches:** `BosonPlotter.m` (one new nested function + one `fig.KeyPressFcn` assignment).

---

### - [x] 14. Dark mode / theme toggle
The `+styles/default.m` theme exists but only controls plot styling. A dark-mode option
that also themes the uifigure panels (dark gray backgrounds, light text) would reduce eye
strain during long analysis sessions and make plots pop.

**Implementation:** A `+styles/dark.m` theme struct with panel/text/axes colors. A
"Theme" dropdown in the controls panel. On change, recursively update
`BackgroundColor`/`FontColor` on all uigridlayout panels and widgets. MATLAB R2022a+
supports `uistyle` for listbox styling.

**Touches:** New `+styles/dark.m`, `BosonPlotter.m` (theme dropdown + recursive updater).

---

### - [x] 15. Export to Origin project file (.opju)
`+utilities/toOrigin.m` exists for Origin-compatible CSV export. Extending to write actual
`.opju` binary format (via the published OriginLab C spec) would save Origin users the
import step entirely.

**Alternative (simpler):** Export as a LabTalk script (`.ogs`) that Origin can execute to
auto-import, set column designations, format axes, and build the graph. More maintainable
than binary format writing.

**Touches:** `+utilities/toOrigin.m` (extend or new `+utilities/exportOriginScript.m`).

---

### - [x] 16. Unit-aware axis labels
When the parser extracts units (now robust with units-row and inline-unit detection), the
GUI could auto-format axis labels as `"Temperature (°C)"` or `"Q (Å⁻¹)"` without the user
typing them manually.

**Implementation:** In `drawToAxes`, after selecting x/y columns, read
`data.metadata.xColumnName`, `xColumnUnit`, and channel `labels`/`units`. Auto-generate
`xlabel` string as `"<name> (<unit>)"` if both are non-empty. Only apply when the user
hasn't manually set a custom label (check `efCustomXLabel` / `efCustomYLabel` for non-empty
override).

**Touches:** `BosonPlotter.m` (`drawToAxes`, ~10 lines).

---

## Recently Implemented (2026-03-14)

The following 23 features were implemented in the BosonPlotter in a single session:

| # | Feature | Widget / Function | Location |
|---|---------|-------------------|----------|
| 1 | Legend toggle | `cbShowLegend` checkbox | axLimGL row 12 |
| 2 | Live preview corrections | `cbLivePreview` checkbox | corrGL row 20 |
| 3 | Derivative computation | `ddDerivative` dropdown (None/dY/dX/d²Y/dX²) | corrGL row 19 |
| 4 | Auto error bars | `findErrorColumn()` heuristic + `errorbar()` | drawToAxes |
| 5 | SNIP baseline estimation | `btnEstimateBaseline` + `onEstimateBaseline()` | corrGL row 18 |
| 6 | Multi-level undo (5-deep) | `ds.undoStack` cell array | onApplyCorrections |
| 7 | Figure dimension fields | `efFigWidth`/`efFigHeight` | axLimGL row 13 |
| 8 | Dataset hover tooltip | File path + parser + point count | onSelectDataset |
| 9 | File loading progress | `fig.Pointer='watch'` + per-file status | loadFilePaths |
| 10 | Copy peaks to clipboard | `btnCopyPeaksClip` + tab-delimited output | peakBtnGL row 8 |
| 11 | Reference lines (H/V) | `btnAddHLine`/`btnAddVLine`/`btnClearRefLines` | axLimGL row 12 |
| 12 | Batch export folder picker | `uigetdir()` at start of batch export | onBatchExportCSV |
| 13 | Dataset context menu | Duplicate/Hide/Set as BG/Move Up/Move Down | cmDatasets |
| 14 | Session backward-compat | `sessionDefaults` struct with all new fields | onLoadSession |
| 15 | Resample dataset | `btnResample` + `onResampleDataset()` | saveGL row 19 |
| 16 | Column calculator | `btnColumnCalc` + `onColumnCalculator()` | saveGL row 20 |
| 17 | Error band plot style | `btnStyleErrorBand` (shaded fill bands) | styleGL row 3 col 4 |
| 18 | Inset plot | `btnInset` + `onCreateInset()` | saveGL row 21 |
| 19 | Overwrite warning | `isfile()` check before session save | saveSessionDirect |
| 20 | Eval whitelist | Regex validation before `eval()` | onDatasetMath |
| 21 | BG interpolation method | `ddBGInterp` (linear/pchip/spline/nearest) | corrGL row 17 |
| 22 | MATLAB .fig export | Added to `ddFigFormat` items | saveGL row 11 |
| 23 | Dirty indicator | `markCorrectionsDirty()` highlights Apply button | corrections pipeline |

---

## Still Open

| Rank | Feature | Status |
|------|---------|--------|
| 1 | #1 Dataset comparison / difference plots | Open |
| 2 | #2 Peak database matching | Open |
| 3 | #3 Scripting / macro recorder | Open |
