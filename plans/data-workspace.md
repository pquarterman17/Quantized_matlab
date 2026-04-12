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

3. **Column roles system** — lightweight column metadata for multi-X and display order
   - [ ] Create `+dataWorkspace/ColumnRoles.m` as a value class
   - [ ] Properties: `displayOrder` (visual column order), `xGroups` (struct
         array: `.xCol` index + `.yCols` index list), `skipped` (logical mask)
   - [ ] Default: column 0 (`.time`) is X for all `.values` columns
   - [ ] `addXGroup(xColIdx, yColIndices)` — creates a new X→Y grouping
   - [ ] `reorder(newOrder)` — sets display column order (visual only)
   - [ ] `getPlotGroups()` — returns cell array of `{xData, yData, labels}` per group
   - [ ] Store per-dataset in `WorkspaceModel.columnRoles{dsIdx}`
   - [ ] Right-click column header: "Set as X", "Set as Y for [X column]"
   - [ ] Visual header badges: (X), (Y), (—) for skipped
   - [ ] Unit tests: default roles, multi-X, reorder, round-trip

4. **Mask model enhancements** — first-class mask operations on the model
   - [ ] `WorkspaceModel.maskPoints(dsIdx, rowIndices)`
   - [ ] `WorkspaceModel.maskRegion(dsIdx, xMin, xMax, yMin, yMax, colIdx)`
   - [ ] `WorkspaceModel.unmaskPoints(dsIdx, rowIndices)`
   - [ ] `WorkspaceModel.unmaskAll(dsIdx)`
   - [ ] `WorkspaceModel.getMask(dsIdx)` — returns logical vector
   - [ ] Mask survives sort/filter (stored on original row indices)
   - [ ] DataWorkspace GUI: masked rows highlighted in soft red
   - [ ] Status bar: "N rows, M masked"
   - [ ] Tests: mask/unmask/region/persistence through sort

5. **Version-branched table widget** — uispreadsheet on R2025a+, uitable fallback
   - [ ] Create `+dataWorkspace/createTableWidget.m` factory function
   - [ ] R2025a+: return `uispreadsheet` with built-in sort/filter/freeze
   - [ ] R2022b-R2024b: return `uitable` with manual sort and filter
   - [ ] Shared API: `.Data`, `.ColumnName`, `.ColumnEditable`, `.Selection`
   - [ ] One-time `fprintf` notice on fallback path per CLAUDE.md convention
   - [ ] Wire into DataWorkspace.m (replace direct `uitable` creation)
   - [ ] Tests: widget creation on current MATLAB version

6. **BosonPlotter ↔ WorkspaceModel integration** — shared model connection
   - [ ] BosonPlotter creates `WorkspaceModel` at startup as `appData.model`
   - [ ] `guiImport` / `loadFilePaths`: also call `model.addDataset()`
   - [ ] Add "Open in DataWorkspace" button to BosonPlotter toolbar
   - [ ] Button opens `DataWorkspace(Model=appData.model)` — shares the model
   - [ ] BosonPlotter listens for `DataChanged` → refreshes dataset list
   - [ ] BosonPlotter listens for `MaskChanged` → replots with updated mask
   - [ ] DataWorkspace listens for model changes from BosonPlotter
   - [ ] Existing embedded table continues to work (reads from model)

7. **Shared model migration** — `appData.datasets` reads through WorkspaceModel
   - [ ] `appData.datasets` becomes a read-through to `model.datasets`
   - [ ] All `appData.datasets{idx} = ds` copy-back sites → `model.updateDataset()`
   - [ ] `ds.mask` → `model.mask{idx}` (single source of truth)
   - [ ] `rebuildDatasetList` reads from model
   - [ ] `renderPlot` reads mask from model
   - [ ] `onArmMaskSelection` / `applyMaskInBox` writes to model
   - [ ] `buildDisplayMask` reads from model
   - [ ] Existing GUI tests updated for new mask path
   - [ ] Session save/load updated to serialize model state

## Tier 2 — Medium Impact

8. **Sorting** — sort by any column
   - [ ] R2025a: built-in via uispreadsheet
   - [ ] R2022b fallback: context menu "Sort Ascending/Descending"
   - [ ] Sort is display-only — underlying data order unchanged
   - [ ] Sort indicator in column header (▲/▼)
   - [ ] Multi-column sort: Shift+click adds secondary sort key

9. **Filtering** — show/hide rows by expression
   - [ ] R2025a: built-in filter row via uispreadsheet
   - [ ] R2022b fallback: top-row editfield with expression parser
   - [ ] Reuse `+bosonPlotter/filterRows.m` expression engine
   - [ ] Filter is visual only — doesn't affect mask or data
   - [ ] Active filter indicator in status bar

