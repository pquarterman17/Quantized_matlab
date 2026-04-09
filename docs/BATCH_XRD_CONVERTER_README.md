# Batch XRD Converter — Usage Guide

Convert multiple XRD data files (XRDML, Rigaku, Bruker) to CSV or Origin ASCII format in batch mode.

---

## Quick Start

### GUI Method (Easiest)

**From the main BosonPlotter:**
```matlab
BosonPlotter()
```
1. Click the **"Batch Convert XRD"** button (green-gold, bottom of the Save panel)
2. Select a folder containing XRD files
3. Choose files (all pre-selected by default)
4. Set output format and options
5. Click **Convert**

**Standalone (without opening BosonPlotter):**
```matlab
xrdConvertGUI()
```

### Script Method (Programmatic)

```matlab
% Convert all XRD files in a folder to standard CSV
results = scripts.batchConvertXRD('test_datasets/XRDML/');

% Convert specific files
results = scripts.batchConvertXRD([
    "sample1.xrdml"
    "sample2.xrdml"
]);

% Custom output directory
results = scripts.batchConvertXRD('measurements/', OutputDir='output/');

% Origin ASCII format, CPS only, no metadata
results = scripts.batchConvertXRD('data/', ...
    Format="origin", ...
    Intensity="cps", ...
    IncludeMetadata=false);
```

---

## Supported File Formats

| Format | Extension | Parser | Notes |
|--------|-----------|--------|-------|
| PANalytical XRDML | `.xrdml` | `importXRDML` | XML-based; includes sample info, anode data |
| Rigaku SmartLab | `.raw` | `importRigaku_raw` | Binary format; magic bytes: `"FI"` |
| Bruker | `.brml` | `importBruker` | ZIP+XML format; auto-detects v3 binary too |
| Rigaku/Bruker v3 | `.raw` | Auto-detected | Magic bytes: `"RAW1.01"` → Bruker v3 |

All files are **auto-detected by extension and magic bytes** — no manual format selection needed.

---

## GUI Usage Details

### Layout

```
┌─────────────────────────────────────────┐
│ XRD Batch Converter                 [x] │
├─────────────────────────────────────────┤
│ [Browse Folder...] [path/to/folder   ] │
│                                         │
│ ┌─ Files (multi-select) ──────────────┐│
│ │ [x] sample1.xrdml        [XRDML]    ││
│ │ [x] sample2.xrdml        [XRDML]    ││
│ │ [x] scan3.raw            [Rigaku]   ││
│ │ [ ] scan4.brml           [Bruker]   ││
│ └─────────────────────────────────────┘│
│                                         │
│ [Select All]  [Deselect All]  4 files  │
│ Format:    [Standard CSV        v]     │
│ Intensity: [Both (cps + counts) v]     │
│ Output:    [Same folder v]             │
│ [x] Include metadata header            │
│                                         │
│ [============ Convert ===============] │
│                                         │
│ ┌─ Log ──────────────────────────────┐ │
│ │ (hidden until conversion starts)   │ │
│ └────────────────────────────────────┘ │
│ Ready (4 files)                        │
└─────────────────────────────────────────┘
```

### Step-by-Step

1. **Select Folder**
   - Click "Browse Folder..." button
   - Navigate to folder containing XRD files
   - GUI auto-scans and populates file list with badges:
     - `[XRDML]` = PANalytical XRDML
     - `[Rigaku]` = Rigaku SmartLab `.raw`
     - `[Bruker]` = Bruker `.brml` or v3 `.raw`
     - `[???]` = Unknown `.raw` file (not an XRD file)

2. **Select Files**
   - All files pre-selected by default
   - Uncheck to skip a file
   - Use "Select All" / "Deselect All" buttons for convenience

3. **Choose Format**
   - **Standard CSV** (default): Comma-delimited, single header row
   - **Origin ASCII**: Tab-delimited, 3-row header (Long Name / Units / Designation)
   - **Send to Origin**: COM automation (launches Origin workbook, requires Origin installed)

4. **Choose Intensity**
   - **Both (cps + counts)** (default): Two columns, auto-converts between formats using `countingTime` metadata
   - **CPS only**: Counts per second only
   - **Counts only**: Raw counts only

