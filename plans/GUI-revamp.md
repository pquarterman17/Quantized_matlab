# GUI Revamp — Analysis & Corrections Panel Improvements

## Context

The Analysis & Corrections panels in `DataPlotter.m` have grown organically to 20 rows (~570px), overflowing on 1080p displays (~450px available). Controls lack visual grouping, the primary "Apply" action is buried mid-panel, labels truncate in narrow columns, and button colors are inconsistent. This plan addresses these issues in 5 discrete phases.

**Target resolutions:** 1080p (primary) and 1440p
**User workflow context:** Live Preview is typically ON; BG file subtraction is uncommon; correction style switching is rare; W-H Plot / Refine Lattice are advanced/secondary features.

---

## Phase 1: Min-Width Constraints for Panel Resize

**Goal:** Prevent panels from being dragged too narrow to be usable.
**Risk:** Low
**Effort:** Small (~30 min)

### Changes

Add constants near `appData` initialization (~line 269):

```matlab
MIN_CORR_W     = 280;   % corrections panel minimum width (px)
MIN_AXLIM_W    = 180;   % axes & appearance panel minimum
MIN_PEAK_W     = 200;   % peak analysis panel minimum
MIN_SAVE_W     = 120;   % save/export panel minimum
MIN_PREVIEW_H  = 150;   % preview row (rootGL row 2) minimum height
MIN_ANALYSIS_H = 250;   % analysis row (rootGL row 3) minimum height
```

Update `onPanelResizeMove()` (~line 8999-9053):

| Border | Current constraint | New constraint |
|--------|-------------------|----------------|
| `v_col12` | `max(200, min(newW, 600))` | `max(MIN_CORR_W, min(newW, 600))` |
| `v_col23` (XRD) | none explicit | `max(MIN_AXLIM_W, min(newW, 500))` |
| `v_col23` (non-XRD) | none explicit | `max(MIN_SAVE_W, min(newW, 400))` |
| `v_col34` | none explicit | `max(MIN_PEAK_W, min(newW, 700))` |
| `h_row12` | `max(100, ...)` | `max(MIN_PREVIEW_H, ...)` |
| `h_row23` | `max(200, ...)` | `max(MIN_ANALYSIS_H, ...)` |

### Files
- `DataPlotter.m`: lines ~269 (constants), ~8999-9053 (`onPanelResizeMove`)

### Testing
- Drag all panel borders to extremes; verify they stop at minimums
- `runAllTests(Group="gui")`

---

## Phase 2: Corrections Panel Restructure (corrGL)

**Goal:** Reduce from 20 rows / ~570px to 16 rows / ~442px. Add collapsible sections. Fix label truncation.
**Risk:** High (row renumbering affects many functions)
**Effort:** Large (~3h)

### Current Layout (20 rows)

```
Row 1:  Style dropdown
Row 2:  X Offset       | BG Slope
Row 3:  Y Offset       | BG Intercept
Row 4:  Smooth checkbox + window + method
Row 5:  Fit BG / Est Y (generic) OR Y Translate / Auto Peak / Manual Peak (XRD)
Row 6:  BG Order       | Remove Peak (XRD)
Row 7:  BG File picker
Row 8:  Subtract BG + Clear BG
Row 9:  Apply Corrections | Reset | Show Raw
Row 10: Apply to All   | Undo
Row 11: Hide Dataset
Row 12: Region Stats
Row 13: Normalize
Row 14: Trim X
Row 15: Spin Asymmetry      (neutron only, RowHeight=0 otherwise)
Row 16: Asymmetry formula    (neutron only, RowHeight=0 otherwise)
Row 17: BG Interp method
Row 18: Estimate Baseline (SNIP)
Row 19: Derivative
Row 20: Live Preview
```

### New Layout (18 rows, 2 hidden for asymmetry)

