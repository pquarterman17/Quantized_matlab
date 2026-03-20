# CLAUDE.md — Matlab Toolbox

## Project Overview

Scientific data analysis toolbox for processing and visualizing magnetometry and generic lab data from laboratory instruments. Supports Quantum Design PPMS/VSM/DynaCool/MPMS, Rigaku XRD, PANalytical XRDML, Bruker XRD, Lake Shore VSM, NCNR neutron reflectometry, SIMS depth profiles, and generic CSV/Excel/TSV data.

## Repository Structure

```
thin_film_toolkit_matlab/
├── setupToolbox.m          # Entry point — adds toolbox root to MATLAB path
├── DataPlotter.m         # Interactive uifigure GUI: browse, preview, correct, peaks, export
├── xrdConvertGUI.m         # Standalone batch XRD file converter GUI
├── materialsCalcGUI.m      # Materials calculator GUI (13 tabs: units, crystal, electrical, semiconductor, thin film, X-ray/neutron, superconductor, optics, vacuum, electrochem, multilayer, periodic table, favorites)
├── emViewerGUI.m           # Standalone electron microscopy image viewer (TIFF/RAW/DM3/DM4)
├── runAllTests.m           # Master test runner; groups: parser/batch/xrd2d/gui/em/emgui/all
├── tests/                  # All test scripts (run via: run tests/test_parsers)
│   ├── test_parsers.m              # Smoke tests for all +parser functions
│   ├── test_importAuto.m           # Smoke tests for parser.importAuto dispatch
│   ├── test_parsers_edge_cases.m   # Edge-case and error-handling tests
│   ├── test_gui_harness.m          # Automated GUI API tests
│   ├── test_data_roundtrip.m       # CSV export round-trip tests
│   ├── test_batch_processing.m     # batchImport / batchConvertXRD integration
│   ├── test_batch_xrd_converter.m  # XRD converter edge cases
│   ├── test_xrdml_2d.m             # 2D area-detector parser tests (8 tests)
│   ├── test_xrdml_2d_edge.m        # Edge cases: missing wavelength, malformed XML, single-frame files
│   ├── test_gui_2d.m               # 2D GUI API tests (6 tests)
│   ├── test_gui_phase4.m           # Phase-4 GUI feature tests (annotations, Y2, waterfall, session)
│   ├── test_sims_parser.m          # SIMS depth profile parser tests (synthetic data)
│   ├── test_em_parsers.m           # EM image parser tests: importTIFF + importRawImage + importDM3 (synthetic)
│   ├── test_imaging_utils.m        # Unit tests for all +imaging functions
│   ├── test_em_gui_harness.m       # Headless emViewerGUI API tests (12 tests)
│   ├── test_eds_composite.m        # EDS multi-channel composite mode tests (10 tests)
│   ├── test_calc_xrayneutron.m    # X-ray/Neutron module tests
│   ├── test_superconductor.m      # Superconductor module tests
│   ├── test_cif_parser.m          # CIF parser and crystal cache tests
│   ├── test_eels.m                 # EELS utility tests (synthetic data)
│   ├── test_diffraction_index.m    # Diffraction indexing tests
│   ├── test_eds_quantification.m   # EDS quantification tests
│   └── archive_2026-03-10/         # Superseded tests (kept for reference)
├── +parser/                # Data import namespace
│   ├── importAuto.m        # Auto-detect file type and dispatch to correct parser
│   ├── resolveParser.m     # Dispatch table: map extension + magic-byte → parser function handle
│   ├── importCSV.m         # Universal CSV/TSV importer with auto-detection
│   ├── importExcel.m       # Excel (.xlsx/.xls/.ods) importer
│   ├── importQDVSM.m       # Quantum Design VSM/DynaCool importer (.dat)
│   ├── importPPMS.m        # Legacy QD PPMS importer (.dat); auto-detects tab/comma
│   ├── importMPMS.m        # Quantum Design MPMS SQUID magnetometer (.dat); wrapper over importQDVSM
│   ├── importLakeShore.m   # Lake Shore VSM/cryostat CSV/DAT; auto-detects header block
│   ├── importRigaku_raw.m  # Rigaku SmartLab binary .raw importer (magic "FI")
│   ├── importXRDML.m       # PANalytical/Malvern XRDML XML; 1D scan + 2D area-detector; Q-space
│   ├── importBruker.m      # Bruker .brml ZIP+XML and .raw v3 binary (magic "RAW1.01")
│   ├── importNCNRRefl.m    # NCNR polarized neutron reflectometry .refl files (R vs Q + errors)
│   ├── importNCNRPNR.m     # NCNR polarized neutron reflectometry .pnr files; cross-section resolved
│   ├── importNCNRDat.m     # refl1d fit output .datA/.datB/.datC/.datD; theory + data overlay
│   ├── importSIMS.m        # SIMS depth profile CSV; paired or shared-depth columns; grid merging
│   ├── importTIFF.m        # TIFF images (8/16/32-bit, grayscale/RGB, multi-page stacks, FEI metadata)
│   ├── importRawImage.m    # Headerless binary images; requires user-specified Width/Height/BitDepth
│   ├── importDM3.m         # Gatan DigitalMicrograph DM3/DM4; recursive tag tree; calibration + metadata
│   └── createDataStruct.m  # Validates and assembles the unified data struct
├── +imaging/               # EM image processing utilities (no toolbox required)
│   ├── adjustContrast.m    # Window/level linear stretch; clamps to [Low, High]
│   ├── applyGaussian.m     # 2D Gaussian filter via conv2 with manual kernel
│   ├── applyMedian.m       # 2D median filter (vectorised sort; window 3-7)
│   ├── computeFFT.m        # FFT magnitude/phase display; fft2 + fftshift + log scaling
│   ├── lineProfile.m       # Intensity along a line via interp2; optional pixel calibration
│   ├── measureDistance.m   # Calibrated point-to-point Euclidean distance
│   ├── addScaleBar.m       # Scale bar rectangle + label overlay on axes
│   ├── generateThumbnail.m # Downsample via block-averaging or bilinear interp2
│   ├── eelsEdgeTable.m     # Built-in EELS core-loss edge database (~50 edges)
│   ├── eelsBackground.m    # Power-law/exponential EELS background subtraction
│   ├── eelsThicknessMap.m  # Log-ratio t/λ thickness from spectrum image
│   ├── eelsAlignZLP.m      # Zero-loss peak alignment via cross-correlation
│   ├── eelsExtractMap.m    # Elemental map extraction from EELS spectrum image
│   ├── calcElectronWavelength.m # Relativistic electron wavelength (kV → Å)
│   ├── findDiffractionSpots.m   # Auto-detect spots in diffraction patterns
│   ├── indexDiffraction.m  # Match diffraction spots to crystal phase database
│   ├── cliffLorimer.m      # Cliff-Lorimer thin-film EDS quantification
│   ├── edsKFactorTable.m   # Built-in k-factors relative to Si (200 kV)
│   └── edsCompositionProfile.m # Composition line profile from EDS maps
├── +plotting/              # Plot helper functions
│   ├── formatAxes.m        # Apply theme to an axes object (fonts, grid, labels)
│   ├── lineColors.m        # Return N colours from the active theme palette
│   └── saveFigure.m        # Export figure to PNG/PDF/SVG/EPS at set dimensions
├── +styles/
│   └── default.m           # Default visual theme struct (colours, widths, font sizes)
├── +utilities/             # General-purpose data helpers
│   ├── normalize.m         # Normalise columns: range / peak / z-score
│   ├── smoothData.m        # Moving-average or Gaussian smoothing (no toolbox)
│   ├── convertUnits.m      # Convert between common lab units (field, moment, temp, …)
│   ├── writeXRDcsv.m       # Write XRD data to CSV (standard or Origin ASCII format)
│   ├── estimateBackground.m # Polynomial background estimation for XRD/spectroscopy data
│   ├── findPeaksRobust.m   # Peak detection with prominence filtering (no toolbox required)
│   ├── pseudoVoigt.m       # Pseudo-Voigt peak shape function (eta-weighted Gaussian+Lorentzian)
│   ├── derivative.m        # Numerical derivative (dY/dX, d²Y/dX²) with optional pre-smoothing
│   ├── cumulativeIntegral.m # Cumulative trapezoidal integral (∫Y dx)
│   ├── logDerivative.m     # Logarithmic derivative d(log Y)/d(log X) for power-law detection
│   ├── datasetAlgebra.m    # Combine two datasets: A±B, A×B, A/B, (A-B)/(A+B) asymmetry
│   └── confidenceBand.m    # Mean±std or median±IQR from N repeat datasets
└── +scripts/
    ├── batchImport.m       # Walk a directory, call importAuto on each supported file
    ├── batchConvertXRD.m   # Batch-convert XRD files (.xrdml/.raw/.brml) to CSV via writeXRDcsv
    └── quickPlot.m        # Auto-detect & plot one or more data files (type-aware defaults)
```

