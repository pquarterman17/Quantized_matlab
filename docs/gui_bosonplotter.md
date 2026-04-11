# BosonPlotter — Detailed Feature Reference

> Extracted from CLAUDE.md. For core conventions and quick-start workflows, see the main [CLAUDE.md](../CLAUDE.md).

## Dataset Struct (GUI Internal)

Each loaded file is stored as a `ds` struct inside `appData.datasets`:
- `.data`, `.corrData` — raw and corrected data structs
- `.xOff`, `.yOff`, `.bgSlope`, `.bgInt` — per-dataset correction values
- `.peaks` — struct array of detected/fitted peaks
- `.axLims` — per-dataset axis limit strings (persisted across dataset switches)

## Advanced Figure Builder

Launched from BosonPlotter → Tools → **Figures...** button. Opens a popup with figure types:

| Type | Description |
|------|-------------|
| Multi-Panel | NxM grid with per-panel datasets/channels, row/col span, dual Y axis |
| Quick Grid | One dataset per cell, auto-tiled |
| Waterfall | Stacked offset traces with right-edge labels |
| Overlay + Residual | Two-panel: overlay + A-B difference |
| Normalized Overlay | Peak/range/z-score/area normalization with optional X alignment |
| Before / After | Side-by-side raw vs corrected |
| Parameter Evolution | Track peak metrics across datasets |
| Broken Axis | Split X or Y axis with gap and diagonal break marks |
| Confidence Band | Mean±std or median±IQR shaded band from N repeat datasets |
| Contour / Heatmap | XYZ data as filled contour, contour lines, pseudocolor, or 3D surface |

Global options: journal templates (APS/Nature/ACS), error style (bars/band), grayscale mode (line-style + marker cycling), font, dimensions.

Post-generation toolbar on every output figure: H/V reference lines, shaded regions, text/arrow annotations, peak labels, inset zoom. Multi-Panel and Quick Grid figures also get a linked cursor (vertical line tracking across all panels on hover).

### Contour / Heatmap Details

- Select dataset, X/Y/Z columns from dropdowns
- 4 plot styles: Filled contour, Contour lines (labeled), Pseudocolor (pcolor), Surface (3D)
- 10 colormaps (parula, viridis, plasma, inferno, hot, jet, turbo, gray, bone, copper)
- Scattered XYZ data auto-gridded via `scatteredInterpolant` (or `griddata` fallback)
- 3D Surface mode enables `rotate3d` for interactive viewing

### Asymmetric Error Bars

The Figure Builder auto-detects separate upper/lower error columns (e.g., `dR+`/`dR-`, `Rerr+`/`Rerr-`) and renders as asymmetric error bars or asymmetric shaded bands.

## Advanced BosonPlotter Tools

| Tool | Button | Description |
|------|--------|-------------|
| Data Cursor | `Cursor` | Click to snap to nearest point (x,y); click again for delta (dx,dy) |
| Dataset Math | `Math...` | Combine two datasets: A±B, A×B, A/B, (A-B)/(A+B) with interpolation |
| Multi-Dataset Overlay | `Overlay` checkbox | Select all datasets and overlay on same axes with unified legend |
| Plot Templates | `Templates...` | Save/load axis limits, corrections, labels, scale as reusable .mat presets |
| Batch Figure Export | `Batch Figs...` | Export every loaded dataset as individual PNG/PDF/SVG/EPS with journal template |
| Advanced Analysis | `⚙ Advanced ▾` | Popup menu: Integrate, Dataset Math, Curve Fit, Resample, Column Calculator, Inset Plot, Graph Digitizer |
| Data Table | `▾ Data Table` bar | Collapsible spreadsheet below plot: view/edit all data, mask rows, column stats, Save As (CSV/Excel) |

## Data Table (Spreadsheet View)

Collapsible panel below the plot axes. Toggle via the "▾ Data Table" bar.

