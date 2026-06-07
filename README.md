# Quantized MATLAB

A MATLAB toolbox for importing, analyzing, and visualizing scientific data from laboratory instruments — magnetometry, X-ray diffraction, neutron reflectometry, and SIMS depth profiles.

> **Looking for the electron microscopy tools?** FermiViewer and the EM parsers (DM3/DM4, TIFF, MRC, SER, BCF) moved to the standalone [fermi-viewer](https://github.com/pquarterman17/fermi-viewer) repository.

**No external toolboxes required.** Uses MATLAB built-ins only. Runs on R2021b+.

## Highlights

- **16 parsers** for Quantum Design PPMS/VSM/DynaCool/MPMS, Rigaku, PANalytical XRDML (incl. 2D area-detector RSM), Bruker, Lake Shore, NCNR neutron reflectometry, SIMS, AFM, generic CSV/TSV/Excel, and more.
- **BosonPlotter** — interactive GUI for browse, preview, correct, fit, and export of 1D/2D datasets. Corrections pipeline, peak analysis (Lorentzian/Voigt/pseudo-Voigt), general curve fitting (see [`+fitting/README.md`](+fitting/README.md) for the model catalog), multi-panel figure builder, graph digitizer, macro recorder, customizable toolbar.
- **DiraCulator** — 18-panel materials property calculator: crystal structure, X-ray/neutron SLD, semiconductor band structure, thin-film optics, superconductor parameters, vacuum, electrochemistry, and more.
- **Unified data contract** — every parser returns `.time`, `.values`, `.labels`, `.units`, `.metadata` via `parser.createDataStruct()`, so downstream code is parser-agnostic.
- **Comprehensive test suite** — covering parsers, GUIs, calculators, fitting, and batch workflows.

## Installation

```matlab
% Clone the repo, then in MATLAB:
cd quantized_matlab
setupToolbox                                    % adds all packages to path
```

Re-run `setupToolbox` each session, or call it from your `startup.m`.

## Quick Start

```matlab
% Auto-detect format and import
data = parser.importAuto('sample.dat');

% Interactive GUIs
BosonPlotter                                    % 1D/2D data browser + analysis
DiraCulator                                     % materials calculator

% Scripting
data = parser.importQDVSM('f.dat', XAxis='field', YAxis='moment');
data = parser.importXRDML('scan.xrdml', Intensity='cps');
scripts.quickPlot('scan.xrdml');
scripts.batchImport('measurements/', Recursive=true);
results = scripts.batchConvertXRD('xrd_data/', OutputDir='csv_out/');
```

## Supported Formats

| Instrument / Format | Extension | Parser |
|---------------------|-----------|--------|
| Quantum Design VSM / DynaCool | `.dat` | `parser.importQDVSM` |
| Quantum Design PPMS (legacy) | `.dat` | `parser.importPPMS` |
| Quantum Design MPMS SQUID | `.dat` | `parser.importMPMS` |
| Lake Shore VSM / cryostat | `.dat`, `.csv` | `parser.importLakeShore` |
| PANalytical / Malvern XRDML | `.xrdml` | `parser.importXRDML` |
| Bruker XRD | `.brml`, `.raw` | `parser.importBruker` |
| Rigaku SmartLab | `.raw` | `parser.importRigaku_raw` |
| Generic CSV / TSV / TXT | `.csv`, `.tsv`, `.txt` | `parser.importCSV` |
| Excel / OpenDocument | `.xlsx`, `.xls`, `.ods` | `parser.importExcel` |
| NCNR neutron reflectometry | `.refl` | `parser.importNCNRRefl` |
| NCNR polarized neutron | `.pnr` | `parser.importNCNRPNR` |
| NCNR refl1d fit output | `.datA`–`.datD` | `parser.importNCNRDat` |
| SIMS depth profile | `.dp_rpc_asc`, `.dp` | `parser.importSIMS` |

All parsers return the same unified struct. `parser.importAuto` dispatches by extension and content sniffing.

Electron-microscopy formats (`.dm3`, `.dm4`, `.tif`, `.mrc`, `.ser`, `.bcf`) are handled by [fermi-viewer](https://github.com/pquarterman17/fermi-viewer).

## 2D Reciprocal-Space Maps

`parser.importXRDML` automatically detects multi-frame area-detector files and builds a 2D intensity map plus Qx/Qz reciprocal-space grids. The result is rendered as a heatmap in BosonPlotter with lazy Q-space computation and optional single-precision storage for large maps (100+ MB XRDML files).

## Testing

```matlab
runAllTests                       % full suite
runAllTests(Group="parser")       % parser smoke tests only (~5 s)
runAllTests(Group="gui")          % BosonPlotter headless API tests
runAllTests(Group="calc")         % materials calculator (13 tabs)
runAllTests(Group="fitting")      % curve fitting engine + models
runAllTests(Group="batch")        % batch import + XRD converter
```

Test groups: `parser`, `batch`, `xrd2d`, `gui`, `calcgui`, `sims`, `xrayneutron`, `superconductor`, `cif`, `optics`, `vacuum`, `electrochemistry`, `fitting`, `plotting`, `interp2d`, `baseline`, `errorprop`, `utilities`, `templates`. EM-related groups moved to [fermi-viewer](https://github.com/pquarterman17/fermi-viewer).

## Documentation

- [**GitHub Wiki**](https://github.com/pquarterman17/Quantized_matlab/wiki) — user guide, tutorials, and reference
- [CLAUDE.md](CLAUDE.md) — developer reference: conventions, struct layout, GUI internals, design decisions
- [docs/gui_bosonplotter.md](docs/gui_bosonplotter.md) — BosonPlotter features, tools, figure builder
- [docs/architecture.md](docs/architecture.md) — data flow, state management, design patterns
- [+parser/README.md](+parser/README.md) — parser formats and dispatch
- [+calc/README.md](+calc/README.md) — materials calculator modules

## License

Source-available license. Free for personal, academic, and non-commercial research use.

**Commercial and government use require prior written permission** from the copyright holder. See [LICENSE](LICENSE) for full terms.

To request permission, contact [github.com/pquarterman17](https://github.com/pquarterman17).
