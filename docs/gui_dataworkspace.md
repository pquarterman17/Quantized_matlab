# DataWorkspace — Feature Reference

> For core conventions and quick-start, see [CLAUDE.md](../CLAUDE.md). For the backend API, see [+dataWorkspace/README.md](../+dataWorkspace/README.md).

DataWorkspace is a standalone spreadsheet GUI for browsing, transforming, and exporting toolbox datasets. It shares a live data model with BosonPlotter so both windows stay in sync automatically.

---

## Getting Started

```matlab
DataWorkspace                % open interactively
```

The window opens with no data loaded. Use **+ Add Files** in the toolbar to import files — it accepts any format recognised by `parser.importAuto` (`.dat`, `.csv`, `.txt`, `.xls`, `.xlsx`, `.xrdml`, `.raw`).

The left panel lists all loaded datasets. Clicking a name in the list activates that dataset; its columns appear in the spreadsheet on the right.

**Column layout in the table:** the first column is always the X axis (`.time`); subsequent columns correspond to `.values(:,1)`, `.values(:,2)`, etc., followed by any computed columns. The units row (above the table) shows the unit string for each column.

---

## Shared Model with BosonPlotter

BosonPlotter creates a `WorkspaceModel` at startup. The toolbar **Workspace** button and the embedded **Open in DataWorkspace** button inside BosonPlotter's Data Table panel both open DataWorkspace connected to that same model:

```
BosonPlotter ──shares── WorkspaceModel ──observed by── DataWorkspace
```

Any dataset loaded in BosonPlotter appears immediately in DataWorkspace (and vice versa). Row masks, computed columns, and column roles are also shared. Events fire synchronously, so both windows always reflect the same state.

To open a pre-connected DataWorkspace from the Command Window:

```matlab
% Attach to an already-running BosonPlotter session
% (BosonPlotter stores its model in appData — this is for scripting/testing only)
api = DataWorkspace(Visible='off', Model=existingModel);
model = api.getModel();
```

---

## Programmatic API

DataWorkspace returns an API struct when called with an output argument:

```matlab
api = DataWorkspace(Visible='off')   % headless (for tests or scripting)

api.fig           % uifigure handle
api.addFiles(f)   % load file paths (char or cell of chars)
api.getModel()    % returns the WorkspaceModel handle
```

Typical scripted workflow:

```matlab
api = DataWorkspace(Visible='off');
api.addFiles({'sample.dat', 'reference.dat'});
model = api.getModel();

% Read back data with mask applied
data = model.getData(1);
mask = model.getMask(1);
filteredValues = data.values(mask, :);
```

---

## Toolbar Actions

| Button | Action |
|--------|--------|
| **+ Add Files** | File picker; multi-select supported; delegates to `parser.importAuto` |
| **− Remove** | Remove dataset(s) selected in the left panel |
| **Export CSV** | Export the active dataset (including computed columns) to a CSV file |
| **Dataset Math...** | Element-wise arithmetic between two datasets (see below) |
| **Merge Columns...** | Horizontally concatenate Y columns from two datasets (see below) |
| **Plot...** | Write the active dataset to a temp CSV and open BosonPlotter |
| **Add Column...** | Open the computed column dialog (see Column Formulas below) |
| **Save Workspace...** | Save all datasets and metadata to a `.dwk` file |
| **Load Workspace...** | Load a `.dwk` file, replacing all current state |

The status label (top-right) shows the dataset count and brief operation results.

---

## Column Roles

Column roles control which column is the X axis for each group of Y columns, the visual display order, and error bar pairing. They are managed from the right-click context menu on any column header or cell.

### Multi-X grouping

By default all Y columns share `.time` as their X axis. To assign a different X column to a subset of Y columns, use the `WorkspaceModel` API directly:

```matlab
model = api.getModel();
roles = model.getColumnRoles(1);

% Make column 2 the X axis for columns 3 and 4
roles = roles.addXGroup(2, [3 4]);
model.setColumnRoles(1, roles);
```

`getPlotGroups` then returns two groups: one with `.time` as X for column 1, and one with column 2 as X for columns 3 and 4. BosonPlotter uses this when rendering the active dataset.

### Display order

Right-click a cell in the column you want to move, then choose **Move Column Left**, **Move Column Right**, or **Move Column to Start**. The reordering is stored in `ColumnRoles.displayOrder` and fires `DataChanged` so BosonPlotter re-renders immediately.

### Error bar designation

Right-click a cell in the error column and choose **Set as Error Bar for...**. A picker lists the other Y columns; select the one this column provides error data for. The designation appears in the stats bar and is used by BosonPlotter's figure builder to draw error bars.

To remove a designation: right-click the Y column and choose **Clear Error Bar Role**.

---

## Column Formulas

Click **Add Column...** to open the computed column dialog.

**Fields:**
- **Column name** — label for the new column (e.g. `FieldSI`)
- **Unit** — optional unit string (e.g. `kA/m`)
- **Formula** — expression referencing existing columns

A live preview shows the first 10 computed values as you type. Errors are shown in red below the formula field.

### Formula syntax

| Syntax | Meaning |
|--------|---------|
| `$ColumnName` | Reference column by label (case-insensitive) |
| `col("ColumnName")` | Same, explicit form |
| `$X` or `col(0)` | The X axis (`.time`) |
| `col(2)` | `.values(:,2)` by numeric index |
| `pi`, `e` | Mathematical constants |

**Operators:** `+`, `-`, `*`, `/`, `^` (element-wise; `^` is right-associative)

