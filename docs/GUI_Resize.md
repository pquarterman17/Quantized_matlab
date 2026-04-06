# GUI Layout & Resize Guide

All code references are to `Boson.m` unless stated otherwise.

The GUI uses MATLAB's `uigridlayout` nesting — all positions are controlled by grid properties, not pixel coordinates.

## The three knobs

### 1. `RowHeight` / `ColumnWidth` — controls size of each slot

```matlab
% Fixed pixels, flexible proportions, or mixed:
'RowHeight', {130, '1x', '2x'}    % row 1 = 130px, rows 2-3 split remaining 1:2
'ColumnWidth', {350, 220, '7x'}   % two fixed cols + one flexible
```

### 2. `Padding` — space between the grid edge and its parent container

```matlab
'Padding', [left bottom right top]   % e.g. [6 6 6 6]
```

### 3. `RowSpacing` / `ColumnSpacing` — gaps between adjacent cells

```matlab
'RowSpacing', 6, 'ColumnSpacing', 10
```

---

## Grid definitions — where to edit

Every grid is defined by a single `uigridlayout(...)` call. Change the
`RowHeight` or `ColumnWidth` arrays on that line to resize.

| Grid | Line | Size | Current Heights / Widths |
|------|------|------|--------------------------|
| `rootGL` | **314** | 3×1 | `{130, '1x', '1x'}` |
| `tbGL` | **322** | 3×2 | rows `{26, 26, '1x'}`, cols `{'1x','1x'}` |
| `contentGL` | **373** | 1×2 | cols `{215, '1x'}` |
| `ctrlGL` | **394** | 10×1 | `{26,2,'1x',2,'1x',2,34,24,26,24}` |
| `y2GL` | **410** | 2×1 | rows `{20,'1x'}`, cols `{'1x'}` |
| `styleGL` | **426** | 2×3 | rows `{20,'1x'}`, cols `{'1x','1x','1x'}` |
| `logChkGL` | **459** | 1×4 | cols `{'1x','1x','1x','1x'}` |
| `wfGL` | **478** | 1×3 | cols `{'1x',50,55}` |
| `analysisGL` | **536** | 1×4 | cols `{350, 220, '7x', '3x'}` |
| `corrGL` | **557** | 16×4 | rows `{24×8, 28, 28, 24, 20, 24, 24, 0, 0}`, cols `{70,'1x',88,'1x'}` |
| `axLimGL` | **816** | 11×4 | rows `{22,26,26,0,28, 22,22,22,22,22,22}`, cols `{40,'1x','1x','1x'}` |
| `fmtGL` | **1006** | 1×6 | cols `{16,'1x',16,'1x',0,0}` |
| `saveGL` | **1036** | 13×2 | rows `{26,28,32×10,28}`, cols `{'1x','1x'}` |
| `peakGL` | **1161** | 1×2 | cols `{'1x','2x'}` |
| `peakBtnGL` | **1176** | 14×1 | rows `{20,24,24,24,24,20,24,'1x',20,24,0,24,24,0}` |
| `minSepGL` | **1276** | 6×2 | rows `{24,24,24,24,24,22}`, cols `{'1x','1x'}` |

---

## Grid hierarchy

