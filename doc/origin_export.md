# Exporting Data to OriginPro

This guide covers three ways to move data from the thin film toolkit into OriginPro: **Origin-formatted CSV files**, **clipboard copy**, and **direct COM automation**.

---

## 1. Origin ASCII CSV (Script & GUI)

The toolkit can write CSV files with Origin's native multi-row header format. When Origin imports these files, column names, units, and designations (X/Y/yErr) are mapped automatically -- no manual column setup required.

### What Origin ASCII looks like

A standard CSV has one header row:

```
Magnetic Field (Oe),Moment (emu),M. Std. Err. (emu)
50000,0.00234,1.2e-06
...
```

An Origin ASCII file has three header rows:

```
Magnetic Field,Moment,M. Std. Err.        ← Long Name
Oe,emu,emu                                ← Units
X,Y,yEr                                   ← Column Designations
50000,0.00234,1.2e-06
...
```

Origin recognises these rows on import and populates the **Long Name**, **Units**, and **Comments** header rows in the worksheet. The `yEr` designation tells Origin the column is an error bar for the preceding Y column.

### Script usage

```matlab
% Import data
data = parser.importAuto('VSM_MvsH.dat');

% Standard CSV (single header row)
guiSaveCSV(data, 'output.csv');

% Origin ASCII (three header rows)
guiSaveCSV(data, 'output.csv', [], [], 'origin');
```

The fifth argument `fmt` controls the format:
- `'standard'` (default) -- single combined header row: `Moment (emu)`
- `'origin'` -- three-row Origin header: Long Name / Units / Designations

#### With corrected + raw columns

```matlab
corrected = applyMyCorrections(data);  % your correction pipeline
guiSaveCSV(corrected, 'output.csv', data, [], 'origin');
%                                       ↑raw  ↑asym  ↑format
```

When `dRaw` is provided, columns are suffixed `[corr]` / `[raw]` in long names.

#### Full signature

```matlab
guiSaveCSV(d, fp)                       % data only, standard CSV
guiSaveCSV(d, fp, dRaw)                 % + raw columns
guiSaveCSV(d, fp, dRaw, asymData)       % + spin asymmetry columns
guiSaveCSV(d, fp, dRaw, asymData, fmt)  % fmt = 'standard' | 'origin'
```

### GUI usage

1. Load a file in `dataImportGUI`
2. Set the **CSV Format** dropdown (below the save path field) to **Origin ASCII**
3. Click **Save CSV** (or **Batch Export All CSV** for all loaded files)
4. Open the `.csv` in Origin: **File > Import > CSV** -- column metadata auto-populates

The format dropdown applies to all CSV export paths: single save, batch export, and neutron consolidated export.

### Importing in Origin

1. **File > Import > CSV (or ASCII)**
2. Check **"Show Options Dialog"** on the first import
3. In the import wizard, set:
   - Header lines: `3`
   - Long Name row: `1`
   - Units row: `2`
   - Comments row: `3`
4. Click **OK** -- columns appear with correct names, units, and X/Y/yErr designations
5. Save as an import filter for one-click re-use

Alternatively, **drag and drop** the `.csv` onto an Origin worksheet. If your default filter is configured for 3-header-row ASCII, it works immediately.

---

## 2. Clipboard Copy (GUI)

The **Copy Data to Clipboard** button in the Save panel copies data as tab-delimited text with Origin's three header rows.

### How to use

1. Click **Copy Data to Clipboard** in the Save / Export panel
2. A dialog lists all loaded datasets -- select one or more
3. Click **OK** -- data is copied to the system clipboard
4. In Origin: **Edit > Paste** (or Ctrl+V into a worksheet)

### What gets copied

- **Tab-delimited** (tabs as column separators, not commas)
- **Three header rows**: Long Name, Units, Column Designations
- **Multiple datasets**: when you select more than one, columns are prefixed with the filename (e.g., `sample1_Moment`, `sample2_Moment`)
- **Corrected data preferred**: uses `corrData` if available, falls back to raw `data`

### Pasting into Origin

When you paste into an empty Origin worksheet:
1. Origin may ask how to interpret the clipboard -- choose **ASCII with header**
2. The three header rows map to Long Name / Units / Comments
3. If Origin pastes everything as data rows, manually set **Header Lines = 3** in the worksheet properties

This also works for pasting into **Excel**, **Google Sheets**, or any text editor.

---

## 3. COM Automation (`utilities.toOrigin`)

For fully automated workflows, the `utilities.toOrigin` function sends data directly to OriginPro via Windows COM. No files are written -- data appears instantly in an Origin worksheet.

### Prerequisites

- **OriginPro installed** on the same Windows machine as MATLAB
- Origin's COM server must be registered (this happens automatically during Origin installation)
- MATLAB must be running on Windows (COM is Windows-only)

