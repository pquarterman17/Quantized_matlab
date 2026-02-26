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

- [ ] **Batch-apply corrections to all datasets** — "Apply to All" button copies the
  current X/Y offset, BG slope/intercept, and smoothing settings to every loaded dataset.

- [ ] **Batch export CSV** — "Export All CSV" button in the Save panel writes one
  `_corrected.csv` per loaded dataset using their auto-generated paths.

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

- [ ] **Colormap for parameter series** — when many datasets are loaded (e.g. 20
  temperature-series XRD scans), auto-assign colors from a chosen colormap (jet,
  viridis, etc.) rather than the fixed 10-color palette.

- [/] **Second Y-axis** — checkbox to plot a selected channel on a right-side Y-axis
  with its own scale. Useful for overlaying moment and temperature vs time in PPMS data.

- [ ] **Annotation tool** — click on the plot to drop a text label (peak index, sample
  name, etc.) that follows data coordinates. Store in `ds.annotations`; re-render in
  `drawToAxes`.


---

### Workflow / UX

- [x] **Drag-and-drop file loading** — use `fig.DropFcn` (MATLAB R2023a+) to accept
  files dragged from Explorer. Add a version guard; fall back gracefully on older MATLAB.

- [ ] **Undo for corrections** — one-level undo: snapshot `ds.corrData`, offsets, etc.
  into `ds.undoState` before "Apply Corrections"; an "Undo" button restores it.

- [x] **Dataset reorder (drag in list)** — allow dragging rows in `lbDatasets` to
  reorder datasets, affecting legend order and waterfall offset order.

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

### Bugs
- [x] **Drag and Drop Files** — fixed: added `AllowDrop=true` (R2024a+) and corrected string-array normalisation in `onDropFiles`

