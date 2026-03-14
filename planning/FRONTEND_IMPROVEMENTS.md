# Frontend Improvements — dataImportGUI.m

UX audit performed 2026-03-14. Items marked **FIXED** are already committed to `main`.

---

## HIGH PRIORITY

### H1 — Ctrl+E keyboard shortcut crash **FIXED**
**Problem:** `onFigureKeyPress` (line 8010) called non-existent `onExportCSV()`.
**Fix:** Renamed to `onSaveCSV()`.
**Commit:** `4b61ecf`

---

### H2 — Drag-and-drop rejected neutron and Bruker files **FIXED**
**Problem:** `onDropFiles` `supported` list (line 1552) was missing `.brml`, `.refl`, `.pnr`,
`.datA/.datB/.datC/.datD`, `.data/.datb/.datc/.datd`. These extensions were accepted by the
Add Files dialog but silently rejected on drag-and-drop — inconsistent behaviour.
**Fix:** Added all missing extensions to the filter.
**Commit:** `4b61ecf`

---

### H3 — No status bar or busy indicator
**Problem:** Long operations (batch export, global peak fit, session load) give no feedback.
The GUI appears frozen with no indication that work is in progress.
**Fix:** Add an 18px status label row at the bottom of `rootGL`. Add a `setStatus(msg)`
nested helper that sets the label text and calls `drawnow limitrate`. Set
`fig.Pointer = 'watch'` at the start of long operations and `'arrow'` on completion.
**Affected areas:** `rootGL` construction; `onBatchExportCSV`, `onFitAllPeaks`,
`onSaveSession`, `onLoadSession`, `onApplyCorrectionsAll`.
**Complexity:** Medium

```matlab
% Sketch — add to rootGL:
rootGL.RowHeight = {185, '1x', '1x', 18};
lblStatusBar = uilabel(rootGL, 'Text', 'Ready', ...
    'FontSize', 9, 'FontColor', [0.5 0.5 0.5]);
lblStatusBar.Layout.Row = 4; lblStatusBar.Layout.Column = 1;

function setStatus(msg)
    lblStatusBar.Text = msg;
    drawnow limitrate;
end
```

---

### H4 — Save/Export panel is a flat wall of 14 unlabelled buttons
**Problem:** `saveGL` has 14 rows of buttons with no visual grouping between:
data export / figure export / Origin integration / session management / tools.
Users must scan all 14 rows to find any single action.
**Fix:** Insert thin section-header `uilabel` rows between groups. Restructure `saveGL`
to 18 rows with 4 separator rows (height 14px each).

**Suggested groups:**

| Group | Buttons |
|-------|---------|
| Data Export | Save CSV, Batch Export All CSV, Export HDF5, Copy Data to Clipboard |
| Figure Export | Export to Figure Window, Copy Plot to Clipboard, Save Figure |
| Origin / Excel | Send to Origin, Export Origin Script, Export Peak Summary XLSX |
| Session | Save Session, Load Session |
| Tools | Batch Convert XRD, Layout Settings |

**Complexity:** Small–Medium

---

## MEDIUM PRIORITY

### M1 — Empty row 7 in file list panel wastes 26px
**Problem:** `tbGL` (line 338) has 8 rows `{26,26,26,26,26,26,26,'1x'}`. Rows 1–6 have
widgets, row 8 has the listbox, row 7 is empty dead space.
**Fix option A:** Remove the empty row (7-row grid, listbox at row 7).
**Fix option B:** Use row 7 for a dataset count label: `"3 files loaded"`.
**Complexity:** Small

---