```
rootGL [3×1]                                          ← line 314
├── Row 1 (130 px)  → tbGL [3×2]                      ← line 322
│   ├── Row 1: btnBrowse, btnRemoveDS
│   ├── Row 2: efDatasetSearch, btnMerge
│   └── Row 3: lbDatasets (spans cols 1-2)
├── Row 2 ('1x')    → contentGL [1×2]                 ← line 373
│   ├── Col 1 (215 px) → ctrlPanel → ctrlGL [10×1]    ← line 394
│   │   ├── Row 1  (26px)  ddX (X-axis dropdown)
│   │   ├── Row 2  (2px)   spacer
│   │   ├── Row 3  ('1x')  lbY (Y-axis listbox)
│   │   ├── Row 4  (2px)   spacer
│   │   ├── Row 5  ('1x')  y2GL [2×1]                 ← line 410
│   │   │   ├── Row 1: lblY2 ("Right Y-axis:")
│   │   │   └── Row 2: lbY2 (listbox)
│   │   ├── Row 6  (2px)   spacer
│   │   ├── Row 7  (34px)  styleGL [2×3]              ← line 426
│   │   │   ├── Row 1: lblColormap, ddColormap
│   │   │   └── Row 2: btnLine, btnScatter, btnLine+Pts
│   │   ├── Row 8  (24px)  logChkGL [1×4]             ← line 459
│   │   │   └── [Log X | Log Y | Log R | Cts/s]
│   │   ├── Row 9  (26px)  wfGL [1×3]                 ← line 478
│   │   │   └── [Waterfall | spacing | Replot]
│   │   └── Row 10 (24px)  cbAnnotationMode
│   └── Col 2 ('1x')   → axPanel → ax (preview axes)
└── Row 3 ('1x')    → analysisGL [1×4]                ← line 536
    ├── Col 1 (350 px)  → corrPanel → corrGL [16×4]    ← line 557
    ├── Col 2 (220 px)  → axLimPanel → axLimGL [11×4]  ← line 816
    │   └── Row 11: fmtGL [1×6]                        ← line 1006
    ├── Col 3 ('7x')    → peakPanel → peakGL [1×2]     ← line 1161
    │   ├── Col 1: peakBtnGL [14×1]                    ← line 1176
    │   │   └── Row 8 area: minSepGL [6×2]             ← line 1276
    │   └── Col 2: peakTable (uitable)
    └── Col 4 ('3x')    → savePanel → saveGL [13×2]    ← line 1036
```

---

## How to resize panels — step by step

### Make the controls panel wider

Edit **line 373** — change the first value in `ColumnWidth`:

```matlab
% line 373 — contentGL ColumnWidth
'ColumnWidth', {250, '1x'}   % was {215, '1x'}
```

### Give the analysis row more space than the preview row

Edit **line 314** — change the `RowHeight` proportions:

```matlab
% line 314 — rootGL RowHeight
'RowHeight', {130, '1x', '2x'}   % analysis row gets 2× the content row
```

### Make corrections panel wider

Edit **line 536** — change the first value in `ColumnWidth`:

```matlab
% line 536 — analysisGL ColumnWidth
'ColumnWidth', {400, 250, '7x', '3x'}   % was {350, 220, '7x', '3x'}
```

**Also update the runtime overrides** — the function `applyParserAnalysisConfig`
overwrites `analysisGL.ColumnWidth` at runtime for different parser types.
Search for all occurrences (lines **2208, 2244, 2273, 2303, 2346**) and update
the first element to match:

```matlab
% lines 2208, 2244, 2273, 2303, 2346 — runtime ColumnWidth overrides
analysisGL.ColumnWidth = {appData.corrPanelWidth, ...};
%                         ^^^^^^^^^^^^^^^^^^^^^^
% This reads from appData.corrPanelWidth (default set at line ~250).
% Change the default there, or change the fixed values on these lines.
```

### Adjust row proportions in the controls panel

Edit **line 394** — change the `RowHeight` array:

```matlab
% line 394 — ctrlGL RowHeight
% Give Y listbox 3× the space of Y2 listbox:
'RowHeight', {26,2,'3x',2,'1x',2,34,24,26,24}
%                  ^^^       ^^^
```

### Change the toolbar height

Edit **line 314** — change the first value:

```matlab
% line 314 — rootGL RowHeight
'RowHeight', {100, '1x', '1x'}   % was 130, shrink toolbar
```

**Also update the resize handler** — interactive panel resize resets this value.
Search for `rootGL.RowHeight` at **line 7616**:

```matlab
% line 7616 — interactive resize applies a new toolbar height
rootGL.RowHeight = {newH, '3x', '2x'};
```

### Make the axes & appearance panel wider

Edit **line 536** — change the second value in `ColumnWidth`:

```matlab
% line 536 — analysisGL ColumnWidth
'ColumnWidth', {350, 280, '7x', '3x'}   % was {350, 220, ...}
```

And update the runtime overrides at **lines 2208, 2303** where `appData.axLimPanelWidth` is used.

### Show/hide the peak tools column

This is toggled at runtime by `applyParserAnalysisConfig()`.
The key lines are:

```matlab
% line 2208 — XRD mode: show peak tools
analysisGL.ColumnWidth = {appData.corrPanelWidth, appData.axLimPanelWidth, '7x', '3x'};

% line 2244 — non-XRD mode: hide peak tools (col 3 = 0)
analysisGL.ColumnWidth = {appData.corrPanelWidth, '7x', 0, '3x'};
```

