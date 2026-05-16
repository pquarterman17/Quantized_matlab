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
    │ BosonPlotter │  │ FermiViewer│  │ DiraCulator  │
    │   (main)    │  │  (EM imgs) │  │    (calc)    │
    └──────┬──────┘  └─────┬──────┘  └──────┬──────┘
           │               │               │
    ┌──────▼──────┐  ┌─────▼──────┐  ┌──────▼──────┐
    │ +bosonPlotter│  │ +emViewer/  │  │   +calc/    │
    │ (extracted) │  │ (extracted) │  │             │
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
     ├──► BosonPlotter loads as dataset → appData.datasets{idx}
     │        │
     │        ▼
     │    bosonPlotter.applyCorrections(rawData, params)
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
     │    bosonPlotter.renderPlot(ax) ← renders to plot
     │
     ├──► FermiViewer loads as image
     │        rawPixels → filteredPixels → displayImg
     │
     └──► scripts.batchImport / scripts.quickPlot
```

## BosonPlotter State Management

### appData (main state container)

```matlab
appData.datasets       % {1×N cell} of dataset structs (ds)
appData.activeIdx      % scalar — index of currently active dataset
appData.bgDataset      % background dataset for subtraction (or [])
appData.peakMode       % 'xrd' | 'reflectometry' | 'none'
appData.overlayMode    % logical — multi-dataset overlay on/off
appData.captureMode    % '' | 'cursor' | 'zoom' | 'mask' | 'annotate' | ...
appData.styleOverrides % struct — global plot style overrides from Plot Style dialog
appData.activeTemplate % string — name of the currently-selected publication template
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

The corrections pipeline is extracted to `+bosonPlotter/applyCorrections.m`. It takes a raw data struct and a params struct, and returns a corrected data struct. The params struct is built by `+bosonPlotter/correctionParams.m` from the dataset struct + GUI widget values.

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
        → bosonPlotter.correctionParams(ds, uiVals) → params
        → bosonPlotter.applyCorrections(data, params) → corrData
        → saves corrData + params back to ds
        → if neutron: propagates to sibling datasets
        → onPlot() → bosonPlotter.renderPlot()
```

```
User clicks in plot (peak detection, cursor, mask, etc.)
    → onAxesButtonDown()
        → checks appData.captureMode
        → dispatches to mode-specific handler