5. **Set Output Location**
   - **Same folder as source** (default): Each file's `.csv` placed next to original
   - **Custom folder**: All `.csv` files go to a single output directory

6. **Options**
   - **Include metadata header**: Write `#`-prefixed comment block at top of CSV (default: enabled)
     - Contains: source file, parser type, sample name, anode info, wavelength, 2θ range, counting time, export date
     - Disabled for "Send to Origin" format

7. **Convert**
   - Click **Convert** button
   - Progress log appears showing per-file status: `[OK]` or `[ERR]`
   - Status line shows summary: "3 OK, 1 failed"

---

## Script Usage (Programmatic API)

### Basic Syntax

```matlab
results = scripts.batchConvertXRD(files, Name=Value options)
```

### Input: `files`

Either a **directory path** or **file list**:

```matlab
% Directory — auto-discovers XRD files
results = scripts.batchConvertXRD('test_datasets/XRDML/');

% Explicit file list (cell array or string array)
results = scripts.batchConvertXRD({
    'sample1.xrdml'
    'sample2.xrdml'
    'scan3.raw'
});

results = scripts.batchConvertXRD([
    "C:/data/sample1.xrdml"
    "C:/data/sample2.xrdml"
]);
```

### Options (Name-Value)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `Format` | string | `"standard"` | `"standard"`, `"origin"`, or `"com"` |
| `OutputDir` | string | `""` | Empty = same folder as source; otherwise custom path |
| `Recursive` | logical | `false` | When input is a folder, recurse into subdirectories |
| `Intensity` | string | `"both"` | `"both"`, `"cps"`, or `"counts"` |
| `IncludeMetadata` | logical | `true` | Write metadata header block in CSV |
| `Verbose` | logical | `true` | Print progress to console |
| `ProgressFcn` | function_handle | `[]` | Callback: `@(k, n, filename)` for live updates |

### Output: `results` Struct Array

Each element contains:

```matlab
results(k).name          % filename (no path), e.g., "sample1.xrdml"
results(k).filepath      % full source path, e.g., "C:/data/sample1.xrdml"
results(k).outputFile    % full output path, e.g., "C:/data/sample1.csv" (empty for COM)
results(k).data          % parsed data struct (empty [] if error)
results(k).error         % error message ('' if OK)
```

### Usage Examples

#### Example 1: Convert folder to standard CSV

```matlab
results = scripts.batchConvertXRD('measurements/xrd/');

% Check results
nOk = sum(cellfun(@isempty, {results.error}));
nErr = sum(~cellfun(@isempty, {results.error}));
fprintf('Converted: %d OK, %d failed\n', nOk, nErr);

% Show first error if any
if any(~cellfun(@isempty, {results.error}))
    badIdx = find(~cellfun(@isempty, {results.error}), 1);
    fprintf('Error: %s\n', results(badIdx).error);
end
```

#### Example 2: Convert with custom output directory

```matlab
results = scripts.batchConvertXRD('raw_data/', ...
    OutputDir='processed/xrd/', ...
    Format='origin');

% All output goes to 'processed/xrd/' regardless of input folder structure
```

#### Example 3: Batch convert with progress bar

```matlab
fig = uifigure('Name', 'XRD Conversion Progress');
pb = uiprogressbar(fig, 'Value', 0);
lbl = uilabel(fig, 'Text', 'Starting...');

results = scripts.batchConvertXRD('data/', ...
    ProgressFcn=@(k, n, fname) updateProgress(k, n, fname, pb, lbl));

function updateProgress(k, n, fname, pb, lbl)
    pb.Value = k / n;
    [~, fn, ~] = fileparts(fname);
    lbl.Text = sprintf('%d/%d: %s', k, n, fn);
    drawnow;
end
```

#### Example 4: Convert only CPS, skip metadata

```matlab
results = scripts.batchConvertXRD('scans/', ...
    Intensity='cps', ...
    IncludeMetadata=false, ...
    Verbose=false);

% Get list of successfully converted files
successFiles = {results(cellfun(@isempty, {results.error})).outputFile}';
disp(successFiles);
```

#### Example 5: Recursive folder scan

