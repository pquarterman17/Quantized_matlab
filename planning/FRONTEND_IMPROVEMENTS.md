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

- [ ] **H3 — No status bar or busy indicator** *(Medium)*
  Long operations (batch export, global peak fit, session load) give no feedback — GUI appears frozen.
  **Fix:** Add an 18px status label row at the bottom of `rootGL` + `setStatus(msg)` helper. Set `fig.Pointer = 'watch'` at start of long operations.
  **Affected:** `rootGL` construction; `onBatchExportCSV`, `onFitAllPeaks`, `onSaveSession`, `onLoadSession`, `onApplyCorrectionsAll`.

  ```matlab
  % Sketch:
  rootGL.RowHeight = {185, '1x', '1x', 18};
  lblStatusBar = uilabel(rootGL, 'Text', 'Ready', ...
      'FontSize', 9, 'FontColor', [0.5 0.5 0.5]);
  lblStatusBar.Layout.Row = 4; lblStatusBar.Layout.Column = 1;

  function setStatus(msg)
      lblStatusBar.Text = msg;
      drawnow limitrate;
  end
  ```

- [ ] **H4 — Save/Export panel is a flat wall of 14 unlabelled buttons** *(Small–Medium)*
  No visual grouping between data export / figure export / Origin integration / session / tools.
  **Fix:** Insert thin `uilabel` separator rows. Restructure `saveGL` to 18 rows with 4 separator rows (14px each).

  | Group | Buttons |
  |-------|---------|
  | Data Export | Save CSV, Batch Export All CSV, Export HDF5, Copy Data to Clipboard |
  | Figure Export | Export to Figure Window, Copy Plot to Clipboard, Save Figure |
  | Origin / Excel | Send to Origin, Export Origin Script, Export Peak Summary XLSX |
  | Session | Save Session, Load Session |
  | Tools | Batch Convert XRD, Layout Settings |

---

## MEDIUM PRIORITY

- [ ] **M1 — Empty row 7 in file list panel wastes 26px** *(Small)*
  `tbGL` has 8 rows; row 7 is empty dead space between the buttons and the listbox.
  **Fix A:** Remove the row (7-row grid, listbox at row 7).
  **Fix B:** Use it for a dataset count label: `"3 files loaded"`.

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

- [ ] **M4 — Keyboard shortcuts not discoverable in the UI** *(Small)*
  10 shortcuts exist but most have no in-app reference.

  | Shortcut | Action | Documented? |
  |----------|--------|-------------|
  | Ctrl+S | Save Session | No |
  | Ctrl+Z | Undo Corrections | No |
  | Ctrl+C | Copy Plot | No |
  | Left / Right | Switch dataset | No |
  | Space | Toggle visibility | No |
  | Delete | Remove dataset | Yes |
  | Ctrl+Up / Down | Reorder dataset | Yes |

  **Fix:** Add `[Shortcut]` hints to button tooltips. Optionally add a `?` button that opens a shortcut reference `uialert`.

  ```matlab
  btnSaveSession.Tooltip = 'Save all datasets, corrections, and peaks to a .mat file  [Ctrl+S]';
  btnUndo.Tooltip        = 'Restore corrections to the state before the last Apply  [Ctrl+Z]';
  btnCopyClip.Tooltip    = 'Copy the current plot to the clipboard as an image  [Ctrl+C]';
  ```

- [x] **M5 — Correction style dropdown tooltip was misleading** *(Trivial)*
  Tooltip said `"Choose correction labels"` but the style actually controls which panels and analysis features are visible.
  **Commit:** `b4ad77a`

- [ ] **M6 — No dirty-state indicator when corrections are unapplied** *(Medium)*
  No visual cue that the plot is stale after editing offset/smoothing/normalization fields.
  **Fix:** Change `btnApply` text to `"Apply  *"` and tint it yellow when any correction field changes; reset on apply.

  ```matlab
  % In each correction field ValueChangedFcn:
  btnApply.Text = 'Apply  *';
  btnApply.FontColor = [1 0.85 0.2];

  % In onApplyCorrections, after applying:
  btnApply.Text = 'Apply Corrections';
  btnApply.FontColor = [1 1 1];
  ```

- [x] **M7 — Peak table columns clipped values at narrow widths** *(Trivial)*
  `#` column was 28px (oversized); d-spacing/size columns were 62px (too narrow for decimal values).
  Changed to `{22, 82, 70, 70, 68, 65, 65, 38, 55}`.
  **Commit:** `b4ad77a`

---

## LOW PRIORITY

- [ ] **L1 — Animate button occupies prime real estate** *(Small)*
  `btnAnimate` takes a full row in the file list panel with a distinctive colour. Rarely used.
  **Fix:** Move to half-width paired with another control, or to the bottom of the panel.

- [ ] **L2 — No confirmation for destructive one-click actions** *(Small)*
  "Clear All Peaks" and "Reset" execute immediately — irreversible with one misclick (undo covers corrections only, not peaks).
  **Fix:** Add `uiconfirm` in `onClearPeaks` when fitted peaks exist.

  ```matlab
  if ~isempty(ds.peaks) && any([ds.peaks.isFitted])
      sel = uiconfirm(fig, ...
          sprintf('Remove all %d peaks (%d fitted)?', numel(ds.peaks), sum([ds.peaks.isFitted])), ...
          'Clear Peaks', 'Options', {'Clear', 'Cancel'}, ...
          'DefaultOption', 2, 'CancelOption', 2);
      if ~strcmp(sel, 'Clear'), return; end
  end
  ```

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

- [x] **L6 — "Replot" button implied plot could be stale** *(Trivial)*
  Renamed to `"Refresh"` with tooltip `"Force a full redraw of the current plot"`.
  **Commit:** `b4ad77a`

- [ ] **L7 — Save panel uses 11 different button colours with no semantic system** *(Small)*
  Each button has a unique colour; colours carry no consistent meaning.
  **Fix:** Adopt a 3-colour palette:
  - **Primary** `[0.20 0.35 0.55]` — data export actions
  - **Secondary** `[0.25 0.28 0.32]` — figure and clipboard actions
  - **Accent** `[0.15 0.40 0.40]` — external integrations (Origin, HDF5)

---

## Implementation Order (recommended)

- [x] Step 1 — H1, H2 (`4b61ecf`)
- [x] Step 2 — M5, M7, L3, L4, L6 (`b4ad77a`)
- [ ] Step 3 — M4 (shortcut hints in tooltips)
- [ ] Step 4 — L2 (`uiconfirm` for destructive actions)
- [ ] Step 5 — H4 (save panel section headers)
- [ ] Step 6 — M6 (dirty-state indicator on Apply button)
- [ ] Step 7 — H3 (status bar — requires `rootGL` restructure)
- [ ] Step 8 — M2 (replace disabled buttons with labels — large but mechanical)
