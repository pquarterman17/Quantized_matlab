# Architecture Guide

> High-level design documentation for contributors and Claude.
> For conventions and quick-start workflows, see [CLAUDE.md](../CLAUDE.md).

## System Overview

```
                    ┌──────────────┐
                    │  User / CLI  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
    ┌─────────▼──┐  ┌──────▼─────┐  ┌──▼──────────┐
    │ DataPlotter │  │ emViewerGUI│  │materialsCalc │
    │   (main)    │  │  (EM imgs) │  │  GUI (calc)  │
    └──────┬──────┘  └─────┬──────┘  └──────┬──────┘
           │               │               │
    ┌──────▼──────┐  ┌─────▼──────┐  ┌──────▼──────┐
    │ +dataplotter│  │  +imaging/  │  │   +calc/    │
    │ (extracted) │  │             │  │             │
    └──────┬──────┘  └─────┬──────┘  └──────┬──────┘
           │               │               │
    ┌──────▼──────────────▼────────────────▼──────┐
    │           +parser/  +utilities/  +scripts/   │
    │              (shared data layer)             │
    └──────────────────────────────────────────────┘
```

## Data Flow: Import → Correct → Plot

```
 File on disk
     │
     ▼
 parser.importAuto(file)          ← resolveParser → function handle
     │
     ▼
 parser.createDataStruct(...)     ← validates unified struct
     │
     ▼
 data struct (.time, .values, .labels, .units, .metadata)
     │
     ├──► DataPlotter loads as dataset → appData.datasets{idx}
     │        │
     │        ▼
     │    dataplotter.applyCorrections(rawData, params)
     │        │  1. Trim/crop
     │        │  2. X offset
     │        │  3. Y background (poly or linear)
     │        │  4. Background dataset subtraction
     │        │  5. Magnetometry unit conversion
     │        │  6. Smoothing (moving/gaussian/SG)
     │        │  7. Normalization (range/peak/zscore/area)
     │        │  8. Derivative (dY/dX, d²Y/dX², ∫Y, dlog/dlog)
     │        ▼
     │    ds.corrData ← corrected data struct
     │        │
     │        ▼
     │    drawToAxes(ax) ← renders to plot
     │
     ├──► emViewerGUI loads as image
     │        rawPixels → filteredPixels → displayImg
     │
     └──► scripts.batchImport / scripts.quickPlot
```

## DataPlotter State Management

### appData (main state container)

```matlab
appData.datasets    % {1×N cell} of dataset structs (ds)
appData.activeIdx   % scalar — index of currently active dataset
appData.bgDataset   % background dataset for subtraction (or [])
appData.peakMode    % 'xrd' | 'reflectometry' | 'none'
appData.overlayMode % logical — multi-dataset overlay on/off
appData.captureMode % '' | 'cursor' | 'zoom' | 'mask' | 'annotate' | ...
```

### Dataset struct (ds)

Each element of `appData.datasets` is a struct:

```matlab
ds.filepath       % source file path
ds.data           % raw unified data struct (from parser)
ds.corrData       % corrected data struct (after pipeline) — [] if uncorrected
ds.parserName     % e.g. 'importQDVSM', 'importXRDML'
ds.visible        % logical — show in plot
ds.color          % [1×3] RGB plot color
ds.legendName     % display name in legend

% Correction parameters (persisted per-dataset)
ds.xOff, ds.yOff, ds.bgSlope, ds.bgInt
ds.bgPoly          % polynomial coefficients (when order > 1)
ds.smoothEnabled, ds.smoothWindow, ds.smoothMethod
ds.xTrimMin, ds.xTrimMax
ds.normMethod, ds.derivativeMode

% Magnetometry-specific
ds.sampleMass, ds.sampleWidth, ds.sampleHeight
ds.fieldUnit, ds.momentUnit, ds.unitSystem

% Peak analysis
ds.peaks           % struct array: center, fwhm, height, area, xRange, status, bg, model, eta
ds.axLims          % saved axis limit strings (persisted across switches)

% Undo
ds.undoStack       % {cell} of undo states (cap 5)
ds.undoState       % single previous state (backward compat)

% Data masking
ds.mask            % logical vector — masked rows excluded from plot
```