```matlab
results = scripts.batchConvertXRD('/large_experiment/', ...
    Recursive=true, ...
    OutputDir='/processed/', ...
    Format='origin');

% Find all errors
errors = {results(~cellfun(@isempty, {results.error})).error}';
errorNames = {results(~cellfun(@isempty, {results.error})).name}';

if ~isempty(errors)
    fprintf('Failed files:\n');
    for i = 1:numel(errorNames)
        fprintf('  %s: %s\n', errorNames{i}, errors{i});
    end
end
```

---

## Output Formats

### Standard CSV

Default comma-delimited format with optional metadata header:

```
# XRD Batch Export
# Source: C:\data\sample.xrdml
# Parser: importXRDML
# Sample: La2NiO4
# Anode: Cu (40.0 kV / 44.0 mA)
# Wavelength: Ka1 = 1.54056 A
# 2-theta range: 10.0000 - 70.0000 deg
# Step size: 0.026 deg (2308 points)
# Counting time: 2.400 s/point
# Export date: 2026-03-07 14:32:15
#
2-Theta (deg),Intensity (cps),Intensity (counts)
10.0000,1234.5,2962.8
10.0260,1256.2,3014.9
...
```

**Use when:** Importing into spreadsheets, minimal header overhead, compatible with most software.

### Origin ASCII

Tab-delimited format with three header rows (suitable for OriginPro import):

```
# XRD Batch Export
# Source: C:\data\sample.xrdml
# Parser: importXRDML
# Sample: La2NiO4
# ...
2-Theta (deg)	Intensity (cps)	Intensity (counts)
deg	cps	counts
X	Y	Y
10.0000	1234.5	2962.8
10.0260	1256.2	3014.9
...
```

**Header rows:**
- Row 1: Long names (e.g., "2-Theta (deg)")
- Row 2: Units (e.g., "deg", "cps")
- Row 3: Designations (e.g., "X" for x-axis, "Y" for data)

**Use when:** Opening directly in OriginPro, or need symbolic metadata rows.

### Send to Origin (COM)

Bypasses CSV files entirely; sends data directly to an open OriginPro instance via COM automation:
- Creates a workbook named `XRD_BatchExport`
- One worksheet per file (name truncated to 30 characters for Origin limit)
- Data formatted with Long Name / Units / Designation rows

**Use when:** You have OriginPro installed and want data directly in worksheets.

---

## Intensity Conversion Logic

The batch converter intelligently handles intensity units using metadata:

### "Both (cps + counts)"

The script determines which unit the original file contains, then converts to the other if possible:

```matlab
if original_unit is 'cps'
    if countingTime is available
        counts_col = cps_values × countingTime
    else
        % Can't convert — output cps only with warning
    end
else % original is 'counts'
    if countingTime is available
        cps_col = counts_values ÷ countingTime
    else
        % Can't convert — output counts only with warning
    end
end
```

**Example:**
- Rigaku `.raw` files typically record counts at 2.4 s/point
- Converter outputs both: `Intensity (cps)` and `Intensity (counts)`
- No re-parsing required; conversion happens at export time

### "CPS only" or "Counts only"

If the requested unit differs from the original and `countingTime` is unavailable, a warning is issued:

```
⚠️ Warning: Cannot convert counts to cps (countingTime not available). Writing counts.
```

---

## Troubleshooting

### "No XRD files found"

**Problem:** Folder scan returned zero files.

**Solutions:**
1. Verify folder contains `.xrdml`, `.brml`, or `.raw` files
2. For `.raw` files: Check that they are actually XRD files (not magnetometry, DSC, etc.)
   - Batch converter uses magic-byte filtering; non-XRD `.raw` files are skipped automatically
3. Check file extensions are lowercase (converter looks for `.xrdml`, `.raw`, `.brml` in lowercase)

### "Cannot open file for writing: ..."

**Problem:** Output directory doesn't exist or isn't writable.

**Solutions:**
1. Verify output directory path is correct
2. Check folder permissions (you have write access)
3. Ensure disk has free space
4. For network drives: verify network connection

### "Cannot convert cps to counts (countingTime not available)"

**Problem:** Requested intensity format requires conversion, but `countingTime` metadata is missing.

**Solutions:**
1. Use `Intensity="both"` instead — script writes what's available
2. Check that your input file is a valid XRD file (some corrupted or non-XRD files may lack metadata)
3. Manually edit the output CSV and add the conversion column if needed

