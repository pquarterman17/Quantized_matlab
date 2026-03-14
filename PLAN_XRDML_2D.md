# Implementation Plan — PANalytical 2D Area Detector XRDML Support

## Problem

Modern PANalytical/Malvern Empyrean systems with PIXcel3D (or GaliPIX3D) area
detectors produce XRDML files containing **multi-dimensional data** — reciprocal
space maps (RSMs), pole figures, stress measurements, and rocking curves where
each scan frame records an intensity profile along the detector strip at a
different motor position.

The current `importXRDML.m` **concatenates all `<scan>` blocks into a single 1D
vector**, which is correct for multi-range 1D scans (e.g., two angular ranges
stitched together) but incorrect for 2D measurements where each scan represents
a row of a 2D intensity grid.

The GUI (`dataImportGUI.m`) only supports 1D line plots, so even if the parser
returned a 2D map, there is no rendering path for it.

---

## Background — XRDML 2D Data Structure

A reciprocal space map file typically contains N `<scan>` blocks where:

```xml
<!-- Scan 0: detector strip at Omega = 30.000° -->
<scan appendNumber="0" scanAxis="Omega" status="Completed">
  <dataPoints>
    <positions axis="2Theta" unit="deg">
      <startPosition>60.0</startPosition>
      <endPosition>62.0</endPosition>
    </positions>
    <positions axis="Omega" unit="deg">
      <commonPosition>30.000</commonPosition>    <!-- ← fixed per frame -->
    </positions>
    <counts>100 200 300 ... (M values)</counts>
  </dataPoints>
</scan>

<!-- Scan 1: detector strip at Omega = 30.005° -->
<scan appendNumber="1" scanAxis="Omega" status="Completed">
  <dataPoints>
    <positions axis="2Theta">
      <startPosition>60.0</startPosition>
      <endPosition>62.0</endPosition>
    </positions>
    <positions axis="Omega">
      <commonPosition>30.005</commonPosition>
    </positions>
    <counts>110 210 310 ... (M values)</counts>
  </dataPoints>
</scan>
```

Stacking N scans × M detector pixels → an N×M intensity matrix `I(Omega, 2Theta)`.

### Variants

| Measurement | Scanned Axis | Detector Axis | Typical Size |
|-------------|-------------|---------------|-------------|
| RSM (ω–2θ) | Omega | 2Theta | 200–2000 × 256–512 |
| Rocking curve (ω-scan) | Omega | 2Theta | 50–500 × 256 |
| Pole figure | Phi or Chi | 2Theta (fixed) | 72–360 × 1 (sum) |
| Stress (sin²ψ) | Chi | 2Theta | 10–40 × 256 |

---

## Scope

### In Scope
1. Parse 2D XRDML data into a new `map2D` struct alongside the existing 1D struct
2. Detect 1D vs 2D automatically and return the correct format
3. Display 2D maps in the GUI as a heatmap/contour plot
4. Basic 2D interactions: colorbar, log scale, 1D line-cut extraction
5. Optional Qx/Qz reciprocal-space coordinate conversion

### Out of Scope (future work)
- Full RSM fitting (peak fitting on 2D maps)
- 3D volumetric data (GaliPIX3D 3D frames)
- Live/streaming data from Data Collector

---

## Implementation Steps

### Phase 1 — Parser: Detect and Parse 2D Data

**File: `+parser/importXRDML.m`**

#### Step 1.1 — Detect dimensionality

After extracting all `<scan>` blocks (existing code, line ~175), classify the
file as 1D or 2D:

```matlab
% Heuristic: if every scan block has the same 2Theta range (within tolerance)
% and a varying second axis (Omega, Chi, Phi) as commonPosition or
% startPosition==endPosition, this is a 2D area-detector measurement.
is2D = false;
if nScans > 1
    ttRanges = zeros(nScans, 2);  % [start, end] per scan
    secAxis  = zeros(nScans, 1);  % value of the second axis per scan
    secAxisName = '';
    for s = 1:nScans
        sb = scanBlocks{sortIdx(s)};
        dpBlock = rxBlock(sb, 'dataPoints');
        ttRanges(s,:) = rxPositions(dpBlock, '2Theta');

        % Check for a secondary axis with commonPosition or start==end
        for axName = ["Omega", "Chi", "Phi"]
            pos = rxPositions(dpBlock, axName);
            if ~isempty(pos) && pos(1) == pos(2) && isempty(secAxisName)
                secAxisName = axName;
            end
            if ~isempty(pos) && strcmp(secAxisName, axName)
                secAxis(s) = pos(1);
            end
        end
    end
    % All scans share the same 2Theta range (detector coverage)
    ttSame = all(abs(ttRanges(:,1) - ttRanges(1,1)) < 1e-4) && ...
             all(abs(ttRanges(:,2) - ttRanges(1,2)) < 1e-4);
    % Secondary axis actually varies
    secVaries = range(secAxis) > 1e-6;
    is2D = ttSame && secVaries && ~isempty(secAxisName);
end
```