## Supported Data Formats

| Format | Parser | Description |
|--------|--------|-------------|
| Quantum Design VSM `.dat` | `importQDVSM.m` | Magnetometry (M vs H, M vs T); [Header]/[Data] markers |
| QD PPMS `.dat` (legacy) | `importPPMS.m` | Older PPMS magnetometry CSV/TSV format; auto-detects delimiter |
| QD MPMS `.dat` | `importMPMS.m` | SQUID magnetometry; thin wrapper over `importQDVSM` with MPMS column shortcuts |
| Lake Shore `.dat` / `.csv` | `importLakeShore.m` | VSM/cryostat; auto-detect header block; flexible x/y column selection |
| CSV / TSV / TXT | `importCSV.m` | Generic lab data with auto-detection of delimiter, headers, units |
| Excel `.xlsx/.xls/.ods` | `importExcel.m` | Spreadsheet data with unit row support |
| Rigaku SmartLab `.raw` | `importRigaku_raw.m` | Binary XRD file (magic "FI"); warns on multi-range files |
| PANalytical XRDML `.xrdml` | `importXRDML.m` | XML XRD; 1D scan or 2D area-detector map; Q-space conversion |
| Bruker `.brml` / `.raw` | `importBruker.m` | Dual-path: ZIP+XML or v3 binary; magic-byte detection ("RAW1.01") |
| NCNR reflectometry `.refl` | `importNCNRRefl.m` | Polarized neutron reflectometry from NCNR; R vs Q with error bars |
| NCNR PNR `.pnr` | `importNCNRPNR.m` | Polarized neutron reflectometry; cross-section resolved (R+, R−) |
| NCNR fit output `.datA/.datB` | `importNCNRDat.m` | refl1d fit output; theory + data overlay; also handles `.datC/.datD` |
| SIMS depth profile `.csv` | `importSIMS.m` | Paired or shared-depth column layout; per-element grid merging via interpolation |
| TIFF image `.tif` / `.tiff` | `importTIFF.m` | 8/16/32-bit grayscale or RGB; multi-page stacks; FEI/Thermo Fisher tag 34682 metadata |
| RAW image `.raw` (headerless) | `importRawImage.m` | Headerless binary; requires explicit Width, Height, BitDepth — not auto-dispatchable |
| Gatan DM3/DM4 `.dm3` / `.dm4` | `importDM3.m` | Gatan DigitalMicrograph v3/v4 recursive tagged binary; pixel calibration; ImageTags metadata |

