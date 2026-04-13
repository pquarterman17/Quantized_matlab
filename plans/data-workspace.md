# DataWorkspace — Standalone Spreadsheet-Centric Data Tool

Origin-style standalone data workspace that replaces the embedded BosonPlotter
data table. The spreadsheet becomes a first-class tool — not a side panel in
a plotter — with column roles, masking, sorting, filtering, statistics, and
multi-dataset management. Shares a WorkspaceModel with BosonPlotter so changes
in either window reflect immediately in the other.

**Status:** Active
**Created:** 2026-04-11
**Updated:** 2026-04-12

---

## Context

### How the pieces fit together

The data table today lives inside BosonPlotter as ~400 lines of tightly coupled
layout + callbacks. DataWorkspace extracts this into a standalone GUI backed by
a shared handle-class model that both GUIs observe.

```
+dataWorkspace/
├── WorkspaceModel.m      — handle class: datasets, masks, column roles, events [EXISTS]
├── ColumnRoles.m         — lightweight column metadata (X/Y grouping, display order)
├── FormulaEngine.m       — column formula parser + evaluator (reuses +fitting/parseEquation)
└── createTableWidget.m   — uispreadsheet (R2025a+) / uitable (R2022b) factory

DataWorkspace.m           — standalone spreadsheet GUI [EXISTS, basic]
BosonPlotter.m            — plotter (reads from shared WorkspaceModel)
```

Key design choices:
- **Shared model**: BosonPlotter and DataWorkspace share one `WorkspaceModel`
  instance; `appData.datasets` migrates to `model.datasets`
- **No positional constraints**: any column can be X for any Y group (no
  Origin-style "X must be left" rule); roles stored as metadata
- **Multi-X**: one dataset can have `{Time→[V,I], Temperature→[R]}` groupings
- **Display order ≠ data order**: column reordering is visual only
- **R2025a `uispreadsheet` with R2022b `uitable` fallback** via version detection
- **Coexist then replace**: embedded table stays until DataWorkspace is stable

### Data / control flow

```
Current:
  File → importAuto() → ds struct → appData.datasets{N}
    ├── BosonPlotter: tblData/tblUnits (embedded, 500-row cap)
    ├── ds.mask (BosonPlotter-internal)
    └── renderPlot → good + gray masked points

Proposed:
  File → importAuto() → WorkspaceModel.addDataset()
    ├── DataWorkspace GUI (standalone spreadsheet)
    │   ├── uispreadsheet or uitable (version-branched)
    │   ├── column roles, sorting, filtering, statistics
    │   └── row/region masking (first-class model operation)
    ├── BosonPlotter (plotter — observes same model)
    │   ├── reads datasets + masks from model
    │   ├── rectangle-mask writes back to model
    │   └── "Open DataWorkspace" button
    └── Both listen to DataChanged / MaskChanged / SelectionChanged events
```

### Dependency map
- Items 1-2 are done (foundation)
- Items 3, 4, 5 are independent (parallelizable)
- Item 6 (BP integration) requires items 3-5
- Item 7 (shared model migration) requires item 6
- Items 8-10 are independent of each other, require item 5
- Item 11 (formulas) requires item 3
- Items 12-15 require items 6-7
- Item 16 (remove legacy) requires everything above to be stable

---

## Tier 1 — High Impact

3. ~~**Column roles system**~~ — lightweight column metadata for multi-X and display order
   - [x] Create `+dataWorkspace/ColumnRoles.m` as a value class
   - [x] Properties: `displayOrder` (visual column order), `xGroups` (struct
         array: `.xCol` index + `.yCols` index list), `skipped` (logical mask)
   - [x] Default: column 0 (`.time`) is X for all `.values` columns
   - [x] `addXGroup(xColIdx, yColIndices)` — creates a new X→Y grouping
   - [x] `reorder(newOrder)` — sets display column order (visual only)
   - [x] `getPlotGroups()` — returns cell array of `{xData, yData, labels}` per group
   - [x] Store per-dataset in `WorkspaceModel.columnRoles{dsIdx}`
   - [ ] Right-click column header: "Set as X", "Set as Y for [X column]" — not implemented; error bar designation exists instead
   - [x] Visual header badges: (E) for error columns via `badgeErrorColumns`
   - [x] Unit tests: default roles, multi-X, reorder, round-trip (tests H-M, U-V in test_workspaceModel)

4. ~~**Mask model enhancements**~~ — first-class mask operations on the model
   - [x] `WorkspaceModel.maskPoints(dsIdx, rowIndices)`
   - [x] `WorkspaceModel.maskRegion(dsIdx, xMin, xMax, yMin, yMax, colIdx)`
   - [x] `WorkspaceModel.unmaskPoints(dsIdx, rowIndices)`
   - [x] `WorkspaceModel.unmaskAll(dsIdx)`
   - [x] `WorkspaceModel.getMask(dsIdx)` — returns logical vector
   - [x] Mask survives sort/filter (stored on original row indices)
   - [x] DataWorkspace GUI: masked rows highlighted with `*` column indicator
   - [x] Status bar: "N rows, M masked"
   - [x] Tests: mask/unmask/region/persistence (tests D-G in test_workspaceModel)

