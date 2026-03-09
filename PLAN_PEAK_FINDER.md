# Plan: Replace XRD Auto Peak Finder with SNIP-based Approach

## Context
The current peak finder (`onAutoPeak` at line 2386 in `dataImportGUI.m`) is fundamentally broken for XRD data:
- **XRDML files**: Finds hundreds of false peaks (noise fluctuations)
- **Rigaku .raw files**: Finds too many peaks including noise bumps
- **Root cause**: Prominence-based thresholds (even noise-adaptive MAD ones) cannot separate real Bragg peaks from noise when XRD data has high dynamic range and varying baselines

**Solution**: Replace with SNIP (Statistics-sensitive Non-linear Iterative Peak-clipping) — the industry-standard algorithm for X-ray spectroscopy background estimation. By subtracting the background first, peak detection becomes trivial: just find local maxima above a noise threshold on a flat baseline.

---

## Step 1 — Create `+utilities/estimateBackground.m` [Sonnet]

**New file**: `+utilities/estimateBackground.m`

SNIP algorithm implementation:
```matlab
function bg = estimateBackground(x, y, options)
    arguments
        x (:,1) double; y (:,1) double
        options.MaxWindowDeg (1,1) double {mustBePositive} = 2.0
        options.SmoothPasses (1,1) double {mustBeNonnegative, mustBeInteger} = 3
    end
```

**Algorithm**:
1. `dx = median(diff(x))` -> `wMax = round(MaxWindowDeg / dx)`, clamped to `floor((n-1)/2)`
2. Transform: `v = sqrt(max(y, 0))` (stabilizes Poisson noise)
3. SNIP loop: `for w = wMax:-1:1`, for each interior point: `v(i) = min(v(i), (v(i-w) + v(i+w))/2)`
4. Back-transform: `bg = v.^2`
5. Optional light moving-average smooth (window=5) for `SmoothPasses` to reduce staircase artifacts

No dependencies. Pure function. Full docstring with Syntax/Inputs/Outputs/Examples per project conventions.

---

## Step 2 — Create `+utilities/findPeaksRobust.m` [Sonnet]

**New file**: `+utilities/findPeaksRobust.m`
**Depends on**: Step 1

```matlab
function [peaks, bgEstimate] = findPeaksRobust(x, y, options)
    arguments
        x (:,1) double; y (:,1) double
        options.SNRThreshold  (1,1) double {mustBePositive} = 5
        options.MinSeparation (1,1) double {mustBeNonnegative} = 0
        options.MaxPeaks      (1,1) double {mustBePositive, mustBeInteger} = 50
        options.MaxWindowDeg  (1,1) double {mustBePositive} = 2.0
        options.MinWidthDeg   (1,1) double {mustBePositive} = 0.01
        options.MaxWidthDeg   (1,1) double {mustBePositive} = 5.0
    end
```

**Algorithm**:
1. `bgEstimate = utilities.estimateBackground(x, y, 'MaxWindowDeg', MaxWindowDeg)`
2. `residual = y - bgEstimate`
3. Noise estimation: MAD of residual in below-median regions -> `noiseSigma`
4. Local maxima: `residual(i) > residual(i-1) && residual(i) > residual(i+1)`
5. SNR filter: keep where `residual(i) >= SNRThreshold * noiseSigma`
6. FWHM estimation: walk left/right from peak until residual drops to half-max. Reject if FWHM outside `[MinWidthDeg, MaxWidthDeg]`
7. Min distance suppression (greedy, tallest first)
8. Cap at `MaxPeaks` (keep tallest)
9. Return struct array matching `ds.peaks` format:
   - `center`, `fwhm`, `height` (= amplitude above background), `area` (NaN)
   - `xRange` ([]), `status` ('auto'), `bg` (= bgEstimate at peak), `model` (''), `eta` (NaN)

Returns `bgEstimate` as second output for plot overlay.

---

## Step 3 — Rewrite `onAutoPeak()` in dataImportGUI.m [Opus]

**Edit**: `dataImportGUI.m` lines 2386-2623
**Depends on**: Steps 1, 2, 7

Replace the three-pass body (findpeaks -> secondDerivativePeaks -> manual seeds) with:

1. **Keep**: dataset validation, x/y vector resolution, NaN removal, x-range restriction (lines 2394-2430)
2. **Keep**: manual seed extraction (lines 2456-2463)
3. **Replace** all of Pass 1, Pass 1b, and the local prominence filter with:
   ```matlab
   userMinSep = efMinSep.Value;
   [autoPeaks, bgEst] = utilities.findPeaksRobust(xv(:), yv(:), ...
       'SNRThreshold', 5, ...
       'MinSeparation', guiTernary(userMinSep>0, userMinSep, 0), ...
       'MaxPeaks', 50, 'MaxWindowDeg', 2.0);
   ds.snipBackground = struct('x', xv(:), 'bg', bgEst(:));
   merged = autoPeaks;
   ```
