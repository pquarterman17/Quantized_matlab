# Backlog — Open Items

Consolidated from `todo.md` and `PROPOSED_FEATURES.md` (2026-03-14).
Only items not yet completed are listed here.

---

## dataImportGUI Features

### ~~Dataset comparison / difference plots~~ — DONE
Implemented via "Dataset Math..." button (`onDatasetMath`). Supports `D1 - D2`, `D1 / D2`,
`log10(D1)`, `diff(D1)`, and arbitrary expressions with `interp1` alignment for mismatched
x-grids. eval() replaced with safe recursive-descent parser (`safeEvalMathExpr`).

### ~~Peak database matching (XRD phase identification)~~ — DONE
Implemented: `calc.crystal.phaseDatabase()` (~50 phases), `calc.crystal.matchPhases()`,
and "Match Phases" button in the peak panel Advanced section. Overlays vertical tick
marks with phase labels on the plot. Adjustable d-spacing tolerance.

### Scripting / macro recorder
"Record Macro" toggle captures GUI actions as MATLAB script calls to the programmatic
API. "Stop Recording" writes `.m` file. "Run Macro" replays it. Enables batch
correction pipelines without clicking through the GUI.

**Touches:** `dataImportGUI.m` (record toggle + script generation), API completeness.

### GUI space optimization
Boxes with few buttons take disproportionate visual space, forcing feature-dense boxes
to be cramped or cut off. Audit and optimize button/box sizes for readability.

**Touches:** `dataImportGUI.m` (layout grid row heights, button placement).

---

## New Parsers

### `importOxford.m` — Oxford Instruments MagLab
Format varies by software version (CSV or custom text). **Blocked:** needs example file.

### `importRaman.m` — Horiba LabSpec / Renishaw ASCII
Wavenumber + intensity columns. May already work via `importCSV` — verify and add
`importAuto` dispatch for `.txt` Raman files.

### `importOpus.m` — Bruker OPUS FTIR binary
Proprietary block structure. Reference: `brukeropus` Python library. **Blocked:** needs
example file.

### `importSPC.m` — GRAMS/Thermo spectral format
Published binary spec. Single and multi-file variants (Shimadzu UV-Vis, etc.).
**Blocked:** needs example file.

### Additional file support
Support file types as they are added to `+test_datasets/` on a rolling basis.

---

## Documentation

### Update in-code documentation
Function docstrings and section comments need a refresh pass.

### Update GitHub wiki
Wiki documentation is out of date with current features.

---

## Performance

See [large-data-performance.md](large-data-performance.md) for the full plan on
handling 100+ MB XRDML files from modern area detectors. Open items:
- Move Qx/Qz computation out of the parser (lazy compute)
- Stream-parse XRDML instead of `fileread`
- Pre-allocate scan arrays
- Cache 2D graphics handles
- Stride-based decimation for very large maps
- File size warning before import
- Memory usage display
- "Clear 2D Matrix" option
