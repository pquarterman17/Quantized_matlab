# CLAUDE.md — Matlab Toolbox

## Project Overview

Scientific data analysis toolbox for processing and visualizing magnetometry and generic lab data from laboratory instruments. Supports Quantum Design PPMS/VSM/DynaCool and generic CSV/Excel/TSV data.

## Repository Structure

```
thin_film_toolkit_matlab/
├── setupToolbox.m          # Entry point — adds all subdirs to MATLAB path
├── dataImportGUI.m         # Interactive uifigure GUI: browse, preview, correct, export
├── test_parsers.m          # Smoke tests for all +parser functions
├── test_importAuto.m       # Smoke tests for parser.importAuto dispatch
├── +parser/                # Data import namespace (ACTIVE)
│   ├── importAuto.m        # Auto-detect file type and dispatch to correct parser
│   ├── importCSV.m         # Universal CSV/TSV importer with auto-detection
│   ├── importExcel.m       # Excel (.xlsx/.xls/.ods) importer
│   ├── importQDVSM.m       # Quantum Design VSM/DynaCool importer (.dat)
│   ├── importPPMS.m        # Legacy QD PPMS importer (.dat)
│   └── createDataStruct.m  # Validates and assembles the unified data struct
├── +plotting/              # Reserved — not yet implemented
├── +scripts/               # Reserved — not yet implemented
├── +styles/                # Reserved — not yet implemented
└── +utilities/             # Reserved — not yet implemented
```

## Supported Data Formats

| Format | Parser | Description |
|--------|--------|-------------|
| Quantum Design VSM `.dat` | `importQDVSM.m` | Magnetometry (M vs H, M vs T); [Header]/[Data] markers |
| QD PPMS `.dat` (legacy) | `importPPMS.m` | Older PPMS magnetometry CSV format |
| CSV / TSV / TXT | `importCSV.m` | Generic lab data with auto-detection of delimiter, headers, units |
| Excel `.xlsx/.xls/.ods` | `importExcel.m` | Spreadsheet data with unit row support |

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

### Column Shorthands (`importQDVSM`)
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

### Generic CSV
```matlab
data = parser.importCSV('data.csv');  % auto-detects delimiter, headers, units
```

### Auto-dispatch
```matlab
data = parser.importAuto('sample.dat');   % picks parser from extension + content
```

### Interactive GUI
```matlab
dataImportGUI   % browse, preview, apply corrections, export CSV
```

## Key Design Decisions

- **No external toolboxes** — uses MATLAB built-ins only
- **Functional approach** — pure functions returning structs; no heavy OOP
- **Auto-detection heuristics** — delimiter, header row, data start, units all inferred automatically
- **Pipeline pattern** — parse → correct → plot; each stage independent
- **Unified data struct** — all parsers emit the same field layout so GUI and plotting code is parser-agnostic

## Future Expansion

Empty packages (`+plotting`, `+scripts`, `+styles`, `+utilities`) are reserved for planned modules. Do not delete them. When implementing, follow the same package/function conventions above.
