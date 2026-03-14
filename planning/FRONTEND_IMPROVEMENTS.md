# Frontend Improvements — dataImportGUI.m

UX audit performed 2026-03-14.

---

## HIGH PRIORITY

- [x] **H1 — Ctrl+E keyboard shortcut crash**
  `onFigureKeyPress` called non-existent `onExportCSV()` — renamed to `onSaveCSV()`.
  **Commit:** `4b61ecf`

- [x] **H2 — Drag-and-drop rejected neutron and Bruker files**
  `onDropFiles` `supported` list was missing `.brml`, `.refl`, `.pnr`, `.datA/.datB/.datC/.datD`, `.data/.datb/.datc/.datd`. Accepted by the Add Files dialog but silently rejected on drag-and-drop.
  **Commit:** `4b61ecf`

- [x] **H3 — No status bar or busy indicator** *(Medium)*
  Long operations (batch export, global peak fit, session load) give no feedback — GUI appears frozen.
  **Fix:** Added 18px `lblStatusBar` uilabel as row 3 of `rootGL` (changed from `[2 1]` to `[3 1]`). Added `setStatus(msg)` helper. Added `fig.Pointer = 'watch'` + `setStatus` at start of `onBatchExportCSV`, `onFitAllPeaks`, `onSaveSession`, `onLoadSession`, `onApplyCorrectionsAll`. Reset pointer and status on completion/error. Also updates `onPanelResizeMove` to preserve row 3 in `rootGL.RowHeight` assignments.
  **Commit:** `873b401` (this session)

- [x] **H4 — Save/Export panel is a flat wall of 14 unlabelled buttons** *(Small–Medium)*
  No visual grouping between data export / figure export / Origin integration / session / tools.
  **Fix:** Restructured `saveGL` from 14 to 19 rows; inserted 5 thin (14px) `uilabel` section headers. Reordered buttons to match groups (BatchExport and CopyDataClip moved into Data Export group). All row assignments updated.
  **Groups:** Data Export (rows 1–7), Figure Export (rows 8–11), Session (rows 12–13), Origin / Excel (rows 14–16), Tools (rows 17–19).
  **Commit:** `873b401` (this session)

---

## MEDIUM PRIORITY

- [ ] **M1 — Empty row 7 in file list panel wastes 26px** *(Small)*
  `tbGL` has 8 rows; row 7 is empty dead space between the buttons and the listbox.
  **Partially fixed:** Row 6 now split: `btnAnimate` at col 1, `btnShortcuts` (? Shortcuts) at col 2. Row 7 still exists as 26px dead space — could be removed in a future pass.

- [ ] **M2 — 25+ disabled buttons used as static labels** *(Medium)*
  `lblXOff`, `lblYOff`, `lblSmooth`, etc. are `uibutton(..., 'Enable','off')`. Renders as greyed-out broken buttons, not labels.
  **Affected lines:** ~607, 618, 626, 635, 643, 719, 736, 805, 810, 820, 832, 842, 866–874, 902, 927, 964, 987, 1006, 1016, 1033, 1045.
  **Fix:** Replace with `uilabel` widgets.

  ```matlab
  % Instead of:
  lblXOff = uibutton(corrGL, 'Text', 'X Offset:', 'Enable', 'off');
  % Use:
  lblXOff = uilabel(corrGL, 'Text', 'X Offset:', 'FontSize', 12, ...
      'HorizontalAlignment', 'right');
  ```

- [x] **M4 — Keyboard shortcuts not discoverable in the UI** *(Small)*
  10 shortcuts exist but most have no in-app reference.
  **Fix:** Added `[Ctrl+Z]` to `btnUndo` tooltip, `[Space]` to `btnToggleVis`, `[Ctrl+C]` to `btnCopyClip`, `[Ctrl+S]` to `btnSaveSession`. Added `btnShortcuts` ("? Shortcuts") button at row 6 col 2 of `tbGL`, launching `onShowShortcuts()` which calls `uialert` with full shortcut list. Shrunk `btnAnimate` to half-width (col 1 only) to make room.
  **Commit:** `873b401` (this session)

- [x] **M5 — Correction style dropdown tooltip was misleading** *(Trivial)*
  Tooltip said `"Choose correction labels"` but the style actually controls which panels and analysis features are visible.
  **Commit:** `b4ad77a`