4. **Keep**: Pass 2 manual seed re-detection (lines 2563-2603, uses try/catch findpeaks with local-max fallback)
5. **Keep**: deduplication and sorting (lines 2606-2622)

---

## Step 4 — Add background overlay in `drawToAxes()` [Opus]

**Edit**: `dataImportGUI.m` around line 6392 (after peak annotations block)
**Depends on**: Step 3

1. Add cleanup: `delete(findall(targetAx, 'Tag', 'GUISNIPBackground'))` alongside existing tag cleanup (~line 5641)
2. After peak rendering, draw the background:
   ```matlab
   if appData.showSnipBg && isfield(ds, 'snipBackground') && ~isempty(ds.snipBackground.x)
       plot(targetAx, ds.snipBackground.x, ds.snipBackground.bg + pkYOff, '--', ...
           'Color', [0.2 0.6 0.2], 'LineWidth', 1.5, 'HitTest', 'off', ...
           'Tag', 'GUISNIPBackground', 'HandleVisibility', 'off');
   end
   ```
3. Initialize `appData.showSnipBg = true` near line 256

---

## Step 5 — Add "Show BG" checkbox [Sonnet]

**Edit**: `dataImportGUI.m` in the `minSepGL` sub-grid (inside `peakBtnGL` row 13)
**Depends on**: Step 4

- Expand `minSepGL` from `[4 2]` to `[5 2]`
- Add `chkShowBG` checkbox at row 5 spanning both columns
- Callback toggles `appData.showSnipBg` and calls `onPlot`

---

## Step 6 — Remove old helper functions [Sonnet]

**Delete** from `dataImportGUI.m`:
**Depends on**: Step 3 (old code no longer called)

- `secondDerivativePeaks()` (~lines 7413-7531, ~119 lines)
- `simplePeakFind()` (~lines 7534-7600, ~67 lines)

**Keep**: `deduplicatePeaks()` (still used for merging auto + manual peaks)

---

## Step 7 — Housekeeping [Sonnet]

Small independent fixes (no dependencies, can run in parallel with Step 1):

1. Add `snipBackground` field in `buildDs()` (~line 7633):
   ```matlab
   ds.snipBackground = struct('x',[],'bg',[]);
   ```
2. Backward-compat guard in `onLoadSession`: if `snipBackground` field missing, add empty default
3. Update tooltip on `btnAutoPeak` (line 665) to mention SNIP instead of findpeaks
4. Fix `importBruker` missing from XRD parser case in `applyParserAnalysisConfig` (line 2144)

---

## Execution Order

```
Phase 1 (parallel, all independent):
  Step 1  [Sonnet]  estimateBackground.m
  Step 7  [Sonnet]  Housekeeping (buildDs, tooltip, importBruker fix)

Phase 2:
  Step 2  [Sonnet]  findPeaksRobust.m (depends on Step 1)

Phase 3 (Opus, together):
  Step 3  [Opus]    Rewrite onAutoPeak
  Step 4  [Opus]    Add BG overlay to drawToAxes

Phase 4 (parallel, both simple):
  Step 5  [Sonnet]  Add "Show BG" checkbox
  Step 6  [Sonnet]  Remove old helper functions
```

---

## Key Files

| File | Action |
|------|--------|
| `+utilities/estimateBackground.m` | **NEW** — SNIP background estimation |
| `+utilities/findPeaksRobust.m` | **NEW** — Robust peak finder |
| `dataImportGUI.m` | **EDIT** — Rewrite onAutoPeak, add BG overlay, add checkbox, remove old helpers, housekeeping |

---

## Verification

1. Load XRDML file (La2NiO4), click Auto Find Peaks -> should find ~5-15 real Bragg peaks, green dashed background curve visible
2. Load Rigaku .raw file (YIG_Py_S3), click Auto Find Peaks -> should find all visible peaks including thin-film peaks at ~33, 38, 40, 84 degrees
3. Toggle "Show BG" checkbox -> background curve appears/disappears
4. Manual peak add -> should still work alongside auto detection
5. Fit Peaks / Fit All -> should work on auto-detected peaks
6. Save/load session -> snipBackground field persists correctly
7. Load non-XRD file (VSM) -> Auto Find Peaks button should remain hidden (no regression)
