# +dataWorkspace/ — DataWorkspace Package

Backend package for the DataWorkspace standalone spreadsheet GUI. Provides the shared data model, column metadata, formula evaluation, and autosave recovery that power both the standalone `DataWorkspace` window and the "Open in DataWorkspace" integration point inside BosonPlotter.

---

## Files

| File | Class / Type | Description |
|------|-------------|-------------|
| `WorkspaceModel.m` | `classdef` (handle) | Shared data model: owns datasets, masks, computed columns, column roles, and undo stack |
| `ColumnRoles.m` | `classdef` (value) | Per-dataset column metadata: display order, X→Y groupings, error-bar designations |
| `FormulaEngine.m` | `classdef` (static) | Safe tokenizer → RPN → evaluator pipeline for computed column formulas |
| `WorkspaceAutosave.m` | `classdef` (static) | Crash-recovery autosave: 2-min timer, snapshot to `prefdir`, restore on next startup |
| `createTableWidget.m` | function | Version-branched table factory: `uispreadsheet` on R2025a+, `uitable` fallback on R2022b+ |

---

## WorkspaceModel

`dataWorkspace.WorkspaceModel` is a handle class that owns all mutable GUI state. Both the `DataWorkspace` window and BosonPlotter's embedded table panel share the same instance, so changes in either window propagate automatically via events.

### Construction

```matlab
model = dataWorkspace.WorkspaceModel();
```

### Properties (read-only)

| Property | Type | Description |
|----------|------|-------------|
| `datasets` | `{1×N} cell` | Unified data structs (`.time`, `.values`, `.labels`, `.units`, `.metadata`) |
| `activeIdx` | `double` | 1-based index of the active dataset; 0 = none |
| `mask` | `{1×N} cell` | Per-dataset `[N×1]` logical vectors; `true` = row included |
| `computedColumns` | `{1×N} cell` | Per-dataset cells of computed column definition structs |
| `columnRoles` | `{1×N} cell` | Per-dataset `ColumnRoles` value objects |
| `undoStack` | `cell` | Snapshots for undo (max depth unbounded) |

### Dataset management

```matlab
model.addDataset(data, filepath, parserName)   % append; fires DataChanged
model.removeDataset(idx)                        % remove by index; fires DataChanged
model.setActive(idx)                            % change active; fires SelectionChanged
data = model.getData(idx)                       % returns corrData if present, else data
model.updateDataset(idx, ds)                    % replace in-place; fires DataChanged
n = model.count()                               % number of datasets
```

### Mask operations

Row masks let downstream code (plots, exports, statistics) ignore flagged outliers without destroying source data.

```matlab
model.setMask(idx, maskVec)          % replace full mask; fires MaskChanged
model.maskPoints(dsIdx, rowIndices)  % set specific rows to false
model.unmaskPoints(dsIdx, rowIndices)
model.maskRegion(dsIdx, xMin, xMax, yMin, yMax, colIdx)
model.unmaskAll(dsIdx)
m = model.getMask(dsIdx)             % [N×1] logical
```

### Computed columns

Formulas are evaluated once on `addComputedColumn` and stored as a value vector. Call `recomputeColumns` after the underlying data changes.

```matlab
model.addComputedColumn(dsIdx, name, expression, unit)
model.removeComputedColumn(dsIdx, colName)
model.recomputeColumns(dsIdx)
cols = model.getComputedColumns(dsIdx)
% cols{k}: struct with .name, .expression, .values ([N×1]), .unit
```

### Column roles

```matlab
model.setColumnRoles(dsIdx, roles)   % fires DataChanged
roles = model.getColumnRoles(dsIdx)  % returns ColumnRoles value object
```

### Undo

```matlab
model.pushUndo(label)    % save a snapshot before a destructive operation
snap = model.popUndo()   % restore; fires DataChanged + SelectionChanged
```

### Session persistence

```matlab
snap = model.createSnapshot()        % serializable struct (save to .dwk)
model.restoreFromSnapshot(snap)      % replace all state; fires events
```

### Multi-dataset operations

These return a new struct but do **not** add it to the model; call `addDataset` afterwards.

```matlab
result = model.datasetMath(idxA, op, idxB)   % op: '+' '-' '*' '/' 'ratio'
result = model.mergeDatasets(idxA, idxB)      % horizontal column concatenation
```

If row counts differ, dataset B is interpolated onto dataset A's time grid via `interp1` (linear, extrapolate).

---

## Events

All GUI observers attach listeners via `addlistener`. Events carry no custom data — handlers re-read model state directly.

| Event | Fired when |
|-------|-----------|
| `DataChanged` | Dataset added, removed, or modified; computed columns changed; column roles changed |
| `SelectionChanged` | `activeIdx` changes |
| `MaskChanged` | Row mask changes for any dataset |

```matlab
model = dataWorkspace.WorkspaceModel();
addlistener(model, 'DataChanged', @(~,~) disp('data changed'));
```

---

## ColumnRoles

`dataWorkspace.ColumnRoles` is a **value class** — methods return a modified copy; the original is unchanged. One instance is stored per dataset in `model.columnRoles`.

Column index convention: `0` = `.time` (X axis), `1..M` = `.values(:, idx)`.

