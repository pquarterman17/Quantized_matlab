# Plan: Handling Very Large Data File Inputs

Generated 2026-03-14. Focuses on large 2D XRDML files (100+ MB) from modern area detectors.

---

## Current Bottlenecks

| Bottleneck | Where | Impact for 100 MB+ XRDML |
|---|---|---|
| `fileread()` loads entire XML into RAM | `importXRDML.m:139` | ~200 MB string (UTF-16) |
| Array growth via `[]` concatenation | `importXRDML.m:308+` | O(N²) copy overhead |
| Eager `meshgrid` for Qx/Qz | `importXRDML.m:496` | 2× intensity matrix size (~32 MB per 1000×1024) |
| Redundant `meshgrid` in `draw2DMap` | `dataImportGUI.m:7611` | Re-allocated every replot |
| `corrData = d` full struct copy | `dataImportGUI.m:5062` | Doubles all 2D matrices in memory |
| No memory monitoring | Everywhere | Silent OOM crash risk |

---

## Implementation Plan (10 steps, ordered by effort/impact)

### Phase 1 — Quick Wins (trivial changes, big memory savings)

#### - [x] 1. Skip corrections copy for 2D datasets

~2 lines. At top of `onApplyCorrections`, early-return for 2D datasets — corrections
are already disabled in the UI for them, so the full struct copy is pure waste.

**Touches:** `dataImportGUI.m` (`onApplyCorrections`, ~line 5051).

**Done 2026-03-14.** Added `if is2DDataset(ds), return; end` after fetching the active
dataset. Verified by `test_gui_2d` (6/6 pass).

---

#### - [x] 2. Eliminate redundant `meshgrid` in `draw2DMap`

~10 lines. `imagesc` only needs vectors, not grids. Gate the `meshgrid` call behind
`if useQSpace` and only compute for Contour/Filled Contour modes that actually need it.

**Touches:** `dataImportGUI.m` (`draw2DMap`, ~line 7662).

**Done 2026-03-14.** Angle-space branch now sets `Xmat=[]; Ymat=[];` and defers
`meshgrid` to the Contour/Filled Contour cases only. Heatmap (the common path) uses
`imagesc(ax, x2, x1, I)` with vectors directly. All 3 render modes tested via
`test_gui_2d` Test 3.

---

### Phase 2 — Lazy Q-Space Computation (medium effort, ~32 MB savings per map)

#### - [ ] 3. Move Qx/Qz computation out of the parser

New file + edits. Create `+parser/computeQSpace.m` — computes Qx/Qz from axis vectors
+ wavelength. Remove eager computation from `importXRDML.m` lines 496–504.

In `draw2DMap` and `extract2DLineCut`, call `parser.computeQSpace(map)` on demand and
cache the result in `ds.data.metadata.parserSpecific.map2D.Qx` / `.Qz` on first use.

Add `map2D.hasQSpaceData = true/false` flag so code can check capability without
triggering allocation. Idempotent: if `Qx`/`Qz` already exist, return immediately.

**Touches:** New `+parser/computeQSpace.m`, `+parser/importXRDML.m` (remove lines 496–504),
`dataImportGUI.m` (`draw2DMap`, `extract2DLineCut`).

---

### Phase 3 — Chunked File Reading (large effort, core memory reduction)

#### - [ ] 4. Stream-parse XRDML instead of `fileread`

~100 lines replacing parser lines 136–348. Two-pass approach:

- **Pass 1 (header)**: Read first ~500 lines for metadata (wavelength, instrument,
  sample name). Use existing regex helpers on this small buffer.
- **Pass 2 (scan blocks)**: `fgetl` loop that accumulates lines only inside
  `<scan>...</scan>` blocks. Process each block immediately with the existing `sscanf`
  logic, then clear the buffer.

Peak memory drops from O(file_size) to O(largest_scan_block + metadata).

**Fallback**: Keep the full-string path for files under 20 MB to avoid regressions on
small files.

**Touches:** `+parser/importXRDML.m` (major rewrite of lines 136–348).