## Conventions

### Naming
- **Functions:** `PascalCase` (`importCSV`, `importQDVSM`, `createDataStruct`)
- **Parameters:** named arguments via `arguments` block; booleans as `true`/`false`
- **Variables:** `camelCase` for local vars (`colIdx`, `rawMatrix`); struct fields use lowercase

### Output Structs
All parsers return unified structs with consistent fields:
- `.time` — x-axis values (numeric vector or datetime)
- `.values` — [N×K] data matrix
- `.labels` — channel names (cell array of strings)
- `.units` — unit strings (cell array)
- `.metadata` — instrument params, source file info

#### 2D area-detector extension (`importXRDML` only)
When a PANalytical XRDML file contains multi-frame area-detector data,
`data.metadata.parserSpecific` gains:
- `.is2D` — `true`; also present (as `false`) for 1D files for explicit checking
- `.map2D.intensity` — [N×M] matrix (N Omega frames × M detector pixels), cps or counts
- `.map2D.axis1` / `.axis1Name` / `.axis1Unit` — scanned motor positions (e.g. Omega, deg)
- `.map2D.axis2` / `.axis2Name` / `.axis2Unit` — detector strip (2Theta, deg)
- `.map2D.Qx`, `.map2D.Qz` — [N×M] reciprocal-space grids (Å⁻¹); present when wavelength available
- `data.time` / `data.values` — integrated profile `sum(intensity, 1)'` (1D fallback)

### Dataset struct (GUI internal)
Each loaded file is stored as a `ds` struct inside `appData.datasets`:
- `.data`, `.corrData` — raw and corrected data structs
- `.xOff`, `.yOff`, `.bgSlope`, `.bgInt` — per-dataset correction values
- `.peaks` — struct array of detected/fitted peaks
- `.axLims` — per-dataset axis limit strings (persisted across dataset switches)

### Column Shorthands (`importQDVSM` / `importPPMS`)
- `'field'` → Magnetic Field (Oe)
- `'moment'` → Moment (emu)
- `'temp'` / `'temperature'` → Temperature (K)
- `'time'` → Time Stamp
- `'stderr'` → M. Std. Err.
- `'all'` → all numeric columns except x-axis

### Documentation
- Every public function has a docstring with: Syntax, Inputs, Outputs, Examples
- Section dividers use `% ════════...` style

## Common Workflows

### Magnetometry (PPMS/VSM)
```matlab
data = parser.importQDVSM('sample.dat', 'XAxis', 'field', 'YAxis', 'moment');
```

### XRD (Rigaku)
```matlab
data = parser.importRigaku_raw('scan.raw', 'UseCountsPerSec', true);
```

### XRD 2D reciprocal-space map (PANalytical area detector)
```matlab
data = parser.importXRDML('rsm.xrdml', Intensity='cps');
map  = data.metadata.parserSpecific.map2D;  % only present when is2D==true

% Angle-space heatmap
imagesc(map.axis2, map.axis1, log10(map.intensity));
axis xy; colorbar; colormap parula;
xlabel('2\theta (deg)'); ylabel('\omega (deg)');

% Q-space heatmap (requires wavelength in file)
if isfield(map, 'Qx')
    pcolor(map.Qx, map.Qz, log10(map.intensity)); shading flat;
end

% Extract a rocking curve (V-cut) at the peak 2Theta
[~, col] = min(abs(map.axis2 - 61.0));
plot(map.axis1, map.intensity(:, col));
```

### Generic CSV
```matlab
data = parser.importCSV('data.csv');  % auto-detects delimiter, headers, units
```

### Auto-dispatch
```matlab
data = parser.importAuto('sample.dat');   % picks parser from extension + content
```

### Batch import
```matlab
results = scripts.batchImport('measurements/', 'Recursive', true);
good = results(cellfun(@isempty, {results.error}));
```

### Batch XRD conversion (XRDML → CSV)
```matlab
% Convert all XRD files in a folder to CSV
results = scripts.batchConvertXRD('measurements/', ...
    Format='standard', Intensity='both', OutputDir='csv_out/');

% Or launch the interactive GUI
xrdConvertGUI

% Or convert a single file directly
data = parser.importXRDML('scan.xrdml');
utilities.writeXRDcsv(data, 'scan.csv', Format='origin', Intensity='cps');
```

