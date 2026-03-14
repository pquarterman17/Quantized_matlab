# CLAUDE.md — Matlab Toolbox

## Project Overview

Scientific data analysis toolbox for processing and visualizing magnetometry and generic lab data from laboratory instruments. Supports Quantum Design PPMS/VSM/DynaCool, Rigaku XRD, and generic CSV/Excel/TSV data.

## Repository Structure

```
thin_film_toolkit_matlab/
├── setupToolbox.m          # Entry point — adds toolbox root to MATLAB path
├── dataImportGUI.m         # Interactive uifigure GUI: browse, preview, correct, peaks, export
├── xrdConvertGUI.m         # Standalone batch XRD file converter GUI
├── tests/                  # All test scripts (run via: run tests/test_parsers)
│   ├── test_parsers.m              # Smoke tests for all +parser functions
│   ├── test_importAuto.m           # Smoke tests for parser.importAuto dispatch
│   ├── test_parsers_edge_cases.m   # Edge-case and error-handling tests
│   ├── test_gui_harness.m          # Automated GUI API tests
│   ├── test_data_roundtrip.m       # CSV export round-trip tests
│   ├── test_batch_processing.m     # batchImport / batchConvertXRD integration
│   ├── test_batch_xrd_converter.m  # XRD converter edge cases
│   ├── test_xrdml_2d.m             # 2D area-detector parser tests (8 tests)
│   ├── test_gui_2d.m               # 2D GUI API tests (6 tests)
│   └── archive_2026-03-10/         # Superseded tests (kept for reference)
├── +parser/                # Data import namespace
│   ├── importAuto.m        # Auto-detect file type and dispatch to correct parser
│   ├── importCSV.m         # Universal CSV/TSV importer with auto-detection
│   ├── importExcel.m       # Excel (.xlsx/.xls/.ods) importer
│   ├── importQDVSM.m       # Quantum Design VSM/DynaCool importer (.dat)
│   ├── importPPMS.m        # Legacy QD PPMS importer (.dat); auto-detects tab/comma
│   ├── importRigaku_raw.m  # Rigaku SmartLab binary .raw importer (magic "FI")
│   └── createDataStruct.m  # Validates and assembles the unified data struct
├── +plotting/              # Plot helper functions
│   ├── formatAxes.m        # Apply theme to an axes object (fonts, grid, labels)
│   ├── lineColors.m        # Return N colours from the active theme palette
│   └── saveFigure.m        # Export figure to PNG/PDF/SVG/EPS at set dimensions
├── +styles/
│   └── default.m           # Default visual theme struct (colours, widths, font sizes)
├── +utilities/             # General-purpose data helpers
│   ├── normalize.m         # Normalise columns: range / peak / z-score
│   ├── smoothData.m        # Moving-average or Gaussian smoothing (no toolbox)
│   └── convertUnits.m      # Convert between common lab units (field, moment, temp, …)
└── +scripts/
    └── batchImport.m       # Walk a directory, call importAuto on each supported file
```

## Supported Data Formats

| Format | Parser | Description |
|--------|--------|-------------|
| Quantum Design VSM `.dat` | `importQDVSM.m` | Magnetometry (M vs H, M vs T); [Header]/[Data] markers |
| QD PPMS `.dat` (legacy) | `importPPMS.m` | Older PPMS magnetometry CSV/TSV format; auto-detects delimiter |
| CSV / TSV / TXT | `importCSV.m` | Generic lab data with auto-detection of delimiter, headers, units |
| Excel `.xlsx/.xls/.ods` | `importExcel.m` | Spreadsheet data with unit row support |
| Rigaku SmartLab `.raw` | `importRigaku_raw.m` | Binary XRD file (magic "FI"); warns on multi-range files |
| PANalytical `.xrdml` | `importXRDML.m` | XML XRD scan; auto-detects 1D vs 2D area-detector data; Q-space conversion |

## Conventions

### Naming
- **Functions:** `PascalCase` (`importCSV`, `importQDVSM`, `createDataStruct`)
- **Parameters:** named arguments via `arguments` block; booleans as `true`/`false`
- **Variables:** `camelCase` for local vars (`colIdx`, `rawMatrix`); struct fields use lowercase

### Output Structs
All parsers return unified structs with consistent fields:
- `.time` — x-axis values (numeric vector or datetime)
- `.values` — [N×K] data matrix
- `.labels` — channel names (cell array of strings)
- `.units` — unit strings (cell array)
- `.metadata` — instrument params, source file info

