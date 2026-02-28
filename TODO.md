impl# TODO — thin_film_toolkit_matlab

## dataImportGUI.m — Improvements & Features

### High impact, moderate effort


- [x] **Waterfall / stacked-offset plot mode** — toggle that adds a configurable vertical
  offset between datasets when plotting; common for comparing XRD scans in a temperature
  or thickness series. Needs a "stack spacing" field and per-dataset auto-offset in
  `drawToAxes`.

- [ ] **Session save / load** — serialize full `appData` (datasets, corrections, peaks,
  axis limits) to a `.mat` file and reload it. Lets the user close MATLAB and resume
  exactly where they left off.

- [ ] **Data trim / crop** — click-drag to select an x-range to keep (discard noisy scan
  edges). Reuse the rubber-band box mechanism; store `ds.xTrimMin` / `ds.xTrimMax` and
  apply early in the corrections pipeline.

- [ ] **Normalization control** — dropdown in corrections panel: None / Peak (max=1) /
  Area (integral=1) / Z-score. `utilities.normalize` already exists; just wire it into
  the GUI corrections pipeline.

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

- [ ] **Copy plot to clipboard** — button that copies the current plot as an image
  (e.g. `print(fig, '-clipboard', '-dbitmap')`).

---

### Analysis enhancements

- [ ] **Region statistics readout** — when drawing the BG-fit box, display mean, std,
  min, max, and centroid of the enclosed data in a tooltip or status label. Reuses
  the existing `onBGMouseUp` selection logic.

- [ ] **Peak area (integrated intensity)** — add an Area column to the peak table,
  calculated as the analytical integral of the fitted Lorentzian/Gaussian. Directly
  useful for XRD film-thickness / crystallite-size estimates.

- [ ] **Multi-peak simultaneous fit** — "Fit All Together" option builds a
  sum-of-Lorentzians/Gaussians model and fits it in one `lsqcurvefit` call to properly
  handle overlapping peaks.

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

- [ ] **Multi-select and merge datasets** — allow `lbDatasets` to support multi-select
  (Ctrl+click / Shift+click) with a "Merge Selected" button that concatenates selected
  datasets into a single combined dataset. Useful for aggregating repeated measurements
  or temperature-sweep segments. Merged dataset stores `.sourceDatasetIndices` for traceability.

- [ ] **Filter/search box above dataset list** — small text field that filters `lbDatasets`
  items by filename or legend name as you type. Rebuild `Items` from a filtered subset on
  each keystroke; restore full list on clear. Most useful with 20+ loaded files.

---

### Export

- [ ] **Publication-ready direct save** — "Save Figure..." button that calls
  `exportgraphics` directly on the GUI axes with user-selectable format (PNG 300 dpi,
  PDF vector, SVG). Avoids the current Export-to-Figure → manual-save workflow.

- [ ] **Peak report export to Excel** — extend "Export Summary CSV" to write an `.xlsx`
  file with one sheet per dataset, including fit parameters, R², and fitted curve values
  for plotting in Origin / Excel.

---



### File Handling

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