5. ~~**Version-branched table widget**~~ — uispreadsheet on R2025a+, uitable fallback
   - [x] Create `+dataWorkspace/createTableWidget.m` factory function
   - [x] R2025a+: return `uispreadsheet` with built-in sort/filter/freeze
   - [x] R2022b-R2024b: return `uitable` with manual sort and filter
   - [x] Shared API: `.Data`, `.ColumnName`, `.ColumnEditable`, `.Selection`
   - [x] One-time `fprintf` notice on fallback path per CLAUDE.md convention
   - [x] Wire into DataWorkspace.m (replace direct `uitable` creation)
   - [x] Tests: widget creation on current MATLAB version

6. ~~**BosonPlotter ↔ WorkspaceModel integration**~~ — shared model connection
   - [x] BosonPlotter creates `WorkspaceModel` at startup as `appData.model`
   - [x] `guiImport` / `loadFilePaths`: also call `model.addDataset()`
   - [x] Add "Open in DataWorkspace" button to BosonPlotter toolbar
   - [x] Button opens `DataWorkspace(Model=appData.model)` — shares the model
   - [x] BosonPlotter listens for `DataChanged` → refreshes dataset list
   - [x] BosonPlotter listens for `MaskChanged` → replots with updated mask
   - [x] DataWorkspace listens for model changes from BosonPlotter
   - [x] Existing embedded table continues to work (reads from model)

7. **Shared model migration** — `appData.datasets` reads through WorkspaceModel (PARTIAL)
   - [ ] `appData.datasets` becomes a read-through to `model.datasets` — still 183 direct refs
   - [ ] All `appData.datasets{idx} = ds` copy-back sites → `model.updateDataset()` — 6 of ~51 migrated
   - [ ] `ds.mask` → `model.mask{idx}` (single source of truth)
   - [ ] `rebuildDatasetList` reads from model
   - [ ] `renderPlot` reads mask from model
   - [ ] `onArmMaskSelection` / `applyMaskInBox` writes to model
   - [ ] `buildDisplayMask` reads from model
   - [ ] Existing GUI tests updated for new mask path
   - [ ] Session save/load updated to serialize model state

## Tier 2 — Medium Impact

8. ~~**Sorting**~~ — sort by any column
   - [x] R2025a: built-in via uispreadsheet
   - [x] R2022b fallback: context menu "Sort Ascending/Descending"
   - [x] Sort is display-only — underlying data order unchanged
   - [ ] Sort indicator in column header (▲/▼)
   - [ ] Multi-column sort: Shift+click adds secondary sort key

9. ~~**Filtering**~~ — show/hide rows by expression
   - [x] R2025a: built-in filter row via uispreadsheet
   - [x] R2022b fallback: top-row editfield with expression parser
   - [x] Reuse `+bosonPlotter/filterRows.m` expression engine
   - [x] Filter is visual only — doesn't affect mask or data
   - [x] Active filter indicator in status bar

10. ~~**Live statistics bar**~~ — Origin-style selection statistics
    - [x] Bottom bar shows: count, mean, std, min, max for selected cells
    - [x] Updates on cell/row selection change
    - [ ] Also shows: sum, median when useful (toggleable)
    - [x] Works with multi-cell selection (rectangular region)

11. ~~**Column formulas**~~ — Origin-style computed columns
    - [x] Create `+dataWorkspace/FormulaEngine.m`
    - [x] Parse: `col("Field") * 79.5775`, `sqrt(col("R1")^2 + col("R2")^2)`
    - [x] Reuse `+fitting/parseEquation.m` tokenizer (no `eval`)
    - [x] Column references by name: `col("Temperature")` or `$Temperature`
    - [x] Results in `WorkspaceModel.computedColumns{dsIdx}`
    - [x] Computed columns appear with italic/colored header
    - [x] Auto-recalculate on source data change (DataChanged listener)
    - [x] "Add Computed Column..." dialog with expression field + preview
    - [x] Circular reference detection
    - [x] Tests: parsing, evaluation, recalc, circular ref error

12. ~~**Column reordering**~~ — drag or right-click to move
    - [ ] Drag column header to reposition (visual order only) — not implemented
    - [x] Right-click → "Move Left" / "Move Right" / "Move to Start"
    - [x] Display order stored in `ColumnRoles.displayOrder`
    - [x] Does not affect `.values` matrix or downstream code

## Tier 3 — Nice-to-Have

13. **Multi-dataset operations** — work across datasets
    - [x] Merge datasets (horizontal concat by shared X, interpolate if needed) — `WorkspaceModel.mergeDatasets`
    - [x] Dataset math: `Dataset A - Dataset B` — `WorkspaceModel.datasetMath`
    - [ ] Compare view: side-by-side tables for two datasets
    - [ ] Drag column from one dataset's sheet to another

14. ~~**Clipboard paste-to-import**~~ — Ctrl+V creates a new dataset
    - [x] Auto-detect delimiter (tab, comma, space) — `parseClipboardText` local function
    - [x] Header row detection (reuse `+parser/` heuristics)
    - [ ] Paste into existing dataset to add columns

