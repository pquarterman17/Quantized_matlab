impl# TODO — thin_film_toolkit_matlab

## dataImportGUI.m — Improvements & Features

### High impact, moderate effort


- [x] **Waterfall / stacked-offset plot mode** — toggle that adds a configurable vertical
  offset between datasets when plotting; common for comparing XRD scans in a temperature
  or thickness series. Needs a "stack spacing" field and per-dataset auto-offset in
  `drawToAxes`.

- [/] **Session save / load** — serialize full `appData` (datasets, corrections, peaks,
  axis limits) to a `.mat` file and reload it. Lets the user close MATLAB and resume
  exactly where they left off. **Implemented, needs testing.**

- [/] **Data trim / crop** — click-drag to select an x-range to keep (discard noisy scan
  edges). Reuse the rubber-band box mechanism; store `ds.xTrimMin` / `ds.xTrimMax` and
  apply early in the corrections pipeline. **Implemented, needs testing.**

- [/] **Normalization control** — dropdown in corrections panel: None / Peak (max=1) /
  Area (integral=1) / Z-score. `utilities.normalize` already exists; just wire it into
  the GUI corrections pipeline. **Implemented, needs testing.**

---

### High impact, low effort

- [/] **Show legend name / parser badge in dataset list** — `rebuildDatasetList` currently
  shows `[N] filename.ext`. When `ds.legendName` is set, display it instead of the
  filename; always prefix with a short type tag (`[VSM]`, `[XRD]`, `[CSV]`) derived from
  `ds.parserName`. Makes mixed-type sessions immediately scannable without clicking each entry.
  **Implemented, needs testing.**

- [/] **Batch-apply corrections to all datasets** — "Apply to All" button copies the
  current X/Y offset, BG slope/intercept, and smoothing settings to every loaded dataset.
  **Implemented, needs testing.**

- [/] **Batch export CSV** — "Export All CSV" button in the Save panel writes one
  `_corrected.csv` per loaded dataset using their auto-generated paths.
  **Implemented, needs testing.**

- [x] **Copy plot to clipboard** — button that copies the current plot as an image
  (e.g. `print(fig, '-clipboard', '-dbitmap')`). **Already implemented.**

---

### Analysis enhancements

- [/] **Region statistics readout** — when drawing the BG-fit box, display mean, std,
  min, max, and centroid of the enclosed data in a tooltip or status label. Reuses
  the existing `onBGMouseUp` selection logic. **Implemented, needs testing.**

- [/] **Peak area (integrated intensity)** — add an Area column to the peak table,
  calculated as the analytical integral of the fitted Lorentzian/Gaussian. Directly
  useful for XRD film-thickness / crystallite-size estimates. **Implemented, needs testing.**

- [/] **Multi-peak simultaneous fit** — "Fit All Together" option builds a
  sum-of-Lorentzians/Gaussians model and fits it in one `fminsearch` call to properly
  handle overlapping peaks. **Implemented, needs testing.**

---

### Visualization

- [/] **Colormap for parameter series** — when many datasets are loaded (e.g. 20
  temperature-series XRD scans), auto-assign colors from a chosen colormap (jet,
  viridis, etc.) rather than the fixed 10-color palette. **Needs testing in GUI.**

- [/] **Second Y-axis** — checkbox to plot a selected channel on a right-side Y-axis
  with its own scale. Useful for overlaying moment and temperature vs time in PPMS data.

- [/] **Annotation tool** — click on the plot to drop a text label (peak index, sample
  name, etc.) that follows data coordinates. Store in `ds.annotations`; re-render in
  `drawToAxes`. **Needs testing in GUI.**
- [x] **Clean up Analysis & Corrections Section** - there are analysis options that only apply to certain data types but are displayed for all. For example, spin asymmetry should only be shown in Neutron Refelectomery analysis
    - [x] Enable other data corrections for Neutron Reflectomery, but remove: subtract BG and smoothing from this data type
    - [x] For Neutron reflectomery corrections, apply R and Q offset equally to all polarizations with same data file name
    - [x] Remove spin asymmetry from all but neutron reflectomery data types in 'analysis and corrections'
    -
- [x] **axis settings and plot appearance** looks section of GUI takes up a lot of horozontal space, input boxes can be narrower to make entire box narrower.
- [ ] **Control panel to set GUI arrangement defaults** create a separate GUI to control the size and arrangement of plot and analysis GUI. activate it with a separate GUI control. Use same color styles