- **Full cell editing** — click any cell to modify values; edits stored in a working copy (original data untouched)
- **Units row** — displays column units from the parser
- **Column stats** — row count, column count, masked point count in the toolbar
- **Data masking** — select rows → "Mask Sel." to exclude from plot/analysis; "Unmask All" to restore
- **Save As** — export working copy (with edits) to new CSV or Excel file; optionally exclude masked rows
- **Auto-refresh** — table updates when switching datasets or applying corrections

## General Curve Fitting (Advanced > Curve Fit...)

Separate dialog with a catalog of built-in models (see [`+fitting/README.md`](../+fitting/README.md) for the canonical list). Summary by category:

| Category | Models |
|----------|--------|
| Linear/Polynomial | Linear, Poly 2, Poly 3 |
| Exponential | Decay, Growth, Double Decay |
| Peak shapes | Gaussian, Lorentzian, Voigt (approx) |
| Other | Power Law, Sigmoid, Arrhenius, Langmuir, Logarithmic, Sqrt |

- **X-range limiting** — fit only within [Xmin, Xmax]
- **Editable initial guesses** — auto-populated from data, user can override
- **Fit engine** — `fminsearch` (Nelder-Mead simplex), 10k eval limit
- **Results** — R², RMSE, parameter table, fit curve + residual plot
- **Plot on Main** — overlay fit curve on BosonPlotter axes with equation annotation
- **Copy** — parameters + stats to clipboard

## Graph Digitizer (Advanced > Graph Digitizer...)

Extract data points from a screenshot or image of a published graph:

1. **Load Image** — browse for PNG/JPG/TIFF screenshot of a figure
2. **Set Axes (4 clicks)** — click 4 reference points in order: X1 (left), X2 (right), Y1 (bottom), Y2 (top), then enter their known data values
3. **Collect Points** — click on data points; pixel coords auto-converted to data coords via linear calibration
4. **Export** — save as CSV or load directly into BosonPlotter as a new dataset (auto-sorted by X)

Features: undo last point, clear all, editable point table, orange calibration markers, red crosshair data markers.

## Peak Deconvolution (Visual Decomposition)

After running "Fit All (global)" in the Peak Analysis window, individual peak components are automatically overlaid on the main plot:
- Each peak drawn as a **dashed colored curve** (unique color per peak)
- **Composite model** drawn as solid red line (sum of all peaks + background)
- **Linear background** drawn as dotted gray line
- All overlays tagged `GUIPeakDecomp` and cleared on next plot redraw
- Also callable programmatically via `onShowDecomposition()`

## Transform Options (Corrections Panel)

The derivative dropdown includes 5 options: `None`, `dY/dX`, `d²Y/dX²`, `∫Y dx` (cumulative integral), `dlog/dlog` (log derivative for power-law detection).

## 2D Map Colormap Editor

For 2D XRDML area-detector data, the map panel includes: intensity scale (Linear/Log₁₀), colorbar min/max range override, 10 colormaps (parula, viridis, plasma, inferno, hot, jet, turbo, gray, bone, copper).

## Peak Analysis Window

`peakFig` is a separate `uifigure` containing the peak table, fitting controls, export buttons, and advanced crystallography tools. It opens automatically after peak detection (`onAutoPeak`) or on the first manual peak add. The "Peaks..." button in the corrections panel opens it on demand. Closing the window just hides it (`Visible='off'`); peaks and markers on the main axes are unaffected.

- `appData.peakMode` tracks the current mode: `'xrd'`, `'reflectometry'`, or `'none'`.
- `configurePeakWindowForMode(mode)` shows/hides mode-specific buttons in the peak window.
- `showPeakWindow()` refreshes the table and brings the window to front.
- The main GUI's `analysisGL` column 3 is now width 0 by default (only used for `map2DPanel` in 2D mode).

## GUI Development Notes

- `cla()` alone does not remove graphics objects with `HandleVisibility='off'` (peak markers). Use `delete(ax.Children)` before `cla()` to clear all children.
- Each dataset in `appData.datasets` stores its own axis limits (`ds.axLims`) so zoom levels are restored when switching between loaded files.