### Adjust correction rows visibility

Rows 7-8 and 15-16 of `corrGL` swap between generic and XRD-specific controls.
Edited at runtime in `applyParserAnalysisConfig()`:

```matlab
% lines 2215-2216 — generic mode: show BG file row, hide asymmetry
corrGL.RowHeight{7}  = 24;  corrGL.RowHeight{8}  = 24;
corrGL.RowHeight{15} = 0;   corrGL.RowHeight{16} = 0;

% lines 2311-2312 — neutron mode: hide BG file, show asymmetry
corrGL.RowHeight{7}  = 0;   corrGL.RowHeight{8}  = 0;
corrGL.RowHeight{15} = 24;  corrGL.RowHeight{16} = 24;
```

### Show/hide Y2 axis controls

The right-axis limit row and format columns are toggled when Y2 channels are
selected. Key lines:

```matlab
% lines 2135-2137 — in updateControlsForActiveDataset()
axLimGL.RowHeight{4}  = 26 * y2Active;    % 0 = hidden, 26 = shown
fmtGL.ColumnWidth{5}  = guiTernary(y2Active, 20,   0);
fmtGL.ColumnWidth{6}  = guiTernary(y2Active, '1x', 0);

% lines 6605-6607 — in drawToAxes() (same logic, keeps in sync)
axLimGL.RowHeight{4} = 26 * hasY2;
fmtGL.ColumnWidth{5} = guiTernary(hasY2, 20,   0);
fmtGL.ColumnWidth{6} = guiTernary(hasY2, '1x', 0);
```

---

## Runtime layout overrides — complete reference

These are all the places where grid sizes are changed **after** initial
construction. If you change a grid's initial definition, check whether any of
these runtime overrides will clobber your change.

| What | Lines | Trigger |
|------|-------|---------|
| `rootGL.RowHeight` | 314 (init), **7616** (resize toolbar), **7627** (resize analysis) | Interactive panel drag |
| `contentGL.ColumnWidth` | 373 (init), **5803** (layout settings) | `layoutSettingsGUI` apply |
| `analysisGL.ColumnWidth` | 536 (init), **2208, 2244, 2273, 2303, 2346** (parser config), **7635-7666** (panel resize) | Dataset load / panel drag |
| `corrGL.RowHeight{7,8,15,16}` | 557 (init), **2215-2216, 2246-2247, 2275-2276, 2311-2312, 2321-2322** | Parser type switch |
| `axLimGL.RowHeight{4}` | 816 (init), **2135, 6605** | Y2 axis toggle |
| `fmtGL.ColumnWidth{5,6}` | 1006 (init), **2136-2137, 6606-6607** | Y2 axis toggle |

---

## Live tweaking trick

While the GUI is running, use the MATLAB command window to adjust values instantly:

```matlab
% Get the root grid:
fig = gcf;
root = fig.Children(1);   % the root grid
root.RowHeight{1} = 100;  % shrink toolbar row

% Navigate to a nested grid:
% Use fig.Children or findobj to locate the grid, then modify directly.
% E.g., to find analysisGL:
panels = findobj(fig, 'Type', 'uigridlayout');
% Inspect each: panels(k).RowHeight, panels(k).ColumnWidth
```

Changes apply instantly — experiment until satisfied, then update the source
code at the line numbers listed above.

---

## Key concepts

- **`'1x'` / `'2x'` / `'3x'`** — flexible proportions (like CSS `flex: 1` / `flex: 2`). They split the remaining space after fixed-pixel rows/cols are allocated.
- **Fixed pixel values** (e.g. `130`, `350`) — absolute size that doesn't change with window resize.
- **`0`** — hides a row/column completely (used for conditional show/hide of Y2 axis controls, peak tools, etc.).
- **`.Layout.Row` / `.Layout.Column`** — assigns a widget to a specific grid cell. Use `[1 2]` to span multiple cells.
- You never set absolute x/y positions — everything flows from the grid definition.
- **Runtime overrides** — several functions (`applyParserAnalysisConfig`, `drawToAxes`, interactive resize handlers) modify grid sizes at runtime. If your change to the initial definition gets ignored, check the runtime override table above.