**Functions:** `sin`, `cos`, `tan`, `exp`, `log`, `log10`, `sqrt`, `abs`, `round`, `floor`, `ceil`, `diff`, `cumsum`, `cumtrapz`

`diff` produces an `[N-1]` vector; the engine prepends `NaN` to maintain length N.

### Examples

```
$Field / 79.5775               % Oe → kA/m conversion
col("Moment") * 1000           % emu → memu
log10($Intensity)              % log-scale intensity
sqrt($X^2 + $Field^2)          % vector magnitude
cumtrapz($Moment) * $Field     % running integral (energy)
```

Computed columns are stored in the model and included in CSV exports. To edit a formula: right-click a cell in the computed column and choose **Edit Formula...**. To remove: right-click and choose **Remove Column**.

---

## Row Masking

Masked rows are excluded from statistics, exports, and (when the shared model is active) from BosonPlotter plots. Source data is never modified — masking is a filter layer on top of the raw values.

**To mask rows:** select one or more rows, right-click, choose **Mask selected rows**. Masked rows are visually dimmed in the table (alternating background colour indicates masked state).

**To unmask:** right-click selected masked rows and choose **Unmask selected rows**, or choose **Unmask all rows** to reset the entire dataset.

The status bar shows the current masked-row count: `N rows masked`.

To mask programmatically:

```matlab
model = api.getModel();
model.maskPoints(1, [5 10 15]);     % mask rows 5, 10, 15 of dataset 1
model.unmaskAll(1);                 % reset

% Mask by value range:
model.maskRegion(1, 0, 100, -0.01, 0.01, 2);
% masks rows where X ∈ [0,100] AND values(:,2) ∈ [-0.01, 0.01]
```

---

## Sorting and Filtering

### R2025a+ (uispreadsheet)

Built-in sort and filter controls appear in the column headers. Click a header to sort; use the filter icon for per-column filtering. The filter bar below the toolbar is hidden in this mode.

### R2022b–R2024b (uitable fallback)

The filter bar is visible. Type an expression and press Enter (or wait for the `ValueChanged` event). The expression is evaluated by `bosonPlotter.filterRows`.

**Filter syntax:**

```
Temperature > 300
Field < 0
Moment > 0 & Temperature < 200
between(x, 30, 60)          % x refers to the X axis (time column)
```

Column names in filter expressions match `.labels` case-insensitively. `x` always refers to `.time`.

Sort via the context menu: right-click a cell, choose **Sort Ascending** or **Sort Descending**. **Clear Sort** restores the original row order. Sort and filter combine: sort is applied to the set of rows that pass the current filter.

---

## Live Statistics Bar

Selecting cells updates the stats bar (below the table) with:

```
Count: N    Mean: x.xxx    Std: x.xxx    Min: x.xxx    Max: x.xxx
```

Statistics are computed over the selected cells, not the entire column. Masked rows are excluded from the selection automatically.

---

## Dataset Math

Requires at least two loaded datasets. Click **Dataset Math...**, then:

1. Choose **Dataset A** and **Dataset B** from the dropdowns
2. Choose an **Operation**: `+`, `-`, `*`, `/`, `Ratio (A/B)`
3. Click **Compute**

The result is added as a new dataset. If row counts differ, dataset B is interpolated onto dataset A's time grid (linear interpolation, extrapolate). The operation applies element-wise to all value columns up to the minimum of the two column counts.

Result labels follow the pattern `LabelA op LabelB` (e.g. `Moment plus Moment`).

---

## Merge Columns

Horizontally concatenates the Y columns of two datasets. Click **Merge Columns...**, choose **Base (A)** and **Append (B)**, then click **Merge**. Dataset B is interpolated onto dataset A's time grid. The result has all Y columns of A followed by all Y columns of B.

---

## Clipboard Paste

Press **Ctrl+V** anywhere in the DataWorkspace window to import tab-separated or space-separated numeric data from the clipboard. The pasted data becomes a new dataset named `clipboard`. This is useful for copying a column from Excel or another application without saving a file first.

---

## Session Management

### Saving

Click **Save Workspace...**. The suggested filename is derived from the first dataset's source file. The file is a `.dwk` file (a `.mat` v7.3 archive containing a `snap` struct).

The snapshot contains: all datasets, row masks, column roles, computed column definitions, and the active dataset index.

### Loading

Click **Load Workspace...**. Loading replaces **all** current state after pushing an undo snapshot. Autosave resumes immediately after a successful load.

### Autosave and crash recovery

DataWorkspace automatically saves a recovery snapshot every 2 minutes to:

```
prefdir/dataworkspace_autosave.dwk
```

On a clean close (window X button), the recovery file is deleted. If the file is present at startup, a dialog offers to **Restore** or **Discard** it.

To locate `prefdir` from the Command Window:

```matlab
prefdir   % returns the full path
```

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Ctrl+V | Paste clipboard data as a new dataset |

---

## Version Compatibility

| MATLAB release | Table widget | Sort/filter |
|----------------|-------------|-------------|
| R2025a+ | `uispreadsheet` | Built-in column header controls |
| R2022b–R2024b | `uitable` | Context menu sort; filter expression bar |

A one-time notice is printed to the Command Window when the `uitable` fallback is active:

```
Note: Using uitable fallback. Upgrade to R2025a+ for built-in sort/filter.
```

The API surface (`Data`, `ColumnName`, `ColumnEditable`, `CellEditCallback`, `CellSelectionCallback`) is identical across both paths, so all context menu, mask, and column-role operations work on both versions.