### SIMS Depth Profile
```matlab
data = parser.importSIMS('sims_profile.csv');
% data.time = depth grid (nm), data.values = [NxM] concentration matrix
% data.labels = element names, data.units = concentration units

% Access original per-element depth vectors (before grid merging)
origD = data.metadata.parserSpecific.originalDepths;
origC = data.metadata.parserSpecific.originalConcentrations;

% Or use the GUI: load a CSV, switch ddCorrStyle to "SIMS Depth Profile"
DataPlotter
```

### Neutron reflectometry (NCNR)
```matlab
% Import polarized neutron data
data = parser.importNCNRRefl('sample.refl');
% data.time = Q (Å⁻¹), data.values = [R+, R-, Rerr+, Rerr-]

% Import cross-section-resolved PNR data
data = parser.importNCNRPNR('sample.pnr');

% Import refl1d fit output (theory + data overlay)
data = parser.importNCNRDat('fit.datA');

% Or auto-dispatch for any supported format
data = parser.importAuto('sample.refl');
```

### Plotting helpers
```matlab
th = styles.default();
cols = plotting.lineColors(3, th);
fig = figure;  plot(data.time, data.values, 'Color', cols(1,:));
plotting.formatAxes(gca, th, 'XLabel', '2\theta (°)', 'YLabel', 'Counts');
plotting.saveFigure(fig, 'scan.pdf');
```

### Data utilities
```matlab
normI  = utilities.normalize(data.values);               % [0,1] range
smI    = utilities.smoothData(data.values, 'Window', 9); % Gaussian smooth
[H_T, u] = utilities.convertUnits(data.time, 'Oe', 'T');

% Derivatives and transforms
dydx   = utilities.derivative(data.time, data.values);            % dY/dX
d2ydx2 = utilities.derivative(data.time, data.values, 'Order', 2); % d²Y/dX²
intY   = utilities.cumulativeIntegral(data.time, data.values);    % ∫Y dx
dlogy  = utilities.logDerivative(Q, R, 'PreSmooth', 3);           % power-law exponent

% Dataset algebra
diff  = utilities.datasetAlgebra(dsA, dsB, 'A-B');
asym  = utilities.datasetAlgebra(Rup, Rdown, '(A-B)/(A+B)');
ratio = utilities.datasetAlgebra(dsA, dsB, 'A/B', 'InterpMethod', 'pchip');

% Confidence band from N repeat measurements
band = utilities.confidenceBand({d1, d2, d3, d4, d5}, 'Method', 'mean');
fill([band.x; flipud(band.x)], [band.upper; flipud(band.lower)], ...
     'b', 'FaceAlpha', 0.2);
hold on; plot(band.x, band.center, 'b-', 'LineWidth', 1.5);
```

### Interactive GUI
```matlab
DataPlotter   % browse, preview, apply corrections, find/fit peaks, export CSV
```

### Quick Plot (command-line)
```matlab
% Single file — auto-detects data type, labels axes, picks scale
scripts.quickPlot('scan.xrdml')

% Overlay multiple files with normalization
scripts.quickPlot({'vsm1.dat', 'vsm2.dat'}, 'Normalize', true)

% Subplots layout with log Y
scripts.quickPlot({'a.dat', 'b.dat'}, 'Layout', 'subplots', 'LogY', true)

% Save to file
scripts.quickPlot('refl.refl', 'SaveAs', 'reflectivity.pdf')
```

Type-aware defaults: XRD → 2θ/Intensity, Magnetometry → Field/Moment (or Temp), Reflectometry → Q/R (log), SIMS → Depth/Concentration.

Options: `LogY`, `Normalize`, `SaveAs`, `Title`, `XLabel`, `YLabel`, `Layout` ('overlay'|'subplots'), `Theme`.

### Advanced Figure Builder (GUI)
Launched from DataPlotter → Tools → **Figures...** button. Opens a popup with 8 figure types:

| Type | Description |
|------|-------------|
| Multi-Panel | NxM grid with per-panel datasets/channels, row/col span, dual Y axis |
| Quick Grid | One dataset per cell, auto-tiled |
| Waterfall | Stacked offset traces with right-edge labels |
| Overlay + Residual | Two-panel: overlay + A-B difference |
| Normalized Overlay | Peak/range/z-score/area normalization with optional X alignment |
| Before / After | Side-by-side raw vs corrected |
| Parameter Evolution | Track peak metrics across datasets |
| Broken Axis | Split X or Y axis with gap and diagonal break marks |
| Confidence Band | Mean±std or median±IQR shaded band from N repeat datasets |

Global options: journal templates (APS/Nature/ACS), error style (bars/band), grayscale mode (line-style + marker cycling), font, dimensions.

Post-generation toolbar on every output figure: H/V reference lines, shaded regions, text/arrow annotations, peak labels, inset zoom. Multi-Panel and Quick Grid figures also get a linked cursor (vertical line tracking across all panels on hover).

### Advanced DataPlotter Tools