---

### Workflow / UX

- [x] **Drag-and-drop file loading** — use `fig.DropFcn` (MATLAB R2023a+) to accept
  files dragged from Explorer. Add a version guard; fall back gracefully on older MATLAB.

- [/] **Undo for corrections** — one-level undo: snapshot `ds.corrData`, offsets, etc.
  into `ds.undoState` before "Apply Corrections"; an "Undo" button restores it.
  **Needs testing in GUI.**

- [x] **Dataset reorder (drag in list)** — allow dragging rows in `lbDatasets` to
  reorder datasets, affecting legend order and waterfall offset order.

- [/] **"Set active dataset as background" button** — one-click to copy the active
  dataset into `appData.bgDataset`, instead of requiring a separate file-browse. Eliminates
  the extra step when the reference measurement is already loaded as a dataset.
  **Implemented, needs testing.**

- [/] **Dataset visibility toggle** — add a `ds.visible` boolean (default `true`) and a
  "Hide/Show" button (or checkbox) per dataset. The `for di = 1:nDS` plot loop already
  supports per-dataset skipping; just add `if ~ds.visible, continue; end`. Useful when
  10+ files are loaded and you want to isolate a subset without removing the others.
  **Implemented, needs testing.**

- [/] **Multi-select and merge datasets** — allow `lbDatasets` to support multi-select
  (Ctrl+click / Shift+click) with a "Merge Selected" button that concatenates selected
  datasets into a single combined dataset. Useful for aggregating repeated measurements
  or temperature-sweep segments. **Implemented, needs testing.**

- [/] **Filter/search box above dataset list** — small text field that filters `lbDatasets`
  items by filename or legend name as you type. Rebuild `Items` from a filtered subset on
  each keystroke; restore full list on clear. Most useful with 20+ loaded files.
  **Implemented, needs testing.**

---

### Export

- [/] **Publication-ready direct save** — "Save Figure..." button that calls
  `exportgraphics` directly on the GUI axes with user-selectable format (PNG/TIFF 300 dpi,
  PDF/SVG vector). Avoids the current Export-to-Figure → manual-save workflow.
  **Implemented, needs testing.**

- [/] **Peak report export to Excel** — "Export Peaks XLSX" button writes an `.xlsx`
  file with one sheet per dataset containing peak fit parameters (Center, FWHM, Height, Area, Status).
  **Implemented, needs testing.**

---



### File Handling

- [/] **NCNR Neutron Data Files** — support file formats in `+parser/file_examples_implementation/NCNR/` directory:
  - [x] **`.refl` files** (reductus reduced data) — `importNCNRRefl.m` reads JSON headers + space-delimited data; auto-detects CANDOR (polychromatic) vs PBR (monochromatic) variants
  - [x] **`.pnr` files** (PNR export with spin-flip/non-spin-flip variants) — `importNCNRPNR.m` reads tab-delimited NSF/SF/combined variants
  - [x] **`.datA`/`.datB`/`.datC`/`.datD` files** (refl1d fit output with polarization encoding) — `importNCNRDat.m` extracts polarization from extension (++/+-/-+/--)
  - [x] **Updated `importAuto.m`** — added dispatch cases for `.refl`, `.pnr`, and `.data`/`.datb`/`.datc`/`.datd` (lowercase due to `lower()` conversion)
  - [x] **All parsers tested** — smoke tests pass for example files; integrated into test_parsers.m
  - **Note:** Fitted/model `.dat` files (slabs, steps, profile) not yet parsed; focus was raw measurement data

- [ ] **Additional File Support** — support file types added into '+test_datasets' on a rolling basis

---

## New Parsers — File Format Support

### Tier 1 — XRD (XML-based, no example files needed)

- [/] **`importXRDML.m`** — PANalytical / Malvern Empyrean `.xrdml` format. Well-documented
  XML schema; parse with `readstruct` or `xmlread`. Extract 2θ array, intensity counts,
  step size, wavelength, and scan metadata.

- [/] **`importBruker.m`** — Bruker D8/D2 `.brml` (ZIP archive containing XML) and legacy
  `.raw` binary (v3 magic `"RAW1.01"`, v4 magic `"RAW "`). Unzip `.brml` with `unzip`,
  then XML parse; binary `.raw` requires manual byte-level reading similar to
  `importRigaku_raw.m`. Single parser dispatches on extension/magic.