#### Step 1.2 — 2D assembly path

When `is2D == true`, build a 2D intensity matrix instead of concatenating:

```matlab
if is2D
    % Sort scans by secondary axis position
    [secAxisSorted, sortOrder] = sort(secAxis);

    % Each scan has M detector pixels → M columns
    nPtsPerScan = numel(sscanf(rxText(rxBlock(scanBlocks{1},'dataPoints'), ...
                        intensityTag), '%f'));
    twoThetaVec = linspace(ttRanges(1,1), ttRanges(1,2), nPtsPerScan)';
    intensityMap = zeros(nScans, nPtsPerScan);

    for i = 1:nScans
        sb = scanBlocks{sortIdx(sortOrder(i))};
        dpBlock = rxBlock(sb, 'dataPoints');
        cntStr  = rxText(dpBlock, intensityTag);
        vals    = sscanf(cntStr, '%f')';
        % Pad or trim if detector pixel count varies (shouldn't, but safety)
        n = min(numel(vals), nPtsPerScan);
        intensityMap(i, 1:n) = vals(1:n);
    end

    % Apply cps normalization
    if options.Intensity == "cps" && countingTime > 0
        intensityMap = intensityMap / countingTime;
    end
end
```

#### Step 1.3 — Dual output format

Add a new optional output field `.map2D` to the data struct when 2D data is
detected. The existing 1D output is still produced (by summing across the
detector strip or taking the integrated profile) for backward compatibility.

**New fields on `data.metadata.parserSpecific`:**

```
.is2D            logical   — true when area-detector 2D data detected
.map2D           struct    — only present when is2D == true
  .intensity     [N×M]    — intensity matrix (N = # scanned positions, M = # detector pixels)
  .axis1         [N×1]    — scanned axis values (e.g. Omega in degrees)
  .axis1Name     string   — 'Omega', 'Chi', or 'Phi'
  .axis1Unit     string   — 'deg'
  .axis2         [M×1]    — detector axis values (e.g. 2Theta in degrees)
  .axis2Name     string   — '2Theta'
  .axis2Unit     string   — 'deg'
  .Qx            [N×M]    — optional: Qx = (4π/λ) · sin(θ) · sin(ω − θ)
  .Qz            [N×M]    — optional: Qz = (4π/λ) · sin(θ) · cos(ω − θ)
```

**1D fallback** (backward compatibility):

For the 1D output (`data.time`, `data.values`), produce the integrated profile
by summing the 2D map along the detector axis:

```matlab
data.time   = twoThetaVec;                        % or secAxisSorted
data.values = sum(intensityMap, 1)';               % integrated intensity
data.labels = {'Intensity (integrated)'};
```

This ensures existing code (GUI, batch export, peak analysis) still works
without modification.

#### Step 1.4 — Reciprocal-space conversion (optional)

When wavelength is available, compute Qx/Qz from (ω, 2θ):

```matlab
% θ = 2Theta / 2, all in radians
lambda = wl.kAlpha1;  % Å
[TT, OM] = meshgrid(deg2rad(twoThetaVec), deg2rad(secAxisSorted));
theta = TT / 2;
k = 2 * pi / lambda;
map2D.Qx = k .* (cos(theta) .* sin(OM - theta));
map2D.Qz = k .* (sin(theta) .* cos(OM - theta) + sin(theta));
```

This enables reciprocal-space plotting without a separate conversion step.

---

### Phase 2 — GUI: 2D Map Visualization

**File: `dataImportGUI.m`**

#### Step 2.1 — Detect 2D datasets

Add a helper:

```matlab
function tf = is2DDataset(ds)
    tf = isfield(ds, 'data') && ...
         isfield(ds.data, 'metadata') && ...
         isfield(ds.data.metadata, 'parserSpecific') && ...
         isfield(ds.data.metadata.parserSpecific, 'is2D') && ...
         ds.data.metadata.parserSpecific.is2D;
end
```