| Tool | Button | Description |
|------|--------|-------------|
| Data Cursor | `Cursor` | Click to snap to nearest point (x,y); click again for delta (dx,dy) |
| Dataset Math | `Math...` | Combine two datasets: A±B, A×B, A/B, (A-B)/(A+B) with interpolation |
| Multi-Dataset Overlay | `Overlay` checkbox | Select all datasets and overlay on same axes with unified legend |
| Plot Templates | `Templates...` | Save/load axis limits, corrections, labels, scale as reusable .mat presets |
| Batch Figure Export | `Batch Figs...` | Export every loaded dataset as individual PNG/PDF/SVG/EPS with journal template |
| Advanced Analysis | `⚙ Advanced ▾` | Popup menu: Integrate, Dataset Math, Curve Fit, Resample, Column Calculator, Inset Plot, Graph Digitizer |
| Data Table | `▾ Data Table` bar | Collapsible spreadsheet below plot: view/edit all data, mask rows, column stats, Save As (CSV/Excel) |

### Data Table (Spreadsheet View)

Collapsible panel below the plot axes. Toggle via the "▾ Data Table" bar.

- **Full cell editing** — click any cell to modify values; edits stored in a working copy (original data untouched)
- **Units row** — displays column units from the parser
- **Column stats** — row count, column count, masked point count in the toolbar
- **Data masking** — select rows → "Mask Sel." to exclude from plot/analysis; "Unmask All" to restore
- **Save As** — export working copy (with edits) to new CSV or Excel file; optionally exclude masked rows
- **Auto-refresh** — table updates when switching datasets or applying corrections

### General Curve Fitting (Advanced > Curve Fit...)

Separate dialog with 15 built-in models:

| Category | Models |
|----------|--------|
| Linear/Polynomial | Linear, Poly 2, Poly 3 |
| Exponential | Decay, Growth, Double Decay |
| Peak shapes | Gaussian, Lorentzian, Voigt (approx) |
| Other | Power Law, Sigmoid, Arrhenius, Langmuir, Logarithmic, Sqrt |

- **X-range limiting** — fit only within [Xmin, Xmax]
- **Editable initial guesses** — auto-populated from data, user can override
- **Fit engine** — `fminsearch` (Nelder-Mead simplex), 10k eval limit
- **Results** — R², RMSE, parameter table, fit curve + residual plot
- **Plot on Main** — overlay fit curve on DataPlotter axes with equation annotation
- **Copy** — parameters + stats to clipboard

**Future:** Custom equation editor, Levenberg-Marquardt, weighted fitting, confidence bands, global fitting.

### Graph Digitizer (Advanced > Graph Digitizer...)

Extract data points from a screenshot or image of a published graph:

1. **Load Image** — browse for PNG/JPG/TIFF screenshot of a figure
2. **Set Axes (4 clicks)** — click 4 reference points in order: X1 (left), X2 (right), Y1 (bottom), Y2 (top), then enter their known data values
3. **Collect Points** — click on data points; pixel coords auto-converted to data coords via linear calibration
4. **Export** — save as CSV or load directly into DataPlotter as a new dataset (auto-sorted by X)

Features: undo last point, clear all, editable point table, orange calibration markers, red crosshair data markers.

### Peak Deconvolution (Visual Decomposition)

After running "Fit All (global)" in the Peak Analysis window, individual peak components are automatically overlaid on the main plot:
- Each peak drawn as a **dashed colored curve** (unique color per peak)
- **Composite model** drawn as solid red line (sum of all peaks + background)
- **Linear background** drawn as dotted gray line
- All overlays tagged `GUIPeakDecomp` and cleared on next plot redraw
- Also callable programmatically via `onShowDecomposition()`

### Contour / Heatmap (Figure Builder)

New figure type in Advanced Figure Builder: **Contour / Heatmap**

- Select dataset, X/Y/Z columns from dropdowns
- 4 plot styles: Filled contour, Contour lines (labeled), Pseudocolor (pcolor), Surface (3D)
- 10 colormaps (parula, viridis, plasma, inferno, hot, jet, turbo, gray, bone, copper)
- Scattered XYZ data auto-gridded via `scatteredInterpolant` (or `griddata` fallback)
- 3D Surface mode enables `rotate3d` for interactive viewing

### Transform Options (Corrections Panel)

The derivative dropdown now includes 5 options: `None`, `dY/dX`, `d²Y/dX²`, `∫Y dx` (cumulative integral), `dlog/dlog` (log derivative for power-law detection).

### 2D Map Colormap Editor

For 2D XRDML area-detector data, the map panel includes: intensity scale (Linear/Log₁₀), colorbar min/max range override, 10 colormaps (parula, viridis, plasma, inferno, hot, jet, turbo, gray, bone, copper).

### Asymmetric Error Bars

The Figure Builder auto-detects separate upper/lower error columns (e.g., `dR+`/`dR-`, `Rerr+`/`Rerr-`) and renders as asymmetric error bars or asymmetric shaded bands.

