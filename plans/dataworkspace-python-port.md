# DataWorkspace Python Port Contract

Design document mapping the MATLAB DataWorkspace architecture to the Python
thin_film_toolkit equivalent. Ensures both implementations share the same data
contracts and JSON schemas so templates and workspace files are portable.

**Status:** Active
**Created:** 2026-04-12
**Updated:** 2026-04-12

---

## Context

### How the pieces fit together

```
MATLAB (quantized_matlab)          Python (thin_film_toolkit)
+dataWorkspace/                    backend/thin_film_toolkit/workspace/
  WorkspaceModel.m  handle class     workspace_model.py   Pydantic model
  ColumnRoles.m     value class      column_roles.py      dataclass
  FormulaEngine.m   static class     formula_engine.py    module
  createTableWidget.m               (not needed — frontend handles)

DataWorkspace.m    uifigure GUI     src/src/views/DataWorkspaceView.vue
                                    src/src/stores/workspaceStore.ts

JSON schemas (shared):
  +templates/defaults/*.json        Same files, both sides read them
  .dwk workspace files              Same MAT→JSON mapping
```

### Dependency map
- WorkspaceModel mapping is the foundation
- ColumnRoles and FormulaEngine are independent
- Frontend (Vue) depends on API design
- Template JSON schema is already shared (item 12 in dataset-templates plan)

---

## Tier 1 — High Impact

1. **WorkspaceModel → Python** — core data model
   - [ ] `WorkspaceModel` as a Pydantic BaseModel or Python dataclass
   - [ ] `datasets`: list of `DataStruct` (the existing Python port of the unified struct)
   - [ ] `active_idx`: int
   - [ ] `masks`: list of numpy boolean arrays
   - [ ] `column_roles`: list of `ColumnRoles` dataclasses
   - [ ] `computed_columns`: list of list of `ComputedColumn` dataclasses
   - [ ] Methods: `add_dataset`, `remove_dataset`, `set_active`, `get_data`,
         `update_dataset`, `mask_points`, `unmask_all`, `get_mask`
   - [ ] Events → Python signals: use `blinker` library or custom event system
   - [ ] For WebSocket: events fire as JSON messages to connected frontends
   - [ ] FastAPI endpoints: `POST /workspace/datasets`, `DELETE /workspace/datasets/{idx}`,
         `PATCH /workspace/datasets/{idx}/mask`

2. **ColumnRoles → Python** — column metadata
   - [ ] `ColumnRoles` as a frozen dataclass
   - [ ] `display_order`: list[int]
   - [ ] `x_groups`: list of `XGroup(x_col: int, y_cols: list[int])`
   - [ ] `skipped`: list[bool]
   - [ ] `error_for`: dict[int, int]
   - [ ] Methods: `add_x_group`, `reorder`, `get_plot_groups`
   - [ ] JSON serialization: `to_dict()` / `from_dict()` for workspace file portability

3. **FormulaEngine → Python** — expression evaluator
   - [ ] Port the tokenizer → RPN → evaluator pipeline
   - [ ] Column references: `col("Name")`, `$Name`
   - [ ] Use numpy for vectorized evaluation (equivalent to MATLAB element-wise ops)
   - [ ] No `eval()` — same security constraint as MATLAB
   - [ ] Consider using `numexpr` for performance on large datasets

## Tier 2 — Medium Impact

4. **Frontend: DataWorkspaceView.vue** — Vue 3 spreadsheet component
   - [ ] AG Grid or TanStack Table for the spreadsheet widget
   - [ ] Column role badges in headers: (X), (Y), (E)
   - [ ] Right-click context menus: Set as X, Set as Y, Set as Error, Move, Sort
   - [ ] Live statistics bar (selection-based)
   - [ ] Formula bar for computed columns
   - [ ] Pinia store: `workspaceStore.ts` mirroring WorkspaceModel state

5. **WebSocket sync** — real-time model updates
   - [ ] FastAPI WebSocket endpoint at `/ws/workspace`
   - [ ] Events: `dataset_added`, `dataset_removed`, `mask_changed`, `selection_changed`
   - [ ] Frontend subscribes on mount, updates Pinia store on message
   - [ ] Bidirectional: frontend actions → REST API → model → WebSocket broadcast

6. **Workspace file format** — portable save/load
   - [ ] Define JSON schema for `.dwk` files (replace MAT-file binary)
   - [ ] Schema: `{ datasets: [...], masks: [...], column_roles: [...], computed_columns: [...] }`
   - [ ] Both MATLAB and Python can read/write the same `.dwk` JSON
   - [ ] Migration: MATLAB `save/load` → `jsondecode/jsonencode` for portability

## Tier 3 — Nice-to-Have

7. **Shared template JSON schema** — already partially done
   - [ ] Verify MATLAB `+templates/defaults/*.json` files are readable by Python
   - [ ] Column role metadata in templates (X/Y grouping, error associations)
   - [ ] Template matching in Python uses same 5-step cascade as MATLAB

8. **Performance benchmarks** — ensure Python port handles large datasets
   - [ ] Target: 1M rows with <1s sort/filter on modern hardware
   - [ ] AG Grid virtual scrolling for frontend
   - [ ] numpy/numexpr for formula evaluation

---

## Completed

(none yet — this is a design document for future implementation)