### M2 — 25+ disabled buttons used as static labels
**Problem:** Controls like `lblXOff`, `lblYOff`, `lblSmooth`, etc. are created as
`uibutton(..., 'Enable', 'off')`. Disabled buttons render with low-contrast greyed text
and look like broken interactive elements, not labels.
**Affected lines:** ~607, 618, 626, 635, 643, 719, 736, 805, 810, 820, 832, 842,
866–874, 902, 927, 964, 987, 1006, 1016, 1033, 1045.
**Fix:** Replace with `uilabel` widgets. Where a background box is required for grid
alignment, use a nested single-cell `uigridlayout` with padding.
**Complexity:** Medium (mechanical — many widgets but each change is simple)

```matlab
% Instead of:
lblXOff = uibutton(corrGL, 'Text', 'X Offset:', 'Enable', 'off');
% Use:
lblXOff = uilabel(corrGL, 'Text', 'X Offset:', 'FontSize', 12, ...
    'HorizontalAlignment', 'right');
```

---

### M4 — Keyboard shortcuts not discoverable in the UI
**Problem:** The GUI has 10 keyboard shortcuts (Delete, Ctrl+S/Z/E/C, Left/Right, Space,
Ctrl+Up/Down) but there is no in-app reference. Several button tooltips mention their
shortcut, but many do not:

| Shortcut | Action | Tooltip documents it? |
|----------|--------|-----------------------|
| Ctrl+S | Save Session | No |
| Ctrl+Z | Undo Corrections | No |
| Ctrl+C | Copy Plot | No |
| Left / Right | Switch dataset | No |
| Space | Toggle visibility | No |
| Delete | Remove dataset | Yes (`btnRemoveDS`) |
| Ctrl+Up / Down | Reorder dataset | Yes (`btnMoveUp/Down`) |

**Fix:** Add shortcut hints to tooltips on the corresponding buttons. Optionally add a
`?` button or "Keyboard Shortcuts" label in the file list panel that opens a `uialert`
listing all shortcuts.
**Complexity:** Small

```matlab
% Example tooltip update:
btnSaveSession.Tooltip = 'Save all datasets, corrections, and peaks to a .mat file  [Ctrl+S]';
btnUndo.Tooltip        = 'Restore corrections to the state before the last Apply  [Ctrl+Z]';
btnCopyClip.Tooltip    = 'Copy the current plot to the clipboard as an image  [Ctrl+C]';
```

---

### M5 — Correction style dropdown tooltip is misleading
**Problem:** `ddCorrStyle` tooltip says `"Choose correction labels"` but selecting a style
actually changes which controls are visible and which analysis features are enabled
(peak tools, neutron spin asymmetry, XRD-specific panels).
**Fix:** Update tooltip to describe the actual behaviour.
**Location:** Line 613
**Complexity:** Trivial

```matlab
ddCorrStyle.Tooltip = ['Controls which correction tools and analysis features are shown. '...
    '"Auto" detects from the file type. "XRD" enables peak detection and Scherrer analysis. '...
    '"Neutron NR" enables spin asymmetry. "Generic" shows all controls.'];
```

---

### M6 — No dirty-state indicator when corrections are unapplied
**Problem:** After editing offset, smoothing, or normalization fields, the user must
remember to click "Apply Corrections". There is no visual cue that the plot is showing
stale (pre-correction) data. Users may think their input had no effect.
**Fix:** When any correction field changes, update `btnApply` text to `"Apply *"` (or
change its border) to signal pending changes. Reset to `"Apply Corrections"` after
`onApplyCorrections` runs.
**Complexity:** Medium

```matlab
% In each correction field ValueChangedFcn, add:
btnApply.Text = 'Apply  *';
btnApply.FontColor = [1 0.85 0.2];   % yellow tint = dirty

% In onApplyCorrections, after applying:
btnApply.Text = 'Apply Corrections';
btnApply.FontColor = [1 1 1];
```

---

### M7 — Peak table columns clip values at narrow widths
**Problem:** `peakTable` column widths `{28, 80, 62, 62, 65, 65, 65, 38, 55}` (line 1218)
clip d-spacing and Size values with many decimal places. The `#` column at 28px is
oversized for 1–2 digit row numbers.
**Fix:** Tighten the `#` column and redistribute to numeric columns.
**Complexity:** Trivial