#### Step 2.2 — 2D rendering path in `drawToAxes()`

Inside `drawToAxes()`, before the existing `for di = 1:nDS` loop, check if the
active dataset is 2D. If so, branch to a separate rendering function:

```matlab
if appData.activeIdx >= 1 && is2DDataset(appData.datasets{appData.activeIdx})
    draw2DMap(targetAx, appData.datasets{appData.activeIdx});
    return;  % skip the 1D plotting path entirely
end
```

New nested function:

```matlab
function draw2DMap(targetAx, ds)
    map = ds.data.metadata.parserSpecific.map2D;
    I = map.intensity;

    % Use Q-space or angle-space based on user toggle
    if cbUseQSpace.Value && isfield(map, 'Qx')
        x = map.Qx; y = map.Qz;
        xLabel = 'Q_x (Å⁻¹)'; yLabel = 'Q_z (Å⁻¹)';
    else
        [x, y] = meshgrid(map.axis2, map.axis1);
        xLabel = [map.axis2Name ' (' map.axis2Unit ')'];
        yLabel = [map.axis1Name ' (' map.axis1Unit ')'];
    end

    % Log intensity for XRD maps (common practice)
    if cbLogY.Value
        I = log10(max(I, 1));  % floor at 1 to avoid log(0)
    end

    % Plot as pseudocolor
    pcolor(targetAx, x, y, I);
    shading(targetAx, 'flat');
    colormap(targetAx, getActiveColormap());
    colorbar(targetAx);

    xlabel(targetAx, xLabel, 'Interpreter', 'tex');
    ylabel(targetAx, yLabel, 'Interpreter', 'tex');
    title(targetAx, ds.data.metadata.parserSpecific.sampleName, 'Interpreter', 'none');
end
```

#### Step 2.3 — UI controls for 2D mode

When a 2D dataset is active, reconfigure the analysis panel:

- **Disable** the peak tools panel (peaks are 1D concepts)
- **Replace/augment** the Y-axis listbox with:
  - A dropdown for the plot type: `Heatmap | Contour | Filled Contour`
  - A checkbox for `Q-space` vs `Angle space`
  - Contour level count edit field
- **Keep** the colormap dropdown (already exists, reuse it)
- **Keep** Log Y checkbox (reinterpret as log-intensity for 2D)

Add these widgets in a new `map2DGL` grid within the controls panel, shown/hidden
via `applyParserAnalysisConfig()` (the existing mechanism for XRD vs non-XRD
panel switching).

#### Step 2.4 — 1D line-cut extraction

Allow the user to click on the 2D map and extract a 1D profile:

- **Horizontal cut** (fixed Omega → I vs 2Theta): hold Shift + click
- **Vertical cut** (fixed 2Theta → I vs Omega): hold Ctrl + click
- The extracted 1D profile is added as a new dataset in `appData.datasets`
  with `parserName = 'lineCut'` and the usual 1D struct format
- This lets the user then apply all existing 1D tools (peak fitting, etc.) to
  the extracted profile

Implementation: add a mode check in `onAxesButtonDown()` when the active dataset
is 2D, using modifier keys to select horizontal or vertical cuts.

---

### Phase 3 — Tests

**File: `tests/test_xrdml_2d.m`**

#### Step 3.1 — Obtain test data

A real PIXcel3D XRDML file is required. Options:
- Export a small RSM from an Empyrean system (< 5 MB, 100 frames × 256 channels)
- Create a synthetic XRDML file for testing: write a minimal valid XRDML string
  with multiple `<scan>` blocks that simulate a 2D measurement

Synthetic test file generator (for CI, no instrument needed):

```matlab
function writeTestXRDML2D(filepath, nOmega, nPixels)
    % Generate a Gaussian peak in the 2D (Omega, 2Theta) space
    omega = linspace(30, 31, nOmega);
    twoTheta = linspace(60, 62, nPixels);
    [TT, OM] = meshgrid(twoTheta, omega);
    I = round(1000 * exp(-((TT-61).^2 + (OM-30.5).^2) / 0.1));
    % Write minimal XRDML ...
end
```

#### Step 3.2 — Parser tests