### "Origin not available — data copied to clipboard instead"

**Problem:** You selected `Format="com"` but OriginPro is not running.

**Behavior:** Data is copied to clipboard instead (Origin-formatted, tab-delimited, ready to paste).

**Solutions:**
1. Start OriginPro before running conversion
2. Use `Format="origin"` to export as CSV files instead

### Some files show `[???]` badge

**Problem:** File is `.raw` but not Rigaku or Bruker XRD.

**Behavior:** File appears in list but conversion will likely fail (unknown format).

**Solutions:**
1. Deselect these files before converting
2. Verify files are actually XRD data (not VSM, DSC, or other instruments)

---

## Tips & Best Practices

1. **Test with one file first**
   ```matlab
   results = scripts.batchConvertXRD('sample.xrdml');
   ```

2. **Always check for errors after batch conversion**
   ```matlab
   failures = results(~cellfun(@isempty, {results.error}));
   if ~isempty(failures)
       disp('Conversion failed for:');
       disp({failures.name}');
   end
   ```

3. **Use output structure to log conversions**
   ```matlab
   % Save results to a text file for audit trail
   fid = fopen('conversion_log.txt', 'w');
   for i = 1:numel(results)
       if isempty(results(i).error)
           fprintf(fid, 'OK: %s -> %s\n', results(i).name, results(i).outputFile);
       else
           fprintf(fid, 'ERR: %s -- %s\n', results(i).name, results(i).error);
       end
   end
   fclose(fid);
   ```

4. **Preserve original files**
   - Batch converter reads input files but never modifies them
   - Output goes to separate `.csv` files (safe to delete originals after conversion)

5. **For large batches, use `Recursive=true` with `OutputDir`**
   ```matlab
   % Convert entire measurement campaign
   results = scripts.batchConvertXRD('2026_Campaign/', ...
       Recursive=true, ...
       OutputDir='2026_Campaign_CSV/');
   ```

6. **Inspect metadata in CSV for quality assurance**
   - Metadata header shows sample name, counting time, 2θ range, anode material
   - Useful for verifying correct file was converted

---

## Integration with Other Tools

### Import into Python/NumPy

```python
import pandas as pd
data = pd.read_csv('sample.csv', comment='#')
theta = data['2-Theta (deg)'].values
intensity = data['Intensity (cps)'].values
```

### Import into OriginPro

**Option 1 (Manual):** Open `.csv` → Right-click columns → Set as X/Y/Designation
**Option 2 (Auto):** Use `Format="origin"` → Open in OriginPro (headers auto-interpreted)
**Option 3 (Direct):** Use `Format="com"` → Data appears directly in workbook

### Batch processing with system command

```bash
# Windows batch script
matlab -batch "scripts.batchConvertXRD('raw/', OutputDir='processed/')"
```

---

## Function Reference

### `scripts.batchConvertXRD(files, options)`

**Core batch conversion engine.**

Full docstring:
```matlab
help scripts.batchConvertXRD
```

### `xrdConvertGUI()`

**Standalone GUI window.**

```matlab
xrdConvertGUI()
```

### `utilities.writeXRDcsv(data, outputPath, options)`

**Write a single XRD data struct to CSV.**

Used internally by `batchConvertXRD`, but can be called directly for custom workflows:

```matlab
% Parse a file manually and export with custom options
data = parser.importXRDML('sample.xrdml');
utilities.writeXRDcsv(data, 'output.csv', ...
    Format='origin', ...
    Intensity='cps', ...
    IncludeMetadata=true);
```

---

## Related Functions

- `parser.importAuto()` — Auto-detect file type and parse
- `parser.importXRDML()` — Parse PANalytical XRDML files
- `parser.importRigaku_raw()` — Parse Rigaku SmartLab `.raw` files
- `parser.importBruker()` — Parse Bruker `.brml` and v3 `.raw` files

---

## Version & History

- **v1.0** (2026-03-07): Initial implementation
  - All XRD parser formats supported
  - Standard CSV and Origin ASCII export
  - GUI and script interfaces

---

## Questions or Issues?

- Check the **Troubleshooting** section above
- Verify input files are valid XRD data files
- Use `Verbose=true` (default) to see detailed console output
- Inspect metadata header in output CSV for export details