#### 2D area-detector extension (`importXRDML` only)
When a PANalytical XRDML file contains multi-frame area-detector data,
`data.metadata.parserSpecific` gains:
- `.is2D` — `true`; also present (as `false`) for 1D files for explicit checking
- `.map2D.intensity` — [N×M] matrix (N Omega frames × M detector pixels), cps or counts
- `.map2D.axis1` / `.axis1Name` / `.axis1Unit` — scanned motor positions (e.g. Omega, deg)
- `.map2D.axis2` / `.axis2Name` / `.axis2Unit` — detector strip (2Theta, deg)
- `.map2D.Qx`, `.map2D.Qz` — [N×M] reciprocal-space grids (Å⁻¹); present when wavelength available
- `data.time` / `data.values` — integrated profile `sum(intensity, 1)'` (1D fallback)

### Dataset struct (GUI internal)
Each loaded file is stored as a `ds` struct inside `appData.datasets`:
- `.data`, `.corrData` — raw and corrected data structs
- `.xOff`, `.yOff`, `.bgSlope`, `.bgInt` — per-dataset correction values
- `.peaks` — struct array of detected/fitted peaks
- `.axLims` — per-dataset axis limit strings (persisted across dataset switches)

### Column Shorthands (`importQDVSM` / `importPPMS`)
- `'field'` → Magnetic Field (Oe)
- `'moment'` → Moment (emu)
- `'temp'` / `'temperature'` → Temperature (K)
- `'time'` → Time Stamp
- `'stderr'` → M. Std. Err.
- `'all'` → all numeric columns except x-axis

### Documentation
- Every public function has a docstring with: Syntax, Inputs, Outputs, Examples
- Section dividers use `% ════════...` style

## Common Workflows

### Magnetometry (PPMS/VSM)
```matlab
data = parser.importQDVSM('sample.dat', 'XAxis', 'field', 'YAxis', 'moment');
```

### XRD (Rigaku)
```matlab
data = parser.importRigaku_raw('scan.raw', 'UseCountsPerSec', true);
```

### XRD 2D reciprocal-space map (PANalytical area detector)
```matlab
data = parser.importXRDML('rsm.xrdml', Intensity='cps');
map  = data.metadata.parserSpecific.map2D;  % only present when is2D==true

% Angle-space heatmap
imagesc(map.axis2, map.axis1, log10(map.intensity));
axis xy; colorbar; colormap parula;
xlabel('2\theta (deg)'); ylabel('\omega (deg)');

% Q-space heatmap (requires wavelength in file)
if isfield(map, 'Qx')
    pcolor(map.Qx, map.Qz, log10(map.intensity)); shading flat;
end

% Extract a rocking curve (V-cut) at the peak 2Theta
[~, col] = min(abs(map.axis2 - 61.0));
plot(map.axis1, map.intensity(:, col));
```

### Generic CSV
```matlab
data = parser.importCSV('data.csv');  % auto-detects delimiter, headers, units
```

### Auto-dispatch
```matlab
data = parser.importAuto('sample.dat');   % picks parser from extension + content
```

### Batch import
```matlab
results = scripts.batchImport('measurements/', 'Recursive', true);
good = results(cellfun(@isempty, {results.error}));
```

### Plotting helpers
```matlab
th = styles.default();
cols = plotting.lineColors(3, th);
fig = figure;  plot(data.time, data.values, 'Color', cols(1,:));
plotting.formatAxes(gca, th, 'XLabel', '2\theta (°)', 'YLabel', 'Counts');
plotting.saveFigure(fig, 'scan.pdf');
```

### Data utilities
```matlab
normI  = utilities.normalize(data.values);               % [0,1] range
smI    = utilities.smoothData(data.values, 'Window', 9); % Gaussian smooth
[H_T, u] = utilities.convertUnits(data.time, 'Oe', 'T');
```

### Interactive GUI
```matlab
dataImportGUI   % browse, preview, apply corrections, find/fit peaks, export CSV
```

## Key Design Decisions

- **No external toolboxes** — uses MATLAB built-ins only
- **Functional approach** — pure functions returning structs; no heavy OOP
- **Auto-detection heuristics** — delimiter, header row, data start, units all inferred automatically
- **Pipeline pattern** — parse → correct → plot; each stage independent
- **Unified data struct** — all parsers emit the same field layout so GUI and plotting code is parser-agnostic
- **Peak fitting** — Lorentzian model (appropriate for XRD Bragg peaks)

## GUI Notes

- `cla()` alone does not remove graphics objects with `HandleVisibility='off'` (peak markers).
  Use `delete(ax.Children)` before `cla()` to clear all children.
- Each dataset in `appData.datasets` stores its own axis limits (`ds.axLims`) so zoom
  levels are restored when switching between loaded files.
