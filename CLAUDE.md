# CLAUDE.md — Matlab Toolbox

## Project Overview

Scientific data analysis toolbox for processing and visualizing X-ray diffraction (XRD) and magnetometry data from laboratory instruments. Supports Rigaku SmartLab XRD, Quantum Design PPMS/VSM/DynaCool, and generic CSV/TSV data.

## Repository Structure

```
Matlab/
├── setupToolbox.m          # Entry point — adds all subdirs to MATLAB path
├── +parser/                # Data import and parsing (ACTIVE)
│   ├── importCSV.m         # Universal CSV/TSV importer with auto-detection
│   ├── importQDVSM.m       # Quantum Design PPMS/VSM/DynaCool importer
│   ├── rigaku_raw/         # Rigaku XRD binary parser and plotting
│   │   ├── rigaku_raw.m        # parse_rigaku_raw() — reads .raw binary files
│   │   ├── plot_xrd_data.m     # Main XRD visualization function
│   │   ├── quick_plot.m        # Minimal plotting template
│   │   ├── plotting_examples.m # 11 usage examples
│   │   ├── advanced_plotting.m # Publication-quality figure templates
│   │   └── PLOTTING_README.md  # Comprehensive user documentation
│   └── ppms_raw/           # Legacy PPMS magnetometry parser
│       ├── PPMS_raw.m          # parse_magnetometry_data()
│       └── @basicMath/         # Static math utility class
├── +plotting/              # Reserved — not yet implemented
├── +scripts/               # Reserved — not yet implemented
├── +styles/                # Reserved — not yet implemented
└── +utilities/             # Reserved — not yet implemented
```

## Supported Data Formats

| Format | Module | Description |
|--------|--------|-------------|
| Rigaku XRD `.raw` (binary) | `rigaku_raw.m` | X-ray diffraction intensity vs. 2θ |
| Quantum Design PPMS `.dat` | `importQDVSM.m` | Magnetometry (M vs H, M vs T) |
| PPMS `.dat` (legacy) | `PPMS_raw.m` | Magnetometry — older parser |
| CSV / TSV (generic) | `importCSV.m` | Generic lab data with auto-detection |

## Conventions

### Naming
- **Functions:** mix of `snake_case` (`parse_rigaku_raw`, `plot_xrd_data`) and `PascalCase` (`importCSV`, `importQDVSM`)
- **Parameters:** named arguments via `arguments` block (modern) or `inputParser` (older); booleans as `true`/`false`
- **Variables:** `camelCase` for local vars (`colIdx`, `rawMatrix`); struct fields use lowercase (`data.theta`, `data.values`)

### Output Structs
Functions return unified structs with consistent fields:
- `.time` / `.timeVec` — x-axis values
- `.values` — data matrix
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
- Example scripts demonstrate all major use cases

## Common Workflows

### XRD Analysis
```matlab
setupToolbox()
[data, params] = parse_rigaku_raw('sample.raw');
plot_xrd_data('sample.raw', 'PlotType', 'log', 'FindPeaks', true, 'Normalize', true);
```

### Magnetometry (PPMS/VSM)
```matlab
data = importQDVSM('sample.dat', 'XAxis', 'field', 'YAxis', 'moment');
```

### Generic CSV
```matlab
data = importCSV('data.csv');  % auto-detects delimiter, headers, units
```

## Key Design Decisions

- **No external toolboxes** — uses MATLAB built-ins only (`textscan`, `findpeaks`, `regexp`, etc.)
- **Functional approach** — pure functions returning structs; no heavy OOP
- **Auto-detection heuristics** — delimiter, header row, data start, units all inferred automatically
- **Pipeline pattern** — parse → normalize → plot; each stage independent
- **Rigaku binary parsing** — reads fixed offsets (num_points @ 4–8, step size @ 1256, start angle @ 3136, data @ 3140+)

## Future Expansion

Empty packages (`+plotting`, `+scripts`, `+styles`, `+utilities`) are reserved for planned modules. Do not delete them. When implementing, follow the same package/function conventions above.