```
Row 1:  Style dropdown (cols 1-3)    | Live Preview checkbox (col 4)
Row 2:  [HEADER] "▼ Offsets & Background" (collapsible, default OPEN)
Row 3:    X Offset       | BG Slope
Row 4:    Y Offset       | BG Intercept
Row 5:    BG Order       | BG Interp method        ← merged from old rows 6+17
Row 6:    Interactive tools (Fit BG/Est Y  OR  Y Translate/Auto Peak/etc.)
Row 7:  [HEADER] "▼ Processing" (collapsible, default OPEN)
Row 8:    Smooth checkbox + window + method
Row 9:    Normalize      | Derivative               ← merged from old rows 13+19
Row 10:   Trim X min     | Trim X max
Row 11:   Estimate Baseline (SNIP)
Row 12: [HEADER] "▶ BG File Subtraction" (collapsible, default COLLAPSED)
Row 13:   BG File path + Load / Use Active          ← hidden by default
Row 14:   Subtract BG + Clear BG                    ← hidden by default
Row 15: Spin Asymmetry       (RowHeight=0 unless neutron)
Row 16: Asymmetry formula    (RowHeight=0 unless neutron)
Row 17: Apply Corrections | Reset | Show Raw
Row 18: Apply to All | Undo | Hide Dataset           ← merged from old rows 10+11
```

### Space Budget

| Element | Height |
|---------|--------|
| 3 section headers @ 16px | 48px |
| 10 content rows @ 24px | 240px |
| 1 action row @ 28px | 28px |
| 1 secondary action row @ 24px | 24px |
| Row spacing 4px × 17 gaps | 68px |
| Padding | 12px |
| Panel title bar | ~30px |
| **Total** | **~450px** (fits 1080p) |

### Specific Changes

#### 2a. Widen column 1: 70 → 80px
- Fixes label truncation for "BG Intercept:", "2θ Offset (°):", "Spin Asymmetry:"
- **Edit:** `corrGL` ColumnWidth definition (~line 637)

#### 2b. Merge Live Preview into row 1
- `ddCorrStyle` spans cols 2-3; `cbLivePreview` moves to col 4
- Row 20 eliminated
- **Edit:** Lines ~643-654 (row 1), ~926 (live preview creation)

#### 2c. Add collapsible section headers
- New `uilabel` widgets with `ButtonDownFcn` callbacks
- Down triangle `▼` (char 9660) = expanded; right triangle `▶` (char 9654) = collapsed
- State stored in `appData.sectionCollapsed.offsets`, `.processing`, `.bgFile`
- BG File section defaults collapsed (`appData.sectionCollapsed.bgFile = true`)

New function `onToggleSection(sectionName, headerLabel, childRows, defaultHeights)`:
```matlab
function onToggleSection(sectionName, headerLabel, childRows, defaultHeights)
    collapsed = ~appData.sectionCollapsed.(sectionName);
    appData.sectionCollapsed.(sectionName) = collapsed;
    if collapsed
        headerLabel.Text = regexprep(headerLabel.Text, char(9660), char(9654));
        for k = 1:numel(childRows)
            corrGL.RowHeight{childRows(k)} = 0;
        end
    else
        headerLabel.Text = regexprep(headerLabel.Text, char(9654), char(9660));
        for k = 1:numel(childRows)
            corrGL.RowHeight{childRows(k)} = defaultHeights(k);
        end
    end
end
```

#### 2d. Merge BG Order + BG Interp into one row (new row 5)
- BG Order label+dropdown cols 1-2; BG Interp label+dropdown cols 3-4
- Eliminates old row 17

#### 2e. Merge Normalize + Derivative into one row (new row 9)
- "Norm:" dropdown cols 1-2; "Deriv:" dropdown cols 3-4
- Eliminates old row 19

#### 2f. Merge Apply-to-All + Undo + Hide Dataset into one row (new row 18)
- Apply-to-All col 1-2; Undo col 3; Hide Dataset col 4
- Eliminates old rows 10-11

#### 2g. Move Region Stats to status bar
- `lblRegionStats` repositioned as an overlay or into the status bar label
- Eliminates old row 12

#### 2h. Move Apply/Reset to bottom (rows 17-18)
- Primary actions always visible at the bottom of the panel
- Apply button de-emphasized when Live Preview is ON (see Phase 3)

#### 2i. Named row constants
Replace magic row numbers with constants at top of `applyParserAnalysisConfig()`:

```matlab
ROW_SEC_OFFSETS  = 2;    ROW_XOFF     = 3;   ROW_YOFF       = 4;
ROW_BGORDER      = 5;    ROW_TOOLS    = 6;
ROW_SEC_PROC     = 7;    ROW_SMOOTH   = 8;   ROW_NORM_DERIV = 9;
ROW_TRIM         = 10;   ROW_BASELINE = 11;
ROW_SEC_BGFILE   = 12;   ROW_BGFILE   = 13;  ROW_BGSUBTR    = 14;
ROW_ASYM1        = 15;   ROW_ASYM2    = 16;
ROW_APPLY        = 17;   ROW_ACTIONS  = 18;
```