### Corrections Pipeline

The corrections pipeline is extracted to `+dataplotter/applyCorrections.m`. It takes a raw data struct and a params struct, and returns a corrected data struct. The params struct is built by `+dataplotter/correctionParams.m` from the dataset struct + GUI widget values.

**Key design decisions:**
- Pipeline order is fixed: trim → offset → background → units → smooth → normalize → derivative
- Derivative is always LAST to preserve numerical accuracy
- Normalization before derivative so normalized shapes are differentiated, not raw values
- For neutron data, Y offset is **multiplicative** (R scale factor), not additive
- Background can be linear (slope+intercept), polynomial (bgPoly), or a separate dataset

### Event Flow

```
User clicks "Apply Corrections"
    → onApplyCorrections()
        → reads UI widget values into uiVals struct
        → dataplotter.correctionParams(ds, uiVals) → params
        → dataplotter.applyCorrections(data, params) → corrData
        → saves corrData + params back to ds
        → if neutron: propagates to sibling datasets
        → onPlot() → drawToAxes()
```

```
User clicks in plot (peak detection, cursor, mask, etc.)
    → onAxesButtonDown()
        → checks appData.captureMode
        → dispatches to mode-specific handler
```

## Extracted Subsystems (+dataplotter/)

| Module | Description | Lines saved from DataPlotter |
|--------|-------------|-----|
| `applyCorrections.m` | Core corrections pipeline (pure function) | ~300 |
| `correctionParams.m` | Build params struct from dataset + UI values | ~60 |
| `curveFitting.m` | General curve fitting dialog (15 models) | ~390 |
| `graphDigitizer.m` | Graph digitizer dialog (image → data points) | ~340 |
| `figureBuilder.m` | Advanced Figure Builder (10 figure types) | ~2430 |

## emViewerGUI Image Pipeline

```
loadImages()
    │
    ▼
rawPixels ← imread / parser.importTIFF / parser.importDM3
    │
    ▼
filteredPixels ← rawPixels after filters (gaussian, median, CLAHE, FFT mask)
    │         Filters are destructive: each modifies filteredPixels in-place.
    │         undoPush() saves state before each filter.
    │
    ▼
displayImg ← adjustContrast(filteredPixels, low, high)
    │         Normalized to [0,1] double for display.
    │
    ▼
imagesc(ax, displayImg) ← rendered to axes
    │
    ├── Scale bar overlay (imaging.addScaleBar)
    ├── Measurement overlays (line profile, distance, angle)
    └── Annotation text
```

### Key patterns:
- **Enable/disable triad**: When adding new buttons, update `displayImage()`, `clearDisplay()`, and `setToolsEnabled()`.
- **Undo**: `undoPush()` called **inside** try blocks, not before. Cap 5 entries.
- **Capture modes**: `appData.captureMode` gates mouse click behavior.
- **FFT masking**: Uses `ButtonDownFcn` on axes, not `ginput()`.

## Testing Architecture

Tests are organized into subdirectories under `tests/`:

```
tests/
├── parser/     — parser smoke tests, edge cases, round-trip, SIMS, 2D XRDML
├── gui/        — DataPlotter headless API tests, contour, materials calc
├── imaging/    — EM parsers, imaging utils, EM GUI, EDS, EELS, diffraction
├── calc/       — calculator module tests (xray, superconductor, CIF, optics, ...)
└── batch/      — batch import and XRD converter tests
```

`runAllTests.m` dispatches tests by group name. Each test script runs in an isolated function workspace (via `runSuite()`) so `clear` in one test doesn't affect others.

## Package Dependencies

```
+parser/  ← standalone (no deps on other packages)
+utilities/ ← standalone
+plotting/ ← depends on +styles/
+styles/ ← standalone
+imaging/ ← standalone
+calc/ ← standalone
+scripts/ ← depends on +parser/, +utilities/
+dataplotter/ ← depends on +parser/, +utilities/
DataPlotter.m ← depends on all packages
emViewerGUI.m ← depends on +parser/, +imaging/
materialsCalcGUI.m ← depends on +calc/
```
