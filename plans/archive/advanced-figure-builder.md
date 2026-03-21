# Advanced Figure Builder — Plan

**Status:** All Tiers Complete (2026-03-19)
**Location:** Popup launched from DataPlotter Tools strip → "Figures..."
**Architecture:** Standalone `uifigure` dialog that reads `appData.datasets` from the parent GUI and generates publication-ready MATLAB `figure` objects. No changes to the main preview axes.

---

## Tier 1 — Core (implement first)

### 1.1 Asymmetric Grid Layout
Allow panels to span multiple rows/columns (e.g., one wide panel on top, two narrow below). Extends the existing multi-panel builder with per-panel row/column span controls.

- [x]Row span and column span spinners per panel card
- [x]`tiledlayout` with `nexttile(tileNum, [rowSpan colSpan])`
- [x]Validate that spans don't overlap

### 1.2 Waterfall with Edge Labels
Stacked offset plot with per-trace labels placed along the right edge (no legend box). Auto-spacing computed from Y range.

- [x]Auto-spacing: `0.8 × median(max(Y) - min(Y))` across traces
- [x]Manual spacing override field
- [x]Right-edge labels: `text()` at `(xMax, yOffset)` for each trace
- [x]Log-mode: multiplicative offset option
- [x]Optional: vertical grouping by parser type or user tag

### 1.3 Overlay + Residual (Stacked)
Two-panel layout: top panel shows overlaid data, bottom panel shows the pointwise difference (residuals). Useful for before/after correction comparison or fit quality.

- [x]Dataset A and Dataset B selectors (dropdowns)
- [x]Y channel selector
- [x]Top panel: both traces overlaid
- [x]Bottom panel: `A - B` (interpolated to common X grid if needed)
- [x]Shared X axis via `linkaxes`
- [x]Optional: residual as percentage `(A-B)/A × 100`

### 1.4 Difference Curve Panel
Standalone subtraction: pick two datasets + channel, plot the difference. Can be added as an extra row below any panel in multi-panel mode.

- [x]Interpolation to common X grid (`interp1` linear)
- [x]NaN handling for non-overlapping regions
- [x]Dashed zero-line reference

### 1.5 Error Band vs Error Bars Toggle
Per-trace choice of error visualization: shaded band, whisker bars, or none.

- [x]Dropdown per panel: `None | Error Bars | Error Band`
- [x]Auto-detect error columns (reuse `findErrorColumn` logic)
- [x]Shaded band via `fill()` with alpha

---

## Tier 2 — Annotation & Polish

### 2.1 Arrow + Text Annotations
Click-to-place arrows and text labels on the generated figure.

- [x]"Add Annotation" button on the output figure toolbar
- [x]Click start point → drag to end point → text input dialog
- [x]`annotation('textarrow', ...)` with normalized coordinates
- [x]Draggable after placement

### 2.2 Region Shading
Highlight a range on the X or Y axis with a translucent coloured band and optional label.

- [x]X-range shading: `patch([x1 x2 x2 x1], [yMin yMin yMax yMax], color, 'FaceAlpha', 0.15)`
- [x]Label placed at top-center of shaded region
- [x]Multiple regions per panel
- [x]Configurable color and alpha

### 2.3 Reference Lines with Labels
Horizontal or vertical lines at user-specified values, with optional text label.

- [x]H-line: `yline(val, '--', label)`
- [x]V-line: `xline(val, '--', label)`
- [x]Per-active-panel (applied to gca of generated figure)

### 2.4 Peak Label Auto-Placement
Pull peak positions from the active dataset's peak analysis and render labels on the figure.

- [x]Read `ds.peaks` struct array
- [x]Place markers + `(hkl)` or `2θ` labels at peak centers
- [x]Smart vertical offset to avoid overlap
- [x]Option: label with center value, FWHM, or Miller index

---

## Tier 3 — Publication Presets

### 3.1 Journal Templates
One-click figure formatting for common journals.

- [x]APS (Physical Review): 3.375 in single-col, 6.75 in double-col, 8pt font, Times
- [x]Nature: 89 mm single, 183 mm double, 7pt font min, Helvetica/Arial
- [x]ACS (JACS/Nano Letters): 3.25 in single, 7 in double, 8pt Helvetica
- [x]Custom: user-defined width/height/font/family
- [x]Template applies: figure size, font size, font family, tick direction, line widths
- [x]Stored as struct presets; selectable from dropdown