To check if COM is available:

```matlab
try
    o = actxserver('Origin.Application');
    o.release();
    disp('Origin COM is available');
catch
    disp('Origin COM not available');
end
```

### Basic usage

```matlab
data = parser.importAuto('VSM_MvsH.dat');

% Send to Origin -- returns true on success, false if Origin unavailable
ok = utilities.toOrigin(data);
```

This opens OriginPro (or connects to a running instance), creates a workbook named `MatlabExport`, and populates a worksheet with:
- Column 1: X-axis data (with correct Long Name and Unit)
- Column 2+: Y-axis channels (each with Long Name, Unit, and X/Y/yErr designation)

### Name-value options

```matlab
ok = utilities.toOrigin(data, ...
    'SheetName',  'M_vs_H', ...          % worksheet name (default: from metadata)
    'BookName',   'Sample_A', ...         % workbook name (default: 'MatlabExport')
    'AxisLabels', struct('x', 'Field (Oe)', 'y', 'Moment (emu)'), ...
    'LogY',       true, ...               % log Y scale
    'LogX',       false, ...              % log X scale
    'Visible',    true);                  % show Origin window
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `SheetName` | string | from `metadata.source` | Worksheet tab name |
| `BookName` | string | `'MatlabExport'` | Workbook (window) name |
| `AxisLabels` | struct | empty | `.x` and `.y` fields for axis label text |
| `LogY` | logical | `false` | Set Y axis to log10 scale |
| `LogX` | logical | `false` | Set X axis to log10 scale |
| `Visible` | logical | `true` | Make Origin window visible |

### What the function does internally

1. Calls `actxserver('Origin.Application')` to connect to Origin
2. Creates a new workbook via LabTalk: `win -t data BookName`
3. Adds columns and sets their type (4=X, 1=Y, 3=yErr), long name, and unit
4. Transfers data via `origin.PutWorksheet(sheetName, matrix, 0, 0)`
5. Optionally sets axis scales and labels via LabTalk
6. Releases the COM object (guaranteed by `onCleanup`)

### Graceful failure

`toOrigin` never throws an error if Origin is unavailable. It returns `false`:

```matlab
ok = utilities.toOrigin(data, 'SheetName', 'scan1');
if ~ok
    % Fall back to Origin ASCII CSV
    guiSaveCSV(data, 'scan1.csv', [], [], 'origin');
    fprintf('Origin unavailable. Saved Origin ASCII to scan1.csv\n');
end
```

### Batch workflow example

```matlab
files = dir('measurements/*.dat');
for i = 1:numel(files)
    fp   = fullfile(files(i).folder, files(i).name);
    data = parser.importAuto(fp);
    [~, name, ~] = fileparts(fp);

    ok = utilities.toOrigin(data, ...
        'SheetName', name, ...
        'BookName',  'BatchImport');

    if ok
        fprintf('Sent %s to Origin\n', name);
    else
        guiSaveCSV(data, fullfile('output', [name '.csv']), [], [], 'origin');
        fprintf('Saved %s as Origin ASCII\n', name);
    end
end
```

### GUI "Send to Origin" button

The GUI wraps `utilities.toOrigin` in a single click:

1. Click **Send to Origin** in the Save / Export panel
2. If Origin is running/installed: data appears in a new worksheet with axis labels and log scale matching the current GUI state
3. If Origin is not available: data is automatically copied to the clipboard instead, with an informative message

---

## 4. Column Designation Reference

Origin uses numeric codes for column roles. The toolkit maps these automatically:

| Designation | Origin Code | When assigned |
|-------------|-------------|---------------|
| X | 4 | First column (x-axis data) |
| Y | 1 | Data columns (Moment, R, Intensity, etc.) |
| yErr | 3 | Error columns (labels containing `err`, `dR`, `std`, `sigma`) |

The mapping is automatic based on column labels. In the resulting Origin worksheet:
- **Y** columns plot as data curves
- **yErr** columns plot as error bars on the preceding Y column
- **X** columns define the horizontal axis

---

## 5. Workflow Comparison

| Method | Requires Origin? | Metadata? | Best for |
|--------|-----------------|-----------|----------|
| Origin ASCII CSV | No | Full (3 header rows) | Archival, sharing, batch processing |
| Clipboard copy | No | Full (3 header rows) | Quick interactive transfer, also works with Excel |
| COM automation | Yes (Windows) | Full + axis styling | Automated pipelines, repeated analysis |

**Recommended workflow for most users:**
1. Use **Origin ASCII CSV** as the default export format (set the dropdown once)
2. Use **Copy Data to Clipboard** for quick one-off transfers
3. Use **COM automation** in scripts when you need a fully hands-free pipeline