---

### Tier 2 — Magnetometry / Transport

- [/] **`importMPMS.m`** — Quantum Design MPMS SQUID `.dat`. Same `[Header]/[Data]`
  block structure as the existing VSM/PPMS parsers; different column layout (DC moment,
  AC susceptibility). Implemented as a thin wrapper around importQDVSM with MPMS-specific
  column shortcuts. **Needs testing with real MPMS files.**

- [/] **`importLakeShore.m`** — Lake Shore VSM / cryostat exports. CSV-style with
  instrument header block. Auto-detects header row and column names; supports temperature/field
  x-axis and moment/susceptibility y-axis with flexible column resolution. **Needs testing with
  real Lake Shore files.**

- [ ] **`importOxford.m`** — Oxford Instruments MagLab exports. Format varies by software
  version (often CSV or custom text). Needs example file to determine structure.

---

### Tier 3 — Spectroscopy

- [ ] **`importRaman.m`** (or extend `importCSV`) — Raman text exports from Horiba LabSpec
  (`.txt`) and Renishaw ASCII export. Wavenumber + intensity columns; likely already
  handled by `importCSV` — verify and add `importAuto` dispatch rule for `.txt` Raman files.

- [ ] **`importOpus.m`** — Bruker OPUS FTIR binary format. Proprietary block structure;
  needs example file. Reference: open-source `brukeropus` Python library for format spec.

- [ ] **`importSPC.m`** — GRAMS/Thermo `.spc` spectral format (Shimadzu UV-Vis and others).
  Published binary spec available; single and multi-file variants.

---

### Bugs
- [x] **Drag and Drop Files** — fixed: added `AllowDrop=true` (R2024a+) and corrected string-array normalisation in `onDropFiles`
- [x] **uieditfield NaN error (line 681)** — fixed: changed trim min/max fields from numeric to text type with empty-string default, added helper functions `nan2str()` and `str2num_trim()`
- [x] **Axes offset from center** — fixed: changed tbGL to span columns [1 2] instead of just [1] to align with content/analysis panels
- [x] **Missing GUI panels** — unclear which panels are missing; most are created but some hidden per data type

---

## Code Quality Scan — 2026-03-07

Comprehensive automated scan of codebase identified **22 issues** across error handling, test coverage, documentation, performance, and architecture. See detailed analysis below.

### Priority 1: Critical Fixes (Est. 17 hrs) — **COMPLETE** ✓

- [x] **#1: Fix dual dispatcher bug** — Created `+parser/resolveParser.m` as centralized dispatcher for extension→parser mapping + magic-byte detection. Updated `importAuto.m` and `guiImport()` to use it. Now `.brml` and `.raw` magic-byte detection work in both paths. **COMPLETE**

- [x] **#2: Add error logging to silent catch blocks** — Added `warning()` calls to silent catch blocks in `importCSV.m`, `importExcel.m`, `importXRDML.m`. Tracks parse failures with counters, emits one warning per operation. **COMPLETE**

- [x] **#3: Create parser edge-case test suite** — Built `test_parsers_edge_cases.m` with 10 comprehensive edge case tests: empty files, truncated binaries, inconsistent columns, multi-range detection, magic-byte detection, datetime parse failures. **COMPLETE**

- [x] **#4: Standardize metadata schema** — Enforced canonical schema across all 14 parsers. All now have: `source` (filepath), `importDate`, `parserName`, `xColumnName`, `xColumnUnit`, `parserSpecific` (instrument-specific). Updated NCNR*, LakeShore, MPMS, XRDML, Bruker parsers. **COMPLETE**

- [x] **#5: Convert multi-range XRD warning to error** — Added `AllowPartialImport` parameter to `importRigaku_raw.m`. Default=false: error on multi-range. True: warn (user opt-in). Updated docstring with Limitations section. **COMPLETE**

### Priority 2: Test & Validation (Est. 12 hrs)

- [ ] **#6: Automated GUI test harness** — No automated tests for 6700-line `dataImportGUI.m` (100+ features). Create test suite using `matlab.uitest` (R2022b+) covering:
  - [ ] Session save/load roundtrip with real data
  - [ ] Batch corrections applied to multiple datasets
  - [ ] Peak fitting with overlapping peaks
  - [ ] Undo/redo state management
  - Impact: Detects regressions in critical workflows (est. 12 hrs)