### EM Image Viewer
```matlab
% Launch the GUI interactively
emViewerGUI

% Programmatic usage (e.g. in scripts or tests)
api = emViewerGUI();
api.loadImages({'sem_image.tif'});
api.autoContrast();
api.getLineProfile(10, 10, 200, 200);
api.rotateFlip('rot90cw');       % rotate/flip: 'rot90cw','rot90ccw','fliph','flipv'
api.setPixelSize(2.4, 'nm');     % override pixel calibration

% EDS multi-channel composite mode
api.loadImages({'Fe_Ka.tif', 'O_Ka.tif', 'Si_Ka.tif'});
api.enterEDS();                          % auto-populates channels from loaded images
chs = api.getEDSChannels();              % cell array of channel structs
api.setEDSChannel(1, 'color', 'red');    % assign pseudo-color
api.setEDSChannel(2, 'color', 'green');
api.setEDSChannel(3, 'color', 'blue');
api.setEDSChannel(2, 'intensity', 0.8); % scale channel brightness
api.setEDSChannel(3, 'visible', false);  % hide a channel
comp = api.getEDSComposite();            % [H x W x 3] RGB double
api.exportImage('eds_composite.png');    % save blended composite
api.exitEDS();                           % return to normal view
api.close();

% Import EM image data directly from the command line
data = parser.importTIFF('sem_image.tif');
img = data.metadata.parserSpecific.imageData;
imagesc(img.pixels); colormap gray; axis equal tight;

% Gatan DigitalMicrograph DM3 or DM4 (auto-dispatched by importAuto)
data = parser.importDM3('hrstem_image.dm3');
img = data.metadata.parserSpecific.imageData;
imagesc(img.pixels); colormap gray; axis image;
if img.calibrated
    title(sprintf('Pixel size: %.4g %s', img.pixelSize, img.pixelUnit));
end

% Headerless RAW — dimensions must be specified explicitly
data = parser.importRawImage('raw_image.raw', 'Width', 1024, 'Height', 768, 'BitDepth', 16);

% Imaging utilities
adjusted = imaging.adjustContrast(img.pixels, 100, 3000);
smoothed = imaging.applyGaussian(img.pixels, Sigma=2);
[mag, phase] = imaging.computeFFT(img.pixels);
[dist, intensity] = imaging.lineProfile(img.pixels, 1, 1, 100, 100, PixelSize=2.4, PixelUnit='nm');
thumb = imaging.generateThumbnail(img.pixels, MaxSize=256);
```

#### emViewerGUI Feature Summary

**Contrast & Display:** Auto-contrast (2nd/98th percentile), manual Low/High sliders, CLAHE (no-toolbox), colormap selection, colorbar toggle, histogram panel.

**Measurements:** Line profile with export, point-to-point distance, angle (3-click), polyline (multi-click, double-click to finish), ROI statistics (mean/std/min/max/area + mini-histogram).

**Processing:** Gaussian filter, median filter, CLAHE, rotate 90°CW/CCW, flip H/V, FFT display, FFT masking with inverse FFT (interactive mask placement via ButtonDownFcn), crop, zoom box.

**Advanced:** Particle/feature counting (threshold + connected-component labeling via two-pass union-find, no toolbox), drift correction / image alignment (cross-correlation), color overlay / channel merge (assign colormaps to two images and blend), **EDS multi-channel composite** (false-color blending of element maps with per-channel color, visibility, and intensity controls), **template matching** (NCC-based feature finding), **image stitching** (panoramic mosaic from overlapping tiles), **noise characterization** (MAD/local-variance estimation with filter recommendations).

**EELS Analysis:** Background subtraction (power-law/exponential), core-loss edge identification (~50 built-in edges), elemental map extraction from spectrum images, thickness mapping (log-ratio t/λ), zero-loss peak alignment. Supports 1D spectra and 3D spectrum image datacubes from DM3/DM4 files.

**Diffraction Indexing:** Auto-detect spots in FFT/diffraction patterns, match against built-in crystal database (~50 phases), zone axis identification, ring overlay for matched phases. Supports both FFT geometry and calibrated TEM diffraction (camera length input).

**EDS Quantification:** Cliff-Lorimer thin-film quantification from EDS element maps, built-in k-factor table (47 elements, 200 kV), atomic% and weight% maps, composition line profiles, ROI composition analysis.

**Analysis Tools:** 3D surface view (height map rendering), live FFT panel (persistent, updates with filters), measurement statistics (aggregate histogram + stats), batch measurement (same profile across all images), export profile to DataPlotter.

**Publication Tools:** Journal presets (APS/Nature/ACS/Elsevier annotation formatting), EM colormap presets (SEM/TEM/STEM-HAADF/EDS/phase/topography).

**Stack Navigator:** Multi-frame TIFF detection with frame slider, prev/next buttons, and Maximum Intensity Projection (MIP). Shown automatically when loading multi-page TIFFs.

**Undo:** Multi-level undo stack (cap 5 entries). `undoPush()` called inside `try` blocks before each destructive operation (filter, rotate, crop, FFT mask). Ctrl+Z triggers undo; handles dimension changes from rotation undo.

**Export:** Save image, save crop, export with overlays (burns scale bar, annotations, measurements into image via `copyobj`+`getframe`), batch export (all loaded images with per-image auto-contrast), copy to clipboard.

**Quality of Life:** Keyboard shortcuts (Ctrl+O open, Ctrl+S save, Ctrl+Z undo, A auto-contrast, F fit, +/- zoom), drag-and-drop file loading, recent files list (persisted to `.emviewer_recent.mat`, cap 10), pixel calibration override, linked zoom in compare mode, text annotations.