**Risk:** Chunked reading changes the parser's fundamental I/O pattern. If the regex
helpers expect the full XML string, they will break. Mitigation: keep the `fileread`
path as fallback for files < 20 MB, so existing small-file behavior is unchanged.

---

#### - [ ] 5. Pre-allocate scan arrays

~15 lines. Quick pre-scan to count `<scan>` blocks, then pre-allocate `scanCounts`,
`scanSecVals`, etc. to avoid O(N²) concatenation growth.

**Touches:** `+parser/importXRDML.m` (array initialization section).

---

### Phase 4 — Rendering Optimizations

#### - [ ] 6. Cache the 2D graphics handle

~15 lines. Store the `imagesc`/`pcolor` handle in `appData.map2DHandle`. On replot,
update `CData` instead of `cla` + recreate. Avoids re-uploading vertex data to the
renderer.

**Touches:** `dataImportGUI.m` (`draw2DMap`).

---

#### - [ ] 7. Stride-based decimation for very large maps

~30 lines. For maps exceeding 500K total elements, apply `I(1:step:end, 1:step:end)`
before rendering. Show "Displaying at 50% resolution (2000×1024 original)" in
`lblMap2DInfo`. No dependency on Image Processing Toolbox — uses simple striding.

**Touches:** `dataImportGUI.m` (`draw2DMap`, `lblMap2DInfo`).

---

### Phase 5 — Memory Management & UX

#### - [ ] 8. File size warning before import

~10 lines. In `loadFilePaths`, check `dir(fp).bytes`. If > 50 MB, show a confirmation
dialog with estimated memory requirement. Allow user to cancel or proceed.

**Touches:** `dataImportGUI.m` (`loadFilePaths`, ~line 1621).

---

#### - [ ] 9. Memory usage display

~20 lines. Status label showing "~XX MB loaded" by summing `numel(matrix) * 8` across
all datasets. Display in GUI toolbar or status area.

**Touches:** `dataImportGUI.m` (new label + update logic in `rebuildDatasetList`).

---

#### - [ ] 10. "Clear 2D Matrix" option

~30 lines. Context menu or button that strips `map2D` from a dataset, keeping only the
1D integrated profile. Lets users reclaim memory after extracting line-cuts.

**Touches:** `dataImportGUI.m` (new button/callback in 2D panel).

---

## Optional Future Enhancement: `single` Precision

Add `Precision='single'` option to `importXRDML` — halves intensity matrix memory.
Perform Q-space math in double even when intensity is single. Axis vectors remain
double. Default remains `'double'` for backward compatibility.

**Touches:** `+parser/importXRDML.m` (option + cast), `+parser/createDataStruct.m`
(relax validation if needed).

---

## Backward Compatibility

All changes must preserve:

- The unified data struct contract (`.time`, `.values`, `.labels`, `.units`, `.metadata`)
- `map2D` field names and types
- Existing session `.mat` files load correctly
- All 8 `test_xrdml_2d.m` tests pass unchanged
- `example_rsm.m` works without modification
- New options default to current behavior

---

## Priority Recommendations

| Rank | Step | Effort | Memory Saved | Rationale |
|------|------|--------|-------------|-----------|
| 1 | #1 Skip corrections copy | ~5 min | 50% of 2D data | Trivial, immediate |
| 2 | #2 Eliminate redundant meshgrid | ~15 min | ~16 MB per replot | Small, no risk |
| 3 | #3 Lazy Qx/Qz | ~2 hr | ~32 MB per map | Medium effort, large payoff |
| 4 | #8 File size warning | ~15 min | N/A (UX) | Safety net for users |
| 5 | #6 Cache 2D graphics handle | ~30 min | N/A (speed) | Faster replot |
| 6 | #5 Pre-allocate scan arrays | ~30 min | Reduces GC pressure | Easy parser fix |
| 7 | #9 Memory usage display | ~30 min | N/A (UX) | User awareness |
| 8 | #4 Chunked file reading | ~1 day | ~200 MB for 100 MB file | Core improvement, highest risk |
| 9 | #7 Stride decimation | ~1 hr | N/A (rendering speed) | Handles extreme cases |
| 10 | #10 Clear 2D matrix | ~1 hr | User-controlled | Manual memory reclaim |
