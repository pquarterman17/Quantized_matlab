# Test Suite

All test scripts live here. Run from the project root (or any directory — scripts
resolve paths from their own location automatically).

## Running Tests

```matlab
% From the project root:
cd G:\Onedrive\Coding\git\thin_film_toolkit_matlab
setupToolbox          % add packages to path (once per session)

% Then run any test script:
run tests/test_parsers
run tests/test_importAuto
run tests/test_parsers_edge_cases
run tests/test_gui_harness
run tests/test_data_roundtrip
run tests/test_batch_processing
run tests/test_batch_xrd_converter
```

## Test Files

| File | Coverage | Speed |
|------|----------|-------|
| `test_parsers.m` | Smoke tests for all `+parser` functions (importQDVSM, importPPMS, importCSV, importExcel, importRigaku_raw, importXRDML, importBruker, importMPMS, importLakeShore, importNCNRRefl, importNCNRPNR, importNCNRDat) | Fast |
| `test_importAuto.m` | `parser.importAuto` extension dispatch and format detection | Fast |
| `test_parsers_edge_cases.m` | Error handling: empty files, truncated binaries, missing files, inconsistent columns | Fast |
| `test_gui_harness.m` | GUI programmatic API: load, correct, peak-find, undo, session save/load | Medium (opens GUI) |
| `test_data_roundtrip.m` | CSV export round-trip: import → writeXRDcsv → re-import → compare | Fast |
| `test_batch_processing.m` | `batchImport` and `batchConvertXRD` integration tests | Fast |
| `test_batch_xrd_converter.m` | `xrdConvertGUI` and batch XRD converter edge cases | Fast |

## Archive

The `archive_2026-03-10/` folder contains test scripts that are superseded or
no longer maintained. See the archive `README.md` for details.
