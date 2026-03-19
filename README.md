# Thin Film Toolkit (MATLAB)

A MATLAB toolbox for importing, correcting, and visualizing magnetometry, XRD, and neutron reflectometry data from common lab instruments.

## Features

- Unified import API for 13 file formats from 6+ instrument families
- Interactive GUI for data preview, baseline correction, peak fitting, and export
- Batch XRD converter (CLI + GUI) for `.xrdml` / `.raw` / `.brml` to CSV
- 2D reciprocal-space map support (PANalytical area-detector XRDML)
- Plotting helpers and unit converters (no external toolboxes required)
- Comprehensive automated test suite (11 suites, ~2 min full run)

## Requirements

- MATLAB R2021b or later (uses `arguments` blocks for named parameters)
- No external toolboxes required — Statistics, Signal Processing, etc. are NOT needed

## Installation

```matlab
% 1. Clone or download this repository
% 2. In MATLAB, navigate to the project root and run:
setupToolbox
```

`setupToolbox` adds all package directories to the MATLAB path for the current session. Re-run it at the start of each session, or add the call to your `startup.m`.

## Quick Start

```matlab
% Auto-detect format and import any supported file
data = parser.importAuto('sample.dat');

% Launch the interactive GUI
DataPlotter

% Batch-convert a folder of XRD files to CSV
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
| Excel spreadsheet | `.xlsx`, `.xls`, `.ods` | `parser.importExcel` |
| NCNR neutron reflectometry | `.refl` | `parser.importNCNRRefl` |
| NCNR polarized neutron | `.pnr` | `parser.importNCNRPNR` |
| NCNR refl1d fit output | `.datA`–`.datD` | `parser.importNCNRDat` |

All parsers return the same unified struct with fields `.time`, `.values`, `.labels`, `.units`, and `.metadata`.

`parser.importAuto` selects the correct parser automatically from the file extension and content.

## Documentation

- [CLAUDE.md](CLAUDE.md) — full developer reference: conventions, struct layout, GUI internals, design decisions
- [Batch XRD Converter Guide](doc/BATCH_XRD_CONVERTER_README.md)
- [Parser Reference](+parser/README.md)
- [Test Suite](tests/README.md)

## Testing

```matlab
runAllTests                     % full suite (~2 min)
runAllTests(Group="parser")     % fast parser checks only (~5 s, no GUI)
```

Individual suites can also be run directly:

```matlab
run tests/test_parsers          % smoke tests for all +parser functions
run tests/test_importAuto       % auto-dispatch tests
run tests/test_gui_harness      % automated GUI API tests
```

## License

*(Add MIT / your license here)*