- [ ] **#7: Round-trip data export tests** — Verify imported data → exported CSV → re-imported data = original. Test in `test_parsers.m`. *Est. 2 hrs*
  - Test: `data1 → writeXRDcsv() → importCSV() → data2 ≈ data1` (tolerance 1e-6)

- [ ] **#8: Batch processing integration tests** — Test `batchConvertXRD.m` and `batchImport.m` with:
  - [ ] Permissions errors (read-only files)
  - [ ] Mixed file types (XRD + CSV in same folder)
  - [ ] Large folders (1000+ files)
  - [ ] Recursion depth limits
  - [ ] Output directory collisions
  - Est. 4 hrs

### Priority 3: Documentation (Est. 6 hrs)

- [ ] **#9: Document GUI state machine** — Create ASCII diagram of callback flow in `dataImportGUI.m` header. Document invariants and valid state transitions. *Est. 2 hrs*

- [ ] **#10: Update TODO.md** — Many features marked `[/]` with vague status. Consolidate into GitHub issues with test results, or add completion checklist. *Est. 1 hr*

- [ ] **#11: Parser-specific metadata** — Document what metadata fields each parser guarantees in `+parser/README.md`. E.g., Rigaku sets `.stepSize`, `.countingTime`, `.startAngle`. *Est. 1 hr*

- [ ] **#12: GUI usage docstring** — Add comprehensive header to `dataImportGUI.m` documenting supported file types, auto-detection heuristics, graceful fallbacks, error handling. *Est. 2 hrs*

### Priority 4: Performance & Architecture (Est. 10 hrs)

- [ ] **#13: Streaming support for large files** — Replace line-by-line parsing in CSV/XRD with vectorized I/O. Use `readmatrix()` with format spec. Pre-allocate arrays. Document file size limits. *Est. 6 hrs*
  - Files: `importCSV.m`, `importQDVSM.m`
  - Current: Fails for >500MB; dynamic cell arrays O(n²)
  - Impact: Handles large datasets without GUI freeze

- [ ] **#14: GUI render caching** — Don't redraw all datasets every cycle. Cache line handles; update only visibility/color/data. *Est. 2 hrs*
  - Impact: Smooth panning/zooming with 50+ datasets

- [ ] **#15: Add progress indication for batch** — Add `waitbar()` or progress text in `xrdConvertGUI.m` conversion loop. *Est. 1 hr*

- [ ] **#16: Replace magic numbers with constants** — In `importRigaku_raw.m` (lines 90-94, 110, 125, 137), define binary offsets as named constants (e.g., `OFFSET_COUNTING_TIME = 2959:2962`). *Est. 1 hr*

### Lower Priority: Architecture Cleanup (Backlog)

- [ ] **#17: Unify column resolution logic** — Extract column shorthand resolution to shared function `+parser/resolveColumnShorthand.m`. Each parser calls this. *Est. 2 hrs*
  - Current: Each parser (QDVSM, LakeShore, MPMS, CSV) defines own semantics

- [ ] **#18: Add version tracking in exports** — Parsers add `data.metadata.parserVersion` field. GUI checks compatibility on load. *Est. 2 hrs*

- [ ] **#19: Add input validation to batch operations** — `xrdConvertGUI.m`: validate selected files exist before conversion starts. *Est. 1 hr*

- [ ] **#20: Boundary checks in array access** — After column name resolution (`importExcel.m`, `importCSV.m`), assert `1 <= idx <= numCols`. *Est. 1 hr*

- [ ] **#21: Document file size limitations** — Add to all parser docstrings tested max file size. E.g., "Tested up to 500MB; larger files may cause memory errors." *Est. 1 hr*

- [ ] **#22: Excel formula error handling** — Document that Excel formula errors (e.g., `#DIV/0!`) become NaN. Add validation warning if >10% of columns are NaN. *Est. 2 hrs*

### Summary

| Category | High | Medium | Total |
|----------|------|--------|-------|
| Code Quality | 7 | 15 | **22** |
| **Est. Effort** | **Priority 1-3: ~35 hrs** | **Priority 4+: ~15 hrs** | **~50 hrs total** |

**Recommended next step:** Start with Priority 1 items (#1, #2, #5) — quick wins that prevent architectural debt and silent failures.