15. ~~**Plot from DataWorkspace**~~ — launch plotter from spreadsheet
    - [x] Select columns → right-click → "Plot as X vs Y" — Plot button + "Open New Plotter" context menu
    - [x] Opens BosonPlotter with shared model, selected columns pre-configured
    - [ ] Bidirectional: clicking a point in BosonPlotter highlights the row

16. **Remove legacy table from BosonPlotter** — clean break
    - [ ] Delete tblData, tblUnits, refreshDataTable (~170 lines)
    - [ ] Delete mask sync code (syncTableMaskToDataset, applyMaskStyling)
    - [ ] Delete appData.tableWorkingCopy, tableMask, tableEdited
    - [ ] Replace bottom panel with compact info bar + "Open DataWorkspace" button
    - [ ] Retire spreadsheetPopup.m (DataWorkspace replaces it)
    - [ ] Net: ~400-500 lines removed from BosonPlotter.m

17. ~~**Error bar column designation**~~ — explicit error associations
    - [x] ColumnRoles gains `.errorFor` mapping: `{colIdx → errorColIdx}`
    - [x] Right-click column → "Set as Error Bar for [column name]"
    - [x] `renderPlot` uses explicit designation when present, falls back to
          `findErrorColumn()` heuristic when not
    - [x] Visual header badge: (E) for error columns — via `badgeErrorColumns`

18. ~~**Virtual scrolling**~~ — handle million-row datasets
    - [x] R2025a: uispreadsheet handles this natively
    - [x] R2022b fallback: row cap removed, uitable renders all rows
    - [x] Eliminate the 500-row cap

19. ~~**Session persistence**~~ — save/load workspace state
    - [x] Save: all datasets, masks, roles, computed columns, layout to `.dwk` file
    - [x] Auto-recovery — `+dataWorkspace/WorkspaceAutosave.m` with 2-min timer
    - [ ] Recent workspaces menu

20. ~~**Python port contract**~~ — design document for thin_film_toolkit
    - [x] WorkspaceModel → Python dataclass / Pydantic model — design doc at `plans/dataworkspace-python-port.md`
    - [x] Events → WebSocket messages (FastAPI)
    - [x] FormulaEngine → Python (sympy or custom)
    - [x] uispreadsheet → AG Grid / TanStack Table
    - [x] JSON schema for column roles (shared between MATLAB + Python)

---

## Completed

- ~~**WorkspaceModel handle class**~~ (2026-04-12) — `+dataWorkspace/WorkspaceModel.m`; 7 passing unit tests
- ~~**DataWorkspace standalone GUI**~~ (2026-04-12) — `DataWorkspace.m`; dark theme, dataset list, row masking, export, `Visible='off'` API
- ~~**Column roles system**~~ (2026-04-12) — `+dataWorkspace/ColumnRoles.m` value class; displayOrder, xGroups, skipped, errorFor; tests H-M, U-V
- ~~**Mask model enhancements**~~ (2026-04-12) — maskPoints/unmaskPoints/maskRegion/getMask/unmaskAll on WorkspaceModel; masked row indicator in table
- ~~**Version-branched table widget**~~ (2026-04-12) — `+dataWorkspace/createTableWidget.m`; uispreadsheet R2025a+ / uitable fallback
- ~~**BosonPlotter integration**~~ (2026-04-12) — `appData.model` created at startup, addDataset/removeDataset wired, "Open in DataWorkspace" button
- ~~**Sorting**~~ (2026-04-12) — uispreadsheet built-in + context menu Sort Ascending/Descending for uitable fallback
- ~~**Filtering**~~ (2026-04-12) — uispreadsheet built-in + expression filter bar for uitable fallback
- ~~**Live statistics bar**~~ (2026-04-12) — count/mean/std/min/max for selected cells, updates on selection change
- ~~**Column formulas**~~ (2026-04-12) — `+dataWorkspace/FormulaEngine.m`; col() references, circular ref detection, auto-recalc
- ~~**Column reordering**~~ (2026-04-12) — right-click Move Left/Right/Start via ColumnRoles.reorder
- ~~**Clipboard paste-to-import**~~ (2026-04-12) — Ctrl+V handler with `parseClipboardText` auto-detecting delimiter/headers
- ~~**Plot from DataWorkspace**~~ (2026-04-12) — Plot button opens BosonPlotter with shared model; "Open New Plotter" context menu
- ~~**Error bar column designation**~~ (2026-04-12) — ColumnRoles `.errorFor` with setErrorFor/getErrorFor/clearErrorFor; (E) header badges
- ~~**Virtual scrolling**~~ (2026-04-12) — 500-row cap removed; uispreadsheet handles natively, uitable renders all rows
- ~~**Session persistence**~~ (2026-04-12) — save/load `.dwk` files + `WorkspaceAutosave` crash recovery with 2-min timer
- ~~**Python port contract**~~ (2026-04-12) — design doc written at `plans/dataworkspace-python-port.md`