#### 2j. Update `applyParserAnalysisConfig()`
- Replace all `corrGL.RowHeight{N}` with named constants
- Update all 6 case branches (XRD, VSM, PPMS, Neutron, SIMS, Generic)
- Neutron: show rows 15-16 (asymmetry), hide rows 13-14 (BG file)
- XRD: show tools row with peak buttons, show BG order
- SIMS: disable BG slope/intercept, hide peak panel
- Generic: enable everything except asymmetry

#### 2k. Update `updateControlsForActiveDataset()`
- Adjust any row-height references
- Collapsible section state respected when switching datasets

### Files
- `DataPlotter.m`: lines ~635-930 (corrGL definition), ~2764-3009 (`applyParserAnalysisConfig`), ~2596-2750 (`updateControlsForActiveDataset`), ~926 (live preview), scattered button definitions

### Testing
- `runAllTests(Group="gui")` — must pass
- Manual: load XRD, VSM, neutron, SIMS, generic CSV files; verify panel fits 1080p
- Manual: toggle each collapsible section
- Manual: resize window from 1080p to 1440p; verify no dead space

---

## Phase 3: Button Styling & Color Consistency

**Goal:** Fix gray-text buttons, establish semantic color palette, de-emphasize Apply when Live Preview is on.
**Risk:** Low
**Effort:** Small (~30 min)

### 3a. Semantic Color Palette

Define near line 300:

```matlab
BTN_PRIMARY   = [0.18 0.52 0.18];  % green  — Apply, main actions
BTN_SECONDARY = [0.25 0.28 0.35];  % steel  — export, figure ops
BTN_DANGER    = [0.55 0.15 0.15];  % red    — remove, clear, reset
BTN_TOOL      = [0.28 0.28 0.28];  % gray   — tools, utilities
BTN_ACCENT    = [0.15 0.37 0.63];  % blue   — fit, analysis
```

Audit all ~40 button `BackgroundColor` values and replace ad-hoc colors with palette constants.

### 3b. Fix Gray Text on Secondary Buttons

| Button | Current FontColor | New FontColor |
|--------|------------------|---------------|
| `btnApplyAll` | `[0.4 0.4 0.4]` | `[0.75 0.75 0.75]` |
| `btnUndo` | `[0.6 0.6 0.6]` | `[0.75 0.75 0.75]` |
| `btnToggleVis` | `[0.6 0.6 0.6]` | `[0.75 0.75 0.75]` |

### 3c. Dynamic Apply Button Styling

New helper `updateApplyButtonStyle()`:

```matlab
function updateApplyButtonStyle()
    if cbLivePreview.Value
        btnApply.BackgroundColor = BTN_TOOL;       % dark gray
        btnApply.FontWeight      = 'normal';
        btnApply.Text            = 'Apply (live)';
    else
        btnApply.BackgroundColor = BTN_PRIMARY;     % green
        btnApply.FontWeight      = 'bold';
        btnApply.Text            = 'Apply Corrections';
    end
end
```

Called from: `cbLivePreview` callback, GUI init, `updateControlsForActiveDataset()`.

### Files
- `DataPlotter.m`: lines ~300 (palette), ~714-1383 (button definitions), ~830-843 (font colors), ~5532 (`markCorrectionsDirty`)

### Testing
- Visual inspection: buttons should have consistent color meaning
- `runAllTests(Group="gui")`

---

## Phase 4: Axes/Appearance Separator + Save Panel Cleanup

**Goal:** Add visual separator in `axLimGL`; make save panel's "Tools" section collapsible.
**Risk:** Low-Medium
**Effort:** Medium (~1h)

### 4a. axLimGL Separator

Insert a section-header label between row 5 (axis limits) and row 6 (appearance controls):

```matlab
lblAxAppearance = uilabel(axLimGL, 'Text', '—  Appearance  —', ...
    'FontSize', 8, 'FontColor', [0.45 0.45 0.45], ...
    'FontAngle', 'italic', 'HorizontalAlignment', 'center');
```