| Test | Description |
|------|-------------|
| `test_2d_detection` | Load 2D file → `is2D == true` |
| `test_2d_matrix_shape` | `map2D.intensity` is [N×M] |
| `test_2d_axis_values` | `map2D.axis1` matches Omega range |
| `test_2d_qspace` | `Qx`, `Qz` computed correctly for known λ |
| `test_1d_fallback` | `data.time` and `data.values` still valid 1D vectors |
| `test_1d_file_unchanged` | Existing La2NiO4 file still parses identically |
| `test_cps_normalization` | 2D intensity divided by countingTime |

#### Step 3.3 — GUI tests

| Test | Description |
|------|-------------|
| `test_gui_2d_load` | Load 2D file → `is2DDataset()` returns true |
| `test_gui_2d_plot_type` | Switching heatmap/contour triggers replot |
| `test_gui_2d_linecut` | Extract horizontal cut → new 1D dataset created |

---

### Phase 4 — Documentation & Integration

- **`importXRDML.m` docstring**: Add a "2D Area Detector Data" section documenting
  the `map2D` struct and the 1D fallback behavior
- **`CLAUDE.md`**: Add `map2D` struct to the "Output Structs" section
- **`todo.md`**: Mark the item complete
- **`examples/`**: Add `example_rsm.m` showing how to load and plot a 2D map

---

## File Change Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `+parser/importXRDML.m` | **Modify** | Add 2D detection, assembly, Q-space conversion |
| `+parser/createDataStruct.m` | **No change** | 1D fallback uses existing struct |
| `dataImportGUI.m` | **Modify** | Add `draw2DMap()`, `is2DDataset()`, 2D UI controls, line-cut extraction |
| `tests/test_xrdml_2d.m` | **New** | 2D parser + GUI tests |
| `+test_datasets/XRDML/synthetic_rsm.xrdml` | **New** | Synthetic 2D test file |
| `examples/example_rsm.m` | **New** | Example script for 2D RSM plotting |

---

## Risks & Open Questions

1. **No test file yet** — The plan relies on the XRDML schema documentation and
   common PANalytical output patterns. A real PIXcel3D file is needed to validate
   the detection heuristic. The synthetic file covers CI but may miss edge cases
   (varying pixel counts across frames, non-uniform Omega spacing).

2. **Large file sizes** — RSMs can be 50–200 MB. The current `fileread + regexp`
   approach loads the entire file into memory. For very large files, a streaming
   parser (reading scan blocks incrementally) may be needed. Start with the
   current approach and add streaming if performance is insufficient.

3. **Pole figures** — A pole figure has a single intensity value per (Chi, Phi)
   point (the detector channels are summed). This is 2D in a different sense
   (azimuthal + tilt). The same `map2D` struct can represent this but the GUI
   would need a polar plot mode. Defer polar plotting to a future phase.

4. **`createDataStruct` constraints** — The unified struct expects a 1D `timeVec`.
   The 2D map is stored in `metadata.parserSpecific.map2D`, not as a first-class
   citizen. This is a pragmatic compromise — restructuring `createDataStruct` to
   support N-D data would break every parser and the entire GUI. The 1D fallback
   ensures backward compatibility.

5. **Corrections pipeline** — The corrections panel (X/Y offset, BG subtraction,
   smoothing, normalization) is designed for 1D data. For 2D datasets, corrections
   should be disabled (similar to how neutron data disables most corrections).
   Use the existing `applyParserAnalysisConfig()` mechanism.

---

## Suggested Implementation Order

```
Phase 1.1  → Detect 1D vs 2D             (parser, ~1 hr)
Phase 1.2  → Build 2D intensity matrix    (parser, ~1 hr)
Phase 1.3  → Dual output format           (parser, ~30 min)
Phase 3.1  → Synthetic test file          (tests, ~30 min)
Phase 3.2  → Parser unit tests            (tests, ~1 hr)
Phase 2.1  → is2DDataset helper           (GUI, ~15 min)
Phase 2.2  → draw2DMap rendering          (GUI, ~2 hr)
Phase 2.3  → 2D UI controls              (GUI, ~1 hr)
Phase 2.4  → Line-cut extraction          (GUI, ~1 hr)
Phase 1.4  → Q-space conversion           (parser, ~30 min)
Phase 3.3  → GUI tests                    (tests, ~30 min)
Phase 4    → Docs & examples              (docs, ~30 min)
```

Total estimated effort: ~10 hours

Priority order: Parser detection/assembly first (phases 1.1–1.3), then basic GUI
rendering (phase 2.2), then the rest. This gives a working end-to-end path as
early as possible.
