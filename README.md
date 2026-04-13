# Quantized MATLAB

A MATLAB toolbox for importing, analyzing, and visualizing scientific data from laboratory instruments — magnetometry, X-ray diffraction, neutron reflectometry, SIMS depth profiles, and electron microscopy.

**No external toolboxes required.** Uses MATLAB built-ins only. Runs on R2021b+.

## Highlights

- **25+ parsers** for Quantum Design PPMS/VSM/DynaCool/MPMS, Rigaku, PANalytical XRDML (incl. 2D area-detector RSM), Bruker, Lake Shore, NCNR neutron reflectometry, SIMS, generic CSV/TSV/Excel, Gatan DigitalMicrograph DM3/DM4, MRC, SER, and more.
- **BosonPlotter** — interactive GUI for browse, preview, correct, fit, and export of 1D/2D datasets. Corrections pipeline, peak analysis (Lorentzian/Voigt/pseudo-Voigt), general curve fitting (see [`+fitting/README.md`](+fitting/README.md) for the model catalog), multi-panel figure builder, graph digitizer, macro recorder, customizable toolbar.
- **FermiViewer** — electron microscopy image viewer. 55+ processing tools organized into 5 tabs (Transform, Filter, FFT & Analysis, Surface & Stack, Export & Style). Line profiles, ROI stats, FFT mask, CLAHE, EELS/EDS/diffraction analysis, GPA strain, CTF estimation, journal export presets.
- **DiraCulator** — 18-panel materials property calculator: crystal structure, X-ray/neutron SLD, semiconductor band structure, thin-film optics, superconductor parameters, vacuum, electrochemistry, and more.
- **Unified data contract** — every parser returns `.time`, `.values`, `.labels`, `.units`, `.metadata` via `parser.createDataStruct()`, so downstream code is parser-agnostic.
- **Comprehensive test suite** — 75 test suites covering parsers, GUIs, imaging, calculators, fitting, and batch workflows (~9 min full run).

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
FermiViewer                                     % EM image viewer
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
| Gatan DigitalMicrograph | `.dm3`, `.dm4` | `parser.importDM3`, `importDM4` |
| TIFF (multi-page, 8/16/32-bit) | `.tif`, `.tiff` | `parser.importTIFF` |
| MRC electron microscopy | `.mrc` | `parser.importMRC` |
| FEI / Thermo SER | `.ser` | `parser.importSER` |

All parsers return the same unified struct. `parser.importAuto` dispatches by extension and content sniffing.

## 2D Reciprocal-Space Maps

`parser.importXRDML` automatically detects multi-frame area-detector files and builds a 2D intensity map plus Qx/Qz reciprocal-space grids. The result is rendered as a heatmap in BosonPlotter with lazy Q-space computation and optional single-precision storage for large maps (100+ MB XRDML files).

## Testing

```matlab
runAllTests                       % full suite (~9 min, 75 suites)
runAllTests(Group="parser")       % parser smoke tests only (~5 s)
runAllTests(Group="gui")          % BosonPlotter headless API tests
runAllTests(Group="emgui")        % FermiViewer headless API tests
runAllTests(Group="em")           % imaging utilities + EM parsers
runAllTests(Group="calc")         % materials calculator (13 tabs)
runAllTests(Group="fitting")      % curve fitting engine + models
runAllTests(Group="batch")        % batch import + XRD converter
```

Test groups: `parser`, `batch`, `xrd2d`, `gui`, `calcgui`, `sims`, `em`, `emgui`, `eds`, `xrayneutron`, `superconductor`, `cif`, `optics`, `vacuum`, `electrochemistry`, `eels`, `eels_adv`, `diffindex`, `diff_sim`, `edsquant`, `contour`, `fitting`.

## Documentation

- [**GitHub Wiki**](https://github.com/pquarterman17/Quantized_matlab/wiki) — user guide, tutorials, and reference
- [CLAUDE.md](CLAUDE.md) — developer reference: conventions, struct layout, GUI internals, design decisions
- [docs/gui_bosonplotter.md](docs/gui_bosonplotter.md) — BosonPlotter features, tools, figure builder
- [docs/gui_emviewer.md](docs/gui_emviewer.md) — FermiViewer features, EELS, EDS, diffraction
- [docs/architecture.md](docs/architecture.md) — data flow, state management, design patterns
- [+parser/README.md](+parser/README.md) — parser formats and dispatch
- [+imaging/README.md](+imaging/README.md) — imaging utilities
- [+calc/README.md](+calc/README.md) — materials calculator modules

## License

Source-available license. Free for personal, academic, and non-commercial research use.

**Commercial and government use require prior written permission** from the copyright holder. See [LICENSE](LICENSE) for full terms.

To request permission, contact [github.com/pquarterman17](https://github.com/pquarterman17).