```matlab
roles = dataWorkspace.ColumnRoles(numCols)

% X→Y groupings (multi-X support)
roles = roles.addXGroup(xColIdx, yColIndices)
roles = roles.removeXGroup(groupIdx)

% Display order
roles = roles.reorder(newOrder)   % newOrder must be a permutation of 1:N

% Error bar designation
roles = roles.setErrorFor(yColIdx, errColIdx)
roles = roles.clearErrorFor(yColIdx)
errIdx = roles.getErrorFor(yColIdx)   % returns 0 if none

% Skip columns from plots
roles = roles.setSkipped(colIndices, tf)

% Query
n = roles.numColumns()

% Extract plot-ready groups
groups = roles.getPlotGroups(dataStruct)
% groups{k}: struct with .xData, .yData, .labels, .units, .errorData (or [])
```

Default state: one group with `xCol=0` (`.time`) and all value columns as Y; no skipped columns; no error bar designations. This is fully backward-compatible with existing code.

---

## FormulaEngine

`dataWorkspace.FormulaEngine` provides a safe formula evaluator with no `eval()`, `feval()` with dynamic strings, or `str2func()` on user input. Dispatch uses `containers.Map` of function handles.

### Column reference syntax

| Syntax | Resolves to |
|--------|------------|
| `col("Temperature")` | Column matching label "Temperature" (case-insensitive) |
| `col('Temperature')` | Same, single-quoted form |
| `col(0)` | `.time` vector (X axis) |
| `$Temperature` | Short form for `col("Temperature")` |
| `$X` | Short form for `col(0)` |

### Supported operators

`+`, `-`, `*`, `/`, `^` (all element-wise). Standard precedence; `^` is right-associative.

### Supported functions

`sin`, `cos`, `tan`, `exp`, `log`, `log10`, `sqrt`, `abs`, `round`, `floor`, `ceil`, `diff`, `cumsum`, `cumtrapz`

Constants: `pi`, `e`

`diff` returns an `[N-1]` vector; the engine prepends `NaN` to restore length N.

### API

```matlab
% One-shot evaluate:
result = dataWorkspace.FormulaEngine.evaluate(expression, dataStruct)
% result is [N×1] double

% Lower-level pipeline:
tokens = dataWorkspace.FormulaEngine.tokenize(expression)
rpn    = dataWorkspace.FormulaEngine.toRPN(tokens)
result = dataWorkspace.FormulaEngine.evalRPN(rpn, dataStruct)

% Circular-reference guard:
tf = dataWorkspace.FormulaEngine.hasCircularRef(expression, dependsOnNames)
```

### Examples

```matlab
data = parser.importQDVSM('sample.dat', XAxis='field', YAxis='moment');

% Convert Oe to kA/m
result = dataWorkspace.FormulaEngine.evaluate('$Field / 79.5775', data);

% Natural log of moment
result = dataWorkspace.FormulaEngine.evaluate('log($Moment)', data);

% Pythagorean combination of two columns
result = dataWorkspace.FormulaEngine.evaluate('sqrt($X^2 + $Field^2)', data);

% Via model (saves result and fires DataChanged):
model.addComputedColumn(1, 'FieldSI', '$Field / 79.5775', 'kA/m');
```

---

## WorkspaceAutosave

Writes a recovery snapshot to `prefdir/dataworkspace_autosave.dwk` every 2 minutes. On a clean close, the file is deleted. On the next startup, if the file exists, `DataWorkspace` offers to restore it.

```matlab
dataWorkspace.WorkspaceAutosave.start(model)   % begin timer (skips if model is empty)
dataWorkspace.WorkspaceAutosave.stop()          % stop + delete timer
dataWorkspace.WorkspaceAutosave.save(model)     % write snapshot immediately
tf = dataWorkspace.WorkspaceAutosave.check()    % true if recovery file exists
dataWorkspace.WorkspaceAutosave.restore(model)  % load snapshot into model; delete file
dataWorkspace.WorkspaceAutosave.cleanup()       % stop timer + delete recovery file
```

The autosave file is a `.mat` (v7.3 format) containing a single variable `snap` produced by `model.createSnapshot()`. Autosave failures are silent — the timer catches and discards all errors to avoid disrupting a live session.

---

## createTableWidget

```matlab
[widget, isSpreadsheet] = dataWorkspace.createTableWidget(parent)
[widget, isSpreadsheet] = dataWorkspace.createTableWidget(parent, Data=C, ColumnName=names, ...)
```

Returns a `uispreadsheet` on R2025a+ (with `EnableSorting=true` and `EnableFiltering=true`) or a `uitable` on R2022b–R2024b. Both widgets expose:

- `.Data`, `.ColumnName`, `.ColumnEditable`, `.CellEditCallback`, `.CellSelectionCallback`

On `uispreadsheet`, `CellEditCallback` and `CellSelectionCallback` are added as dynamic properties that forward from `DataChangedFcn` / `SelectionChangedFcn` — callers need no version branching.

A one-time notice is printed to the Command Window when the `uitable` fallback activates.

---

## Integration with BosonPlotter

BosonPlotter constructs a `WorkspaceModel` at startup and stores it in `appData.model`. The toolbar "Workspace" button and the embedded "Open in DataWorkspace" button both call:

```matlab
DataWorkspace(Model=appData.model)
```

Both windows share the same model instance; any dataset loaded in either window immediately appears in the other. Events fire synchronously, so the shared model is always consistent.

```matlab
% Access the shared model from the BosonPlotter workspace
% (for scripting or testing — not for production GUI code)
api = DataWorkspace(Visible='off', Model=existingModel);
model = api.getModel();
```

---

## See Also

- `DataWorkspace.m` — launcher and GUI (top-level function)
- `BosonPlotter.m` — primary analysis GUI (shares WorkspaceModel)
- `parser.createDataStruct` — canonical way to build the unified data struct
- `bosonPlotter.filterRows` — the filter expression evaluator used by the filter bar