**Capture modes** (`appData.captureMode`): `'profile'`, `'distance'`, `'angle'`, `'polyline'`, `'roistats'`, `'zoom'`, `'crop'`, `'savecrop'`, `'annotation'`.

### EELS Analysis
```matlab
% Import EELS spectrum from DM3/DM4
data = parser.importDM3('eels_spectrum.dm3');
spec = data.metadata.parserSpecific.spectrumData;
plot(spec.energyAxis, spec.counts);
xlabel('Energy Loss (eV)'); ylabel('Counts');

% Background subtraction (power-law)
[signal, bg] = imaging.eelsBackground(spec.energyAxis, spec.counts, ...
    FitWindow=[600 700]);

% Show edge markers
edges = imaging.eelsEdgeTable();
feEdge = edges(strcmp({edges.symbol}, 'Fe-L23'));
xline(feEdge.onsetEV, 'r--', feEdge.symbol);

% Spectrum image: load 3D datacube
data = parser.importDM3('spectrum_image.dm3');
si = data.metadata.parserSpecific.spectrumImage;
% si.cube = [Ny x Nx x nE], si.energyAxis = [nE x 1]

% Extract elemental map
feMap = imaging.eelsExtractMap(si.cube, si.energyAxis, [708 750], ...
    BackgroundWindow=[600 700]);
imagesc(feMap); colorbar; title('Fe-L_{2,3} map');

% Thickness mapping
[tMap, mask] = imaging.eelsThicknessMap(si.cube, si.energyAxis);

% ZLP alignment
[alignedCube, shifts] = imaging.eelsAlignZLP(si.cube, si.energyAxis);
```

### Diffraction Pattern Indexing
```matlab
% Auto-detect spots in FFT or diffraction pattern
spots = imaging.findDiffractionSpots(fftImage, MinRadius=15, Threshold=0.05);

% Match against crystal database
result = imaging.indexDiffraction(spots, size(fftImage), ...
    PixelSize=0.195, PixelUnit='nm', AccVoltage=200);

% Top candidate
fprintf('Best match: %s (score=%.0f%%)\n', ...
    result.candidates(1).phaseName, result.candidates(1).score*100);

% Zone axis
za = result.candidates(1).zoneAxis;
fprintf('Zone axis: [%d %d %d]\n', za);

% Electron wavelength
lambda = imaging.calcElectronWavelength(200);  % 0.02508 Å
```

### EDS Quantification
```matlab
% Cliff-Lorimer quantification from intensity maps
maps = {fe_map, o_map, ti_map};
elements = {'Fe', 'O', 'Ti'};
result = imaging.cliffLorimer(maps, elements);
% result.atomicPctMaps, result.weightPctMaps, result.meanAtomicPct

% Built-in k-factors
kTable = imaging.edsKFactorTable();
kFe = kTable('Fe');  % 1.21

% Composition line profile
profile = imaging.edsCompositionProfile(result.atomicPctMaps, elements, ...
    x1, y1, x2, y2, PixelSize=2.4, PixelUnit='nm');
plot(profile.distance, profile.atomicPct);
legend(elements);
```

### Materials Calculator
```matlab
materialsCalcGUI                                    % launch interactive GUI
api = materialsCalcGUI();                            % headless API for testing

% Unit conversions
api.convert(1, 'eV', 'nm')                          % energy ↔ wavelength

% Crystal calculations
api.calcDSpacing(3.905, 1, 1, 0)                    % cubic d-spacing
api.calcPlaneSpacings(5.431, 'F')                    % FCC Si allowed reflections

% X-ray/Neutron SLD
api.calcNeutronSLD('SrTiO3', 5.12)                  % neutron SLD
api.calcXraySLD('Si', 2.33)                          % X-ray SLD
api.calcQToTwoTheta(2.0, 1.5406)                    % Q → 2θ conversion

% Superconductor calculations
api.calcLondonDepth('Nb', 4.2)                       % London depth at 4.2 K
api.calcCriticalFields('Nb', 4.2)                    % critical fields at 4.2 K

% Favorites
api.addFavorite('STO SLD', 'X-ray/Neutron', '3.54e-6', '\mathrm{SLD}')
api.getFavorites()

api.close()
```

**13 Tabs:** Unit Converter, Crystal, Electrical, Semiconductor, Thin Film, X-ray/Neutron, Superconductor, Optics, Vacuum, Electrochem, Multilayer, Periodic Table, Favorites

**Packages:** `+calc/constants.m`, `+calc/unitConvert.m`, `+calc/elementData.m`, `+calc/+crystal/` (13), `+calc/+electrical/` (5), `+calc/+semiconductor/` (12), `+calc/+thinFilm/` (9, incl. ion beam), `+calc/+magnetic/` (4), `+calc/+substrates/` (2), `+calc/+xrayNeutron/` (11), `+calc/+superconductor/` (6), `+calc/+optics/` (7), `+calc/+vacuum/` (6), `+calc/+electrochemistry/` (5), `+calc/importCIF.m`, `+calc/crystalCache.m`