### 3.2 Grayscale / Print-Safe Mode
Convert all colours to distinguishable grayscale or hatched patterns.

- [x]Map colour palette → grayscale via luminance
- [x]Alternate: dashed/dotted/dash-dot line styles per trace
- [x]Marker shape variation (circle, square, triangle, diamond)
- [x]Preview toggle in builder

---

## Tier 4 — Advanced Comparison

### 4.1 Before/After Corrections View
Side-by-side panels: left = raw data, right = corrected data, same axis limits.

- [x]Single dataset selector
- [x]Left panel: `ds.data`, right panel: `ds.corrData`
- [x]Linked axes (both X and Y)
- [x]Shared colormap

### 4.2 Parameter Evolution Strip
Plot a derived quantity (peak position, FWHM, intensity) across multiple loaded files.

- [x]X axis: file index or a metadata field (temperature, field, etc.)
- [x]Y axis: peak center, peak FWHM, peak area, integrated intensity
- [x]Requires peaks to be detected on each dataset
- [x]Scatter + optional connecting line

### 4.3 Broken Axis
Split a single panel with a visual gap to skip a featureless region.

- [x]Two sub-axes side by side with diagonal break marks
- [x]User specifies gap region `[xGapLo, xGapHi]`
- [x]Proportional width allocation based on data range
- [x]Diagonal hatch marks at the break boundary

---

## UI Design

The Advanced Figure Builder is a single `uifigure` (~700×600) with:

```
┌─────────────────────────────────────────────────┐
│ Figure Type:  [Dropdown ▾]                      │
│   Multi-Panel | Waterfall | Overlay+Residual |  │
│   Before/After | Parameter Evolution | Custom   │
├─────────────────────────────────────────────────┤
│                                                 │
│  (Dynamic config area — changes per type)       │
│                                                 │
├─────────────────────────────────────────────────┤
│ ┌─ Global Options ────────────────────────────┐ │
│ │ Template: [None ▾]  Font: [__] pt           │ │
│ │ Error: [None ▾]  Grayscale: [ ]             │ │
│ │ Width: [__] in  Height: [__] in             │ │
│ └─────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────┤
│              [Preview]  [Generate]  [Cancel]    │
└─────────────────────────────────────────────────┘
```

The **Figure Type** dropdown swaps the middle config area.
**Global Options** (template, error style, dimensions) persist across type switches.

---

## Implementation Order

1. Scaffold the popup with figure-type dropdown and global options row
2. Port existing multi-panel config into the popup as the first type
3. Add Waterfall with edge labels
4. Add Overlay + Residual
5. Add journal template presets
6. Add error band/bar toggle
7. Add reference lines and region shading
8. Add before/after view
9. Add parameter evolution
10. Add annotation tools (post-generation)
11. Add broken axis (complex, last)

## Tier 5 — Extended Features (added 2026-03-19)

### 5.1 Dual-Y Axis in Multi-Panel
- [x] Y2 (right axis) listbox per panel card
- [x] `yyaxis(tAx, 'right')` rendering via `plotTraces`
- [x] Independent color allocation for right-axis traces

### 5.2 Normalized Overlay
- [x] Dataset multi-select with single Y channel
- [x] Normalization: Peak (0-1), Range (0-1), Z-score, Area
- [x] X alignment: None, Peak center, X offset
- [x] Grayscale + line-style variation support

### 5.3 Inset Zoom (post-generation tool)
- [x] Prompt for X/Y range + corner position (tl/tr/bl/br)
- [x] Copy line objects from main axes into inset
- [x] Draw dashed rectangle on main axes indicating zoomed region
- [x] Inherit Y scale from parent axes

### 5.4 Quick Plot Script
- [x] `scripts.quickPlot` — auto-import + type-aware plotting from command line
- [x] Multi-file overlay or subplot layout
- [x] Smart defaults per data type (XRD, magnetometry, reflectometry, SIMS)
- [x] Options: LogY, Normalize, SaveAs, Title, XLabel, YLabel, Layout, Theme

---

## Files Modified

- `DataPlotter.m` — "Figures..." button + `onAdvancedFigureBuilder` nested function (~800 lines)
- `+scripts/quickPlot.m` — new file, command-line plotting script (~250 lines)
- `CLAUDE.md` — documented quickPlot and figure builder
