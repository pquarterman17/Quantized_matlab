# Test Suite

All test scripts live here. Run from the project root.

## Quick start

```matlab
runAllTests                   % run everything
runAllTests(Group="parser")   % fast parser checks only (no GUI)
runAllTests(Group="gui")      % GUI tests only
```

## Groups

| Group | Command | Speed | What it covers |
|-------|---------|-------|----------------|
| `parser` | `runAllTests(Group="parser")` | Fast | All parsers, importAuto dispatch, edge cases, CSV round-trip |
| `batch`  | `runAllTests(Group="batch")`  | Fast | batchImport, batchConvertXRD, XRD converter GUI |
| `xrd2d`  | `runAllTests(Group="xrd2d")`  | Fast | 2D XRDML parser, Q-space, shapes, cuts, session round-trip |
| `gui`    | `runAllTests(Group="gui")`    | Medium | GUI API: load, correct, peaks, session, 2D map, colormaps |
| `all`    | `runAllTests`                 | Medium | Everything above, in order |

## Individual suites

You can still run any suite on its own:

```matlab
run tests/test_parsers
run tests/test_importAuto
run tests/test_parsers_edge_cases
run tests/test_data_roundtrip
run tests/test_batch_processing
run tests/test_batch_xrd_converter
run tests/test_xrdml_2d
run tests/test_xrdml_2d_edge
run tests/test_gui_harness
run tests/test_gui_2d
run tests/test_gui_phase4
```

## Test files

| File | Group | Coverage |
|------|-------|----------|
| `test_parsers.m` | parser | Smoke tests for all `+parser` functions |
| `test_importAuto.m` | parser | `parser.importAuto` dispatch and format detection |
| `test_parsers_edge_cases.m` | parser | Error handling: empty files, truncated binaries, missing files |
| `test_data_roundtrip.m` | parser | CSV export round-trip: import → writeXRDcsv → re-import → compare |
| `test_batch_processing.m` | batch | `batchImport` and `batchConvertXRD` integration tests |
| `test_batch_xrd_converter.m` | batch | `xrdConvertGUI` and batch XRD converter edge cases |
| `test_xrdml_2d.m` | xrd2d | 2D XRDML parser: is2D detection, matrix shape, Q-space, backward compat |
| `test_xrdml_2d_edge.m` | xrd2d | Edge cases: minimal/large/asymmetric grids, zero BG, boundary cuts, session |
| `test_gui_harness.m` | gui | GUI programmatic API: load, correct, peak-find, undo, session save/load |
| `test_gui_2d.m` | gui | GUI 2D map: load, plot types, H-cut, V-cut, multi-cut accumulation |
| `test_gui_phase4.m` | gui | GUI Phase 4: Q-space toggle, contour levels, colormap, mixed 1D+2D |

## Archive

The `archive_2026-03-10/` folder contains test scripts that are superseded or
no longer maintained. See the archive `README.md` for details.
