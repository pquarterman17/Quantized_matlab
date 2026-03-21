# CLAUDE.md — Matlab Toolbox

## Project Overview

Scientific data analysis toolbox for magnetometry and generic lab data. Supports Quantum Design PPMS/VSM/DynaCool/MPMS, Rigaku XRD, PANalytical XRDML, Bruker XRD, Lake Shore VSM, NCNR neutron reflectometry, SIMS depth profiles, and generic CSV/Excel/TSV data.

## Repository Structure

```
thin_film_toolkit_matlab/
├── setupToolbox.m            # Adds toolbox root to MATLAB path
├── DataPlotter.m             # Main GUI: browse, preview, correct, peaks, export
├── xrdConvertGUI.m           # Batch XRD file converter GUI
├── materialsCalcGUI.m        # Materials calculator (13 tabs)
├── emViewerGUI.m             # Electron microscopy image viewer
├── runAllTests.m             # Master test runner (see Testing section)
├── tests/                    # Test suites organized by domain
│   ├── parser/               # Parser smoke tests, edge cases, round-trip
│   ├── gui/                  # DataPlotter headless API tests
│   ├── imaging/              # EM parsers, imaging utils, EM GUI, EDS, EELS, diffraction
│   ├── calc/                 # Calculator module tests (xray, superconductor, CIF, optics, ...)
│   ├── batch/                # Batch import and XRD converter tests
│   └── fitting/              # Curve fitting engine, models, auto-guess, equation parser
├── +parser/                  # Data import (see +parser/README.md)
├── +imaging/                 # EM image processing (see +imaging/README.md)
├── +calc/                    # Calculator backend (see +calc/README.md)
├── +utilities/               # Data processing helpers (see +utilities/README.md)
├── +plotting/                # Plot formatting and export
├── +styles/                  # Visual themes
├── +scripts/                 # Batch workflows (see +scripts/README.md)
├── +fitting/                 # General curve fitting engine, model library, equation parser
├── +dataplotter/             # Extracted DataPlotter subsystems
├── docs/                     # Detailed feature documentation
│   ├── gui_dataplotter.md    # DataPlotter features, tools, figure builder
│   ├── gui_emviewer.md       # emViewerGUI features, EELS, EDS, diffraction
│   └── architecture.md       # Data flow, state management, design patterns
└── plans/                    # Feature roadmaps and organization plans
```

## Conventions

- **Functions:** `PascalCase` — **Variables:** `camelCase` — **Struct fields:** lowercase
- **Parameters:** named arguments via `arguments` block (R2021b+)
- **No external toolboxes** — MATLAB built-ins only
- **Unified data struct:** all parsers return `.time`, `.values`, `.labels`, `.units`, `.metadata` via `parser.createDataStruct()`
- **Section dividers:** `% ════════...` style
- **Pipeline:** parse → correct → plot (each stage independent)

### Column Shorthands (`importQDVSM` / `importPPMS`)

`'field'` → Magnetic Field (Oe), `'moment'` → Moment (emu), `'temp'` → Temperature (K), `'time'` → Time Stamp, `'stderr'` → M. Std. Err., `'all'` → all numeric columns except x-axis

## Quick Start

```matlab
setupToolbox                                    % add to path (once)
data = parser.importAuto('sample.dat');         % auto-detect format
data = parser.importQDVSM('f.dat', 'XAxis', 'field', 'YAxis', 'moment');
data = parser.importXRDML('scan.xrdml', Intensity='cps');
data = parser.importCSV('data.csv');
DataPlotter                                     % interactive GUI
scripts.quickPlot('scan.xrdml')                 % one-liner plot
scripts.batchImport('measurements/', 'Recursive', true);
```

## Testing

```matlab
runAllTests                          % full suite
runAllTests(Group="parser")          % parser smoke tests (fast)
runAllTests(Group="gui")             % headless DataPlotter API tests
runAllTests(Group="em")              % EM parsers + imaging utilities
runAllTests(Group="emgui")           % EM Viewer GUI API tests
runAllTests(Group="batch")           % batch import + XRD converter
runAllTests(Group="fitting")         % curve fitting engine + models + parser
```

Groups: `parser`, `batch`, `xrd2d`, `gui`, `sims`, `em`, `emgui`, `eds`, `xrayneutron`, `superconductor`, `cif`, `optics`, `vacuum`, `electrochemistry`, `eels`, `eels_adv`, `diffindex`, `diff_sim`, `edsquant`, `contour`, `fitting`

## Key Design Decisions

- **Functional approach** — pure functions returning structs; no heavy OOP
- **Auto-detection heuristics** — delimiter, header row, data start, units all inferred
- **Unified data struct** — parser-agnostic GUI and plotting code
- **Peak fitting** — Lorentzian model (appropriate for XRD Bragg peaks)
- **General curve fitting** — `+fitting/` package with 23 models, bounds, parameter errors, custom equations, batch fitting, peak tracking
- **Publication templates** — `styles.template('aps')` etc. for journal-ready figures
- **Statistics** — t-tests, linear regression, descriptive stats (no Statistics Toolbox)

## 2D Area-Detector Extension (`importXRDML`)

When XRDML contains multi-frame area-detector data, `data.metadata.parserSpecific` gains:
- `.is2D` — `true` (also `false` for 1D files)
- `.map2D.intensity` — [N×M] matrix, `.map2D.axis1`/`.axis2` — motor positions
- `.map2D.Qx`, `.map2D.Qz` — reciprocal-space grids (when wavelength available)

## Detailed Documentation

Feature-level docs are in separate files to keep this context compact:

| Topic | File |
|-------|------|
| DataPlotter tools, figure builder, curve fitting, digitizer | [docs/gui_dataplotter.md](docs/gui_dataplotter.md) |
| emViewerGUI features, EELS, EDS, diffraction | [docs/gui_emviewer.md](docs/gui_emviewer.md) |
| Architecture, data flow, state management | [docs/architecture.md](docs/architecture.md) |
| Parser formats and dispatch | [+parser/README.md](+parser/README.md) |
| Imaging utilities | [+imaging/README.md](+imaging/README.md) |
| Calculator modules | [+calc/README.md](+calc/README.md) |
| Data processing utilities | [+utilities/README.md](+utilities/README.md) |
| Batch scripts | [+scripts/README.md](+scripts/README.md) |

## GUI Development Notes

### DataPlotter
- `cla()` alone does not remove `HandleVisibility='off'` objects — use `delete(ax.Children)` before `cla()`
- Each dataset stores axis limits in `ds.axLims` (persisted across switches)
- Peak Analysis window: see [docs/gui_dataplotter.md](docs/gui_dataplotter.md)

### emViewerGUI
- Image pipeline: `rawPixels` → `filteredPixels` → `displayImg`
- Enable/disable triad: `displayImage()`, `clearDisplay()`, `setToolsEnabled()`
- `undoPush()` inside `try` blocks only — prevents phantom undo on failure
- FFT mask uses `ButtonDownFcn`, not `ginput()` (unreliable in uifigure)
- See [docs/gui_emviewer.md](docs/gui_emviewer.md) for full details