10. **Live statistics bar** — Origin-style selection statistics
    - [ ] Bottom bar shows: count, mean, std, min, max for selected cells
    - [ ] Updates on cell/row selection change
    - [ ] Also shows: sum, median when useful (toggleable)
    - [ ] Works with multi-cell selection (rectangular region)

11. **Column formulas** — Origin-style computed columns
    - [ ] Create `+dataWorkspace/FormulaEngine.m`
    - [ ] Parse: `col("Field") * 79.5775`, `sqrt(col("R1")^2 + col("R2")^2)`
    - [ ] Reuse `+fitting/parseEquation.m` tokenizer (no `eval`)
    - [ ] Column references by name: `col("Temperature")` or `$Temperature`
    - [ ] Results in `WorkspaceModel.computedColumns{dsIdx}`
    - [ ] Computed columns appear with italic/colored header
    - [ ] Auto-recalculate on source data change (DataChanged listener)
    - [ ] "Add Computed Column..." dialog with expression field + preview
    - [ ] Circular reference detection
    - [ ] Tests: parsing, evaluation, recalc, circular ref error

12. **Column reordering** — drag or right-click to move
    - [ ] Drag column header to reposition (visual order only)
    - [ ] Right-click → "Move Left" / "Move Right" / "Move to Start"
    - [ ] Display order stored in `ColumnRoles.displayOrder`
    - [ ] Does not affect `.values` matrix or downstream code

## Tier 3 — Nice-to-Have

13. **Multi-dataset operations** — work across datasets
    - [ ] Merge datasets (horizontal concat by shared X, interpolate if needed)
    - [ ] Dataset math: `Dataset A - Dataset B`
    - [ ] Compare view: side-by-side tables for two datasets
    - [ ] Drag column from one dataset's sheet to another

14. **Clipboard paste-to-import** — Ctrl+V creates a new dataset
    - [ ] Auto-detect delimiter (tab, comma, space)
    - [ ] Header row detection (reuse `+parser/` heuristics)
    - [ ] Paste into existing dataset to add columns

15. **Plot from DataWorkspace** — launch plotter from spreadsheet
    - [ ] Select columns → right-click → "Plot as X vs Y"
    - [ ] Opens BosonPlotter with shared model, selected columns pre-configured
    - [ ] Bidirectional: clicking a point in BosonPlotter highlights the row

16. **Remove legacy table from BosonPlotter** — clean break
    - [ ] Delete tblData, tblUnits, refreshDataTable (~170 lines)
    - [ ] Delete mask sync code (syncTableMaskToDataset, applyMaskStyling)
    - [ ] Delete appData.tableWorkingCopy, tableMask, tableEdited
    - [ ] Replace bottom panel with compact info bar + "Open DataWorkspace" button
    - [ ] Retire spreadsheetPopup.m (DataWorkspace replaces it)
    - [ ] Net: ~400-500 lines removed from BosonPlotter.m

17. **Error bar column designation** — explicit error associations
    - [ ] ColumnRoles gains `.errorFor` mapping: `{colIdx → errorColIdx}`
    - [ ] Right-click column → "Set as Error Bar for [column name]"
    - [ ] `renderPlot` uses explicit designation when present, falls back to
          `findErrorColumn()` heuristic when not
    - [ ] Visual header badge: (E) for error columns

18. **Virtual scrolling** — handle million-row datasets
    - [ ] R2025a: uispreadsheet handles this natively
    - [ ] R2022b fallback: render only visible rows + buffer, fetch on scroll
    - [ ] Eliminate the 500-row cap

19. **Session persistence** — save/load workspace state
    - [ ] Save: all datasets, masks, roles, computed columns, layout to `.dwk` file
    - [ ] Auto-recovery (reuse `+bosonPlotter/autosave.m` pattern)
    - [ ] Recent workspaces menu

20. **Python port contract** — design document for thin_film_toolkit
    - [ ] WorkspaceModel → Python dataclass / Pydantic model
    - [ ] Events → WebSocket messages (FastAPI)
    - [ ] FormulaEngine → Python (sympy or custom)
    - [ ] uispreadsheet → AG Grid / TanStack Table
    - [ ] JSON schema for column roles (shared between MATLAB + Python)

---

## Completed

- ~~**WorkspaceModel handle class**~~ (2026-04-12) — `+dataWorkspace/WorkspaceModel.m`; 7 passing unit tests
- ~~**DataWorkspace standalone GUI**~~ (2026-04-12) — `DataWorkspace.m`; dark theme, dataset list, row masking, export, `Visible='off'` API