```

## Extracted Subsystems (+bosonPlotter/)

The package contains 37 files. Below is the full function index grouped by area.

### Render pipeline

| Module | Description |
|--------|-------------|
| `renderPlot.m` | Master render entry point — dispatches to 1D/2D/overlay rendering |
| `resolveStyle.m` | Resolve per-dataset style (color, line, marker) from template + overrides |
| `applyPostRenderStyle.m` | Apply post-render style properties (font, axes box, grid, etc.) |
| `applyDsOverride.m` | Apply per-dataset style overrides onto a rendered line/patch |
| `applyAlphaToLine.m` | Set line/patch alpha (transparency) |
| `applyFaceModeToLine.m` | Set face/edge mode on patch/area objects |
| `applyAppearanceToAxes.m` | Apply Appearance struct properties to axes |
| `applyAppearanceToColorbar.m` | Apply Appearance struct to colorbar (font, label, ticks) |
| `colorMaps.m` | Custom colormap definitions (viridis, plasma, etc.) |
| `buildMap2DPanel.m` | Build the 2D reciprocal-space map panel and colorbar |
| `drawOverlays.m` | Draw annotations, scale bars, and cursor overlays onto axes |

### Style system

| Module | Description |
|--------|-------------|
| `plotStyleDialog.m` | Plot Style dialog — edit global style overrides stored in `appData.styleOverrides` |
| `userTemplates.m` | Load, save, and manage user-defined publication templates |
| `safeEvalMathExpr.m` | Safely evaluate math expressions from style input fields (no eval) |

### Dialogs

| Module | Description |
|--------|-------------|
| `curveFitting.m` | General curve fitting dialog (fminsearch; see [`+fitting/README.md`](../+fitting/README.md) for model catalog) |
| `graphDigitizer.m` | Graph digitizer: extract (x,y) data from graph screenshots |
| `figureBuilder.m` | Advanced Figure Builder (10 figure types, journal templates) |
| `multiPanel.m` | Multi-panel figure composer |
| `hysteresisDialog.m` | Hysteresis loop analysis dialog (coercivity, remanence, saturation) |
| `reflFitting.m` | Neutron/X-ray reflectometry fitting dialog |
| `surfaceFitDialog.m` | 2D surface / polynomial fit dialog |
| `spreadsheetPopup.m` | Inline spreadsheet popup for viewing/editing dataset table |
| `roiAnalysis.m` | Region-of-interest statistics dialog |

### State & session

| Module | Description |
|--------|-------------|
| `AppState.m` | Centralised appData accessors (get/set with validation) |
| `sessionManager.m` | Save and restore full GUI session to/from MAT file |
| `UndoManager.m` | Undo stack management (push, pop, cap enforcement) |
| `actionLog.m` | Append entries to the in-memory action log |
| `toolbarConfig.m` | Declare toolbar button layout and initial enabled state |
| `toolbarDefaultConfig.m` | Default toolbar configuration struct |

### Peak & fitting

| Module | Description |
|--------|-------------|
| `peakAnalysis.m` | Peak detection, fitting, and reporting logic |
| `peakCallbacks.m` | UI callbacks for the Peak Analysis window |
| `peakTools.m` | Utility functions shared by peakAnalysis and peakCallbacks |
| `buildPeakWindow.m` | Construct the Peak Analysis uifigure and controls |

### Data subsystems

| Module | Description |
|--------|-------------|
| `applyCorrections.m` | Core corrections pipeline — pure function (trim, offset, bg, smooth, norm, deriv) |
| `correctionParams.m` | Build params struct from dataset + UI widget values |
| `datasetGroups.m` | Dataset grouping logic (group-by, batch operations) |
| `filterRows.m` | Row-level data masking and filter application |

## FermiViewer Image Pipeline

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

## Extracted Subsystems (+emViewer/)

FermiViewer's logic is extracted to `+emViewer/` (47 files). The orchestrator
builds context structs and delegates; package functions return modified appData.

```
FermiViewer.m (6,082 lines — orchestrator + closure state)
    │
    ├── ctx = struct(fig, ax, sliders, callbacks...)
    │
    └── appData = emViewer.<module>(action, appData, ctx, ...)
```

### Accept-and-return pattern (closure mutation fix)

MATLAB structs are value-type: extracted functions hold local copies. Callbacks
that modify appData in the closure (rebuildScaleBar, refreshDisplay) must accept
and return appData so the caller's copy stays current:

```matlab
% WRONG — closure's scale bar updates lost when filterOps returns its stale copy
cb.refreshDisplay();

% CORRECT — state flows back through the return value
appData = cb.refreshDisplay(appData);
```

For `displayImage.m`, the `closureReturn_` bridge provides:
- `pushAppData(appData)` — write local state TO closure before callbacks fire
- `pullAppData()` — read closure state back after callbacks modify it

### Module groups (see `+emViewer/README.md` for full index)

| Area | Key modules |
|------|-------------|
| Display | `displayImage`, `displayHelpers`, `displayStackFrame`, `clearDisplay` |
| Processing | `filterOps`, `processActions`, `rotateFlip`, `contrastOps` |
| Interaction | `mouseOps`, `measInteract`, `measExecute`, `captureDispatch` |
| UI build | `buildToolbar`, `buildContrastPanel`, `buildEDSPanel`, `buildEELSPanel` |
| Scale bar | `scaleBarOps`, `applyScaleBarPos`, `snapScaleBarPos` |
| Session | `sessionOps`, `onKeyPress`, `export` |
| Compare | `compareImage`, `compareDispatch` |
| Domain | `onDiffractionAction`, `onAnnotationAction`, `applyColorChannel` |

## Testing Architecture

Tests are organized into subdirectories under `tests/`:

```
tests/
├── parser/     — parser smoke tests, edge cases, round-trip, SIMS, 2D XRDML
├── gui/        — BosonPlotter headless API tests, contour, materials calc
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
+bosonPlotter/ ← depends on +parser/, +utilities/
+emViewer/ ← depends on +imaging/, +parser/
BosonPlotter.m ← depends on all packages
FermiViewer.m ← depends on +emViewer/, +parser/, +imaging/
DiraCulator.m ← depends on +calc/
```