- `axLimGL` changes from `[13 4]` to `[14 4]`
- New row inserted at position 6, height 12px
- All appearance widget `Layout.Row` values bump by +1 (rows 6→7 through 13→14)
- Check `toggleY2Appearance()` — uses handle names not row numbers, should be safe
- Grep for `axLimGL.RowHeight{N}` and update any index references

### 4b. Save Panel — Collapsible "Tools" Section

`saveGL` rows 17-22 contain a "Tools" section header (row 17) followed by: Batch Convert XRD, Resample Data, Column Calculator, Inset Plot Generator, and a spacer.

Make rows 18-22 collapsible (default collapsed):
- Add `ButtonDownFcn` to the existing "Tools" section header label
- Toggle `saveGL.RowHeight{18..22}` between `24`/`0`
- `appData.sectionCollapsed.saveTools = true` (default collapsed)
- Saves ~120px when collapsed

### Files
- `DataPlotter.m`: lines ~939 (axLimGL creation), ~1046-1197 (appearance widgets), ~1203-1383 (saveGL), ~9226 (`toggleY2Appearance`)

### Testing
- Verify axis limits and appearance controls render correctly with separator
- Toggle Tools section; verify buttons hide/show
- `runAllTests(Group="gui")`

---

## Phase 5: Peak Panel — Advanced Buttons Collapsible

**Goal:** Collapse W-H Plot, FFT Thickness, Refine Lattice behind an "Advanced..." toggle.
**Risk:** Low
**Effort:** Medium (~1h)

### Changes

In `peakBtnGL` (~line 1405):

- Insert "Advanced..." toggle button at row 11
- W-H Plot, FFT Thickness, Refine Lattice shift to rows 12-14
- Reflectivity FFT stays visible (used by neutron mode)
- Default: collapsed (`peakBtnGL.RowHeight{12..14} = 0`)

New function `onToggleAdvancedPeakTools()`:
```matlab
function onToggleAdvancedPeakTools(~,~)
    collapsed = ~appData.sectionCollapsed.advancedPeak;
    appData.sectionCollapsed.advancedPeak = collapsed;
    heights = {24, 24, 24};  % W-H, FFT, Lattice
    for k = 1:3
        peakBtnGL.RowHeight{11+k} = heights{k} * ~collapsed;
    end
    if collapsed
        btnMorePeak.Text = [char(9654) ' Advanced...'];
    else
        btnMorePeak.Text = [char(9660) ' Advanced'];
    end
end
```

`applyParserAnalysisConfig()` already controls visibility of these buttons per mode. The collapse toggle is additive — if a button is `Visible='off'` due to mode, collapsing the section has no visible effect (the row is 0-height anyway when not in XRD mode).

### Files
- `DataPlotter.m`: lines ~1405 (peakBtnGL), ~1471 (button definitions), new toggle function

### Testing
- Load XRD file; verify primary peak buttons visible, advanced hidden
- Click "Advanced..."; verify W-H/FFT/Lattice appear
- Switch to VSM; verify peak panel hides entirely
- `runAllTests(Group="gui")`

---

## Implementation Order

```
Commit 1:  Phase 1  — min-width constraints (standalone, safe)
Commit 2:  Phase 2  — corrGL restructure (big change, high impact)
Commit 3:  Phase 3  — button styling (depends on Phase 2 row numbers)
Commit 4:  Phase 4  — axLimGL separator + save panel
Commit 5:  Phase 5  — peak panel collapse
```

## Verification Checklist

After all phases:

- [ ] `runAllTests(Group="gui")` passes
- [ ] `runAllTests(Group="parser")` passes (corrections pipeline unchanged)
- [ ] Load XRD file: corrGL fits 1080p, peak panel visible, sections collapse
- [ ] Load VSM file: peak panel hidden, labels correct, resize works
- [ ] Load neutron file: asymmetry rows appear, BG rows hidden
- [ ] Load SIMS file: BG slope disabled, log Y enabled, [SIMS] badge
- [ ] Load generic CSV: all generic controls enabled
- [ ] Resize window to 1080p (1920x1080): no overflow in any panel
- [ ] Resize window to 1440p (2560x1440): good use of space, no dead areas
- [ ] Drag all panel borders: min-width constraints enforced
- [ ] Toggle each collapsible section: smooth expand/collapse
- [ ] Session save/load: corrections, peaks, axis limits survive round-trip
- [ ] Apply button: gray when Live Preview on, green when off