- [x] **M6 — No dirty-state indicator when corrections are unapplied** *(Medium)*
  No visual cue that the plot is stale after editing offset/smoothing/normalization fields.
  **Fix:** Added `markCorrectionsDirty()` helper. Added `ValueChangedFcn` callbacks to `efXOffset`, `efYOffset`, `efBGSlope`, `efBGIntercept`, `ddNormalize`, `efXTrimMin`, `efXTrimMax` — each calls `markCorrectionsDirty()`. In `onApplyCorrections`, reset `btnApply.Text = 'Apply Corrections'` and `btnApply.FontColor = [1 1 1]` after applying.
  **Commit:** `873b401` (this session)

- [x] **M7 — Peak table columns clipped values at narrow widths** *(Trivial)*
  `#` column was 28px (oversized); d-spacing/size columns were 62px (too narrow for decimal values).
  Changed to `{22, 82, 70, 70, 68, 65, 65, 38, 55}`.
  **Commit:** `b4ad77a`

---

## LOW PRIORITY

- [x] **L1 — Animate button occupies prime real estate** *(Small)*
  `btnAnimate` was full-width in row 6 of `tbGL`.
  **Fix:** Shrunk to column 1 only; column 2 used for `btnShortcuts` (implemented alongside M4).
  **Commit:** `873b401` (this session)

- [x] **L2 — No confirmation for destructive one-click actions** *(Small)*
  "Clear All Peaks" and "Reset" execute immediately — irreversible with one misclick.
  **Fix:** Added `uiconfirm` in `onClearPeaks` when fitted peaks exist (checks `ds.peaks.status` for 'fitted'/'fitted(global)'). Added `uiconfirm` in `onResetCorrections` when `ds.corrData` is non-empty.
  **Commit:** `873b401` (this session)

- [x] **L3 — Axis limit placeholder text failed WCAG contrast** *(Trivial)*
  Default placeholder grey (~2.6:1 contrast ratio) on dark `[0.17 0.17 0.17]` background failed WCAG AA.
  Added `AXLIM_PH = [0.70 0.70 0.70]` constant and `PlaceholderFontColor` on all 9 axlim fields (~4.4:1).
  **Commit:** `b4ad77a`

- [x] **L4 — Default file list width clipped long filenames** *(Trivial)*
  Raised `contentGL.ColumnWidth{1}` and `LAYOUT_DEFAULTS.fileListW` from 170 → 200px.
  **Commit:** `b4ad77a`

- [ ] **L5 — Unnecessary 2px spacer rows in ctrlGL** *(Small)*
  Rows 2, 4, 6 of `ctrlGL` are 2px spacers that add indexing complexity without meaningful visual separation (`RowSpacing` already handles gaps).
  **Fix:** Remove spacer rows and rely on `RowSpacing`, or increase to 8–12px for intentional grouping.
  **Skipped:** High renumbering risk, low visual benefit. Defer to future pass.

- [x] **L6 — "Replot" button implied plot could be stale** *(Trivial)*
  Renamed to `"Refresh"` with tooltip `"Force a full redraw of the current plot"`.
  **Commit:** `b4ad77a`

- [x] **L7 — Save panel uses 11 different button colours with no semantic system** *(Small)*
  Each button had a unique colour; colours carried no consistent meaning.
  **Fix:** Applied 5-category semantic palette:
  - Data export: `[0.18 0.32 0.52]` — btnSave, btnBatchExport, btnCopyDataClip
  - Figure/clipboard: `[0.25 0.28 0.35]` — btnExportFig, btnCopyClip, btnSaveFig
  - External/Origin: `[0.12 0.38 0.38]` — btnSendOrigin, btnExportOriginScript, btnExportHDF5
  - Session: `[0.22 0.32 0.42]` — btnSaveSession, btnLoadSession
  - Tools: `[0.28 0.28 0.28]` — btnBatchConvertXRD, btnLayoutSettings
  **Commit:** `873b401` (this session)

---

## Implementation Order (recommended)

- [x] Step 1 — H1, H2 (`4b61ecf`)
- [x] Step 2 — M5, M7, L3, L4, L6 (`b4ad77a`)
- [x] Step 3 — M4 (shortcut hints in tooltips + ? button)
- [x] Step 4 — L2 (`uiconfirm` for destructive actions)
- [x] Step 5 — H4 (save panel section headers)
- [x] Step 6 — M6 (dirty-state indicator on Apply button)
- [x] Step 7 — H3 (status bar — rootGL restructure)
- [x] Step 7b — L1 (Animate half-width), L7 (semantic colours)
- [ ] Step 8 — M2 (replace disabled buttons with labels — large but mechanical)
- [ ] Step 9 — L5 (remove ctrlGL spacer rows — deferred, risky)