```matlab
'ColumnWidth', {22, 82, 70, 70, 68, 65, 65, 38, 55},
```

---

## LOW PRIORITY

### L1 — Animate button occupies prime real estate
**Problem:** `btnAnimate` (row 6 of `tbGL`) has a distinctive brown colour and takes a
full row in the file list panel. Animation is a niche feature rarely used in normal
workflows.
**Fix:** Move to half-width paired with another control, or relocate to the bottom of
the file list panel.
**Complexity:** Small

---

### L2 — No confirmation for destructive one-click actions
**Problem:** "Clear All Peaks" and "Reset" (corrections) execute immediately. A misclick
after manually adding or fitting peaks is irreversible (undo covers corrections only,
not peaks).
**Fix:** Add `uiconfirm` in `onClearPeaks` when fitted peaks exist, and in
`onResetCorrections` when corrections have been applied.
**Complexity:** Small

```matlab
% In onClearPeaks:
if ~isempty(ds.peaks) && any([ds.peaks.isFitted])
    sel = uiconfirm(fig, ...
        sprintf('Remove all %d peaks (%d fitted)?', numel(ds.peaks), sum([ds.peaks.isFitted])), ...
        'Clear Peaks', 'Options', {'Clear', 'Cancel'}, ...
        'DefaultOption', 2, 'CancelOption', 2);
    if ~strcmp(sel, 'Clear'), return; end
end
```

---

### L3 — Axis limit placeholder text fails WCAG contrast
**Problem:** Axis limit edit fields use `BackgroundColor=[0.17 0.17 0.17]`. MATLAB's
default placeholder text renders at ~[0.5 0.5 0.5], giving a contrast ratio of ~2.6:1
(WCAG AA minimum for normal text is 4.5:1).
**Fix:** Set explicit `PlaceholderFontColor` to a lighter grey, or raise `BackgroundColor`
slightly.
**Location:** Lines 877–878
**Complexity:** Trivial

---

### L4 — Default 170px file list clips long filenames
**Problem:** Scientific filenames like `LaFeO3_300K_MvsH_sweep2.dat` are heavily
truncated in the 170px list column.
**Fix:** Raise default `contentGL.ColumnWidth{1}` from `170` to `200`. Also update
`LAYOUT_DEFAULTS.fileListW` from `170` to `200`.
**Complexity:** Trivial

---

### L6 — "Replot" button name implies plot can be stale
**Problem:** Most value-changed callbacks already call `onPlot`. The "Replot" button
(line 537) suggests manual refresh is sometimes required, which may confuse users.
**Fix:** Rename to `"Refresh"` and add tooltip: `"Force a full redraw of the current plot"`.
**Complexity:** Trivial

---

### L7 — Save panel uses 11 different button colours with no semantic system
**Problem:** Each save/export button has a unique background colour. Colours carry no
consistent meaning (not grouped by action type, not colour-coded for risk level).
**Fix:** Adopt a 3-colour palette for the save panel:
- **Primary** (blue-grey `[0.20 0.35 0.55]`) — main data export actions
- **Secondary** (slate `[0.25 0.28 0.32]`) — figure and clipboard actions
- **Accent** (teal `[0.15 0.40 0.40]`) — external integrations (Origin, HDF5)

Session and Tools buttons can use the existing neutral dark.
**Complexity:** Small

---

## Implementation Order (recommended)

1. **H1, H2** — already fixed (`4b61ecf`)
2. **M5, M7, L3, L4, L6** — all trivial, one sitting
3. **M4** — add shortcut hints to tooltips
4. **L2** — add `uiconfirm` for destructive actions
5. **H4** — restructure save panel with section headers
6. **M6** — dirty-state indicator on Apply button
7. **H3** — status bar (requires `rootGL` restructure)
8. **M2** — replace disabled buttons with labels (large but mechanical)