### Running the test suite
```matlab
runAllTests                     % all suites (~2 min including GUI tests)
runAllTests(Group="parser")     % fast parser smoke tests only (no GUI, ~5 s)
runAllTests(Group="xrd2d")      % 2D area-detector parser + edge cases
runAllTests(Group="gui")        % headless DataPlotter API tests
runAllTests(Group="sims")       % SIMS depth profile parser tests
runAllTests(Group="batch")      % batchImport / batchConvertXRD integration
runAllTests(Group="em")         % EM image parsers + imaging utilities (no GUI, fast)
runAllTests(Group="emgui")      % headless emViewerGUI API tests (requires display)
runAllTests(Group="eds")        % EDS multi-channel composite mode tests
runAllTests(Group="xrayneutron") % X-ray/Neutron calculation module tests
runAllTests(Group="superconductor") % superconductor calculation module tests
runAllTests(Group="cif")        % CIF parser and crystal cache tests
runAllTests(Group="eels")           % EELS analysis utility tests
runAllTests(Group="diffindex")      % Diffraction indexing tests
runAllTests(Group="edsquant")       % EDS quantification tests
```

Individual suites can still be run directly:
```matlab
run tests/test_parsers            % smoke tests for all +parser functions
run tests/test_importAuto         % auto-dispatch coverage
run tests/test_parsers_edge_cases % error-handling paths
run tests/test_xrdml_2d           % 2D XRDML parser (8 tests)
run tests/test_xrdml_2d_edge      % edge cases: missing wavelength, malformed XML
run tests/test_gui_harness        % GUI API (requires display)
run tests/test_gui_phase4         % phase-4 GUI features (annotations, Y2, session)
run tests/test_sims_parser        % SIMS depth profile parser (synthetic data)
run tests/test_em_parsers         % EM image parsers: importTIFF + importRawImage + importDM3
run tests/test_imaging_utils      % imaging utilities: contrast, filter, FFT, profile
run tests/test_em_gui_harness     % EM Viewer GUI API (requires display)
run tests/test_eds_composite      % EDS multi-channel composite mode
run tests/test_eels                  % EELS utilities (synthetic data)
run tests/test_diffraction_index     % Diffraction indexing (synthetic spots)
run tests/test_eds_quantification    % EDS quantification (synthetic maps)
```

## Key Design Decisions

- **No external toolboxes** — uses MATLAB built-ins only
- **Functional approach** — pure functions returning structs; no heavy OOP
- **Auto-detection heuristics** — delimiter, header row, data start, units all inferred automatically
- **Pipeline pattern** — parse → correct → plot; each stage independent
- **Unified data struct** — all parsers emit the same field layout so GUI and plotting code is parser-agnostic
- **Peak fitting** — Lorentzian model (appropriate for XRD Bragg peaks)

## GUI Notes

### DataPlotter
- `cla()` alone does not remove graphics objects with `HandleVisibility='off'` (peak markers).
  Use `delete(ax.Children)` before `cla()` to clear all children.
- Each dataset in `appData.datasets` stores its own axis limits (`ds.axLims`) so zoom
  levels are restored when switching between loaded files.
- **Peak Analysis window** (`peakFig`) is a separate `uifigure` containing the peak table, fitting
  controls, export buttons, and advanced crystallography tools. It opens automatically after peak
  detection (`onAutoPeak`) or on the first manual peak add. The "Peaks..." button in the corrections
  panel opens it on demand. Closing the window just hides it (`Visible='off'`); peaks and markers
  on the main axes are unaffected. Peak detection buttons (Auto Find, Add Peak, Click-Remove)
  remain in the corrections panel since they interact with the main axes.
  - `appData.peakMode` tracks the current mode: `'xrd'`, `'reflectometry'`, or `'none'`.
  - `configurePeakWindowForMode(mode)` shows/hides mode-specific buttons in the peak window.
  - `showPeakWindow()` refreshes the table and brings the window to front.
  - The main GUI's `analysisGL` column 3 is now width 0 by default (only used for `map2DPanel` in 2D mode).

### emViewerGUI
- Image pipeline: `rawPixels` → `filteredPixels` (after filters) → `displayImg` ([0,1] after contrast).
- `displayImage()`, `clearDisplay()`, and `setToolsEnabled()` must all be updated when adding new buttons (the enable/disable triad).
- `exitCompareMode()` recreates `axGL` as `[2 1]` grid (row 1 = axes, row 2 = stack navigator). Stack controls must be recreated with full styling (`BTN_TOOL`, `BTN_FG`, tooltips).
- `undoPush()` must go **inside** `try` blocks, not before — prevents phantom undo entries on filter failure.
- `undoPop()` must detect dimension changes (e.g. undoing a rotation on non-square images) and do full axes rebuild instead of just updating CData.
- FFT mask editor uses `ButtonDownFcn` on axes, not `ginput()` — `ginput` is unreliable from uifigure callback contexts.
- Polyline double-click: `WindowButtonDownFcn` fires twice; check `fig.SelectionType == 'open'` before adding click points.
- Recent files persisted to `.emviewer_recent.mat` in the toolbox root directory.
- CLAHE: uniform tiles can produce `cdf(end) == 0`; fallback: `cdf = linspace(0, 1, nBins)`.
- Batch export uses per-image auto-contrast (2nd/98th percentile), not the active image's slider values.
