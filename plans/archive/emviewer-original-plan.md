# Electron Microscopy Image Viewer — Implementation Plan

**Created:** 2026-03-15
**Status:** Phase 7 Complete — Core Implementation Done

---

## Overview

A new standalone GUI (`Fermion.m`) for viewing and analysing electron microscopy images. Supports TIFF, headerless RAW, and Gatan DM3 formats. Follows the existing toolbox architecture: parsers return the unified data struct, image-specific utilities live in a new `+imaging` package, and the GUI is a monolithic uifigure with nested functions (same pattern as `Boson.m` and `xrdConvertGUI.m`).

---

## Architecture Decisions

### 1. Separate GUI (not integrated into Boson)

The interaction model for raster images (pan/zoom/contrast/measurement) is fundamentally different from curve plotting with corrections and peak fitting. Adding it to `Boson.m` (already 11,500+ lines) would push it past 15,000 lines and mix incompatible workflows. A standalone `Fermion.m` follows the established pattern of purpose-specific GUIs.

### 2. Image data struct — extend the 2D pattern

Image parsers return the standard unified struct so they work with `importAuto`, `exportHDF5`, tests, etc. The real image payload lives in `metadata.parserSpecific.imageData`:

```matlab
% Standard fields (1D fallback)
data.time      = 1:H;                  % row pixel indices or calibrated spatial axis
data.values    = meanIntensityProfile;  % Hx1 mean intensity
data.labels    = {'Mean Intensity'};
data.units     = {'counts'};
data.metadata.parserName = 'importTIFF';
data.metadata.parserSpecific.isImage = true;

% Image-specific payload
data.metadata.parserSpecific.imageData
    .pixels         % [H x W] or [H x W x C] numeric (uint8/uint16/single)
    .bitDepth       % 8, 16, or 32
    .height         % H in pixels
    .width          % W in pixels
    .numChannels    % 1 (grayscale) or 3 (RGB)
    .numFrames      % 1 for single image, >1 for stack
    .frames         % {1 x numFrames} cell of [HxW] matrices (stacks only)
    .pixelSize      % scalar, physical size of one pixel (NaN if uncalibrated)
    .pixelUnit      % string: 'nm', 'um', 'mm', '' (empty if uncalibrated)
    .calibrated     % logical
    .acquiParams    % struct of instrument-specific acquisition metadata
```

This follows the same pattern as `importXRDML`'s `map2D` extension — no changes to `createDataStruct` needed.

### 3. New `+imaging` package

Image processing functions that have no meaning for 1D data go in `+imaging/`, not `+utilities/`. Parsers remain in `+parser/` because they return the unified struct.

---

## File Formats

### TIFF (.tif / .tiff)
- Standard EM image format
- Metadata in TIFF tags: FEI/Thermo Fisher tag 34682 (ASCII `key=value` block), standard EXIF via `imfinfo`
- 8-bit, 16-bit, or 32-bit; grayscale or RGB
- Multi-page TIFFs for image stacks
- Parser: `imread` / `imfinfo` / `Tiff` class (all built-in)

### RAW (.raw) — headerless binary
- Arbitrary dimensions and bit depths
- Requires user-specified Width, Height, BitDepth
- NOT auto-dispatchable via `importAuto` (impossible to detect dimensions)
- Parser: `fread` + `reshape`

### DM3 (.dm3) — Gatan DigitalMicrograph v3
- Proprietary binary format with recursive tagged data structure
- Contains image data, calibration (pixel size/units), acquisition metadata
- No official specification; community-documented
- **DEFERRED to post-launch** (see Risks)

---

## New Files (14 total)

### Parsers (`+parser/`)

| File | Description | Complexity |
|------|-------------|------------|
| `importTIFF.m` | TIFF via `imread`/`imfinfo` + FEI metadata from tag 34682 | Medium |
| `importRawImage.m` | Headerless binary with user-specified W/H/BitDepth | Low |
| `importDM3.m` | Gatan DM3 recursive tagged binary format | **HIGH — deferred** |

### Imaging utilities (`+imaging/`)

| File | Purpose | Implementation notes |
|------|---------|---------------------|
| `adjustContrast.m` | Window/level linear stretch | `out = (img - Low) / (High - Low)`, clamped |
| `applyGaussian.m` | 2D Gaussian filter | `conv2` with manual kernel (`exp(-0.5*(x^2+y^2)/sigma^2)`) |
| `applyMedian.m` | 2D median filter | Manual implementation (no `medfilt2`); limit window to 3-7 |
| `computeFFT.m` | FFT magnitude display | `fft2` + `fftshift` + `log10(1+abs(...))` |
| `lineProfile.m` | Intensity along a line | `interp2` with linear method along sample points |
| `measureDistance.m` | Calibrated point-to-point distance | Euclidean distance with optional calibration |
| `addScaleBar.m` | Scale bar overlay on axes | `rectangle` + `text` with `HandleVisibility='off'` |
| `generateThumbnail.m` | Downsample (no `imresize`) | Block-averaging or `interp2` with bilinear on coarser grid |

### GUI

| File | Description | Estimated size |
|------|-------------|---------------|
| `Fermion.m` | Standalone uifigure EM image viewer | ~3,000-4,000 lines |

### Tests

| File | Group | Description |
|------|-------|-------------|
| `test_em_parsers.m` | `em` | Synthetic TIFF (via `imwrite`), synthetic RAW, (future: DM3) |
| `test_imaging_utils.m` | `em` | Unit tests for all `+imaging` functions with known inputs |
| `test_em_gui_harness.m` | `emgui` | Headless GUI API tests (same pattern as `test_gui_harness.m`) |

### Modified files (4)

| File | Change |
|------|--------|
| `resolveParser.m` | Add `.tif`/`.tiff`/`.dm3` cases; disambiguate `.raw` via magic bytes |
| `runAllTests.m` | Add `em` and `emgui` test groups |
| `Boson.m` | Optional "Launch EM Viewer" button (3 lines) |
| `CLAUDE.md` | Document new parsers, `+imaging` package, `Fermion` |

---

## GUI Layout

```
+------------------------------------------------------------------+
| Toolbar: [Open] [Save] [Export] | Filename | Zoom: [Fit] [1:1]   |
+------------------------------------------------------------------+
|            |                                    |                 |
| Image List |       Main Image Display           | Info / Tools    |
| (uilistbox)|       (uiaxes with imagesc)        |                 |
|            |                                    | -- Contrast --  |
|   [thumb]  |       [scale bar overlay]          | Low [===] High  |
|   [thumb]  |       [measurement overlays]       | [Auto] [Reset]  |
|   [thumb]  |                                    |                 |
|            |                                    | -- Histogram -- |
|            |                                    | [mini histogram]|
|            |                                    |                 |
|            |                                    | -- Measure --   |
|            |                                    | [Line Profile]  |
|            |                                    | [Distance]      |
|            |                                    | [Export Profile] |
|            |                                    |                 |
|            |                                    | -- Process --   |
|            |                                    | [Gauss Filter]  |
|            |                                    | [Median Filter] |
|            |                                    | [FFT]           |
|            |                                    |                 |
|            |                                    | -- Metadata --  |
|            |                                    | kV: 15          |
|            |                                    | Mag: 50kx       |
|            |                                    | WD: 5.2mm       |
|            |                                    | Pixel: 2.4nm    |
+------------------------------------------------------------------+
| Status: 2048x2048 px | 16-bit | 2.4 nm/px | Mouse: (512, 384)   |
+------------------------------------------------------------------+
```

### Programmatic API (for testing)

```matlab
api = Fermion();
api.fig                           % figure handle
api.loadImages(fpaths)            % load cell array of file paths
api.getImages()                   % return loaded image structs
api.getActiveIdx()                % current image index
api.setActiveIdx(idx)             % switch image
api.setContrast(low, high)        % set window/level
api.autoContrast()                % auto stretch to [2nd, 98th] percentile
api.getLineProfile(x1,y1,x2,y2)  % extract line profile
api.applyFilter(type, params)     % 'gaussian' or 'median'
api.computeFFT()                  % show FFT of current image
api.exportImage(path)             % save processed image
api.close()                       % close figure
```

---

## Implementation Phases

### Phase 1: Parsers (no GUI dependency)

| Step | File | Dependencies | Agent |
|------|------|-------------|-------|
| 1a | `+parser/importTIFF.m` | None | code-implementer |
| 1b | `+parser/importRawImage.m` | None | code-implementer |
| 1c | `+parser/resolveParser.m` modifications | 1a | code-implementer |
| 1d | `tests/test_em_parsers.m` (TIFF + RAW) | 1a, 1b | bug-hunter |
| 1e | `+parser/importDM3.m` | **Deferred** | — |
| 1f | `runAllTests.m` update | 1d | code-implementer |

**Deliverable:** `parser.importTIFF('sem_image.tif')` returns a valid unified struct. `parser.importAuto('sem_image.tif')` dispatches correctly. Tests pass.

### Phase 2: Imaging utilities (no GUI dependency)

| Step | File | Dependencies | Agent |
|------|------|-------------|-------|
| 2a | `+imaging/adjustContrast.m` | None | code-implementer |
| 2b | `+imaging/applyGaussian.m` | None | code-implementer |
| 2c | `+imaging/applyMedian.m` | None | code-implementer |
| 2d | `+imaging/computeFFT.m` | None | code-implementer |
| 2e | `+imaging/lineProfile.m` | None | code-implementer |
| 2f | `+imaging/measureDistance.m` | None | code-implementer |
| 2g | `+imaging/addScaleBar.m` | None | code-implementer |
| 2h | `+imaging/generateThumbnail.m` | None | code-implementer |
| 2i | `tests/test_imaging_utils.m` | 2a-2h | bug-hunter |

**All 2a-2h are independent and can be built in parallel.**

**Deliverable:** All `+imaging` functions working and tested with synthetic data from the command line.

### Phase 3: Core GUI shell

| Step | Description | Dependencies | Agent |
|------|-------------|-------------|-------|
| 3a | Layout scaffolding (uifigure + uigridlayout + uiaxes + panels) | None | ux-frontend-expert |
| 3b | File loading callback + `imagesc` display | Phase 1, 3a | ux-frontend-expert |
| 3c | Image list (uilistbox) with multi-image support | 3b | ux-frontend-expert |
| 3d | Zoom/pan via MATLAB built-in tools | 3b | ux-frontend-expert |
| 3e | Status bar (dimensions, bit depth, pixel size, mouse coords) | 3b | ux-frontend-expert |
| 3f | Programmatic API struct | 3b | ux-frontend-expert |

**Deliverable:** Minimal working GUI — open TIFF, display with zoom/pan, status bar shows mouse position.

### Phase 4: Contrast and histogram

| Step | Description | Dependencies | Agent |
|------|-------------|-------------|-------|
| 4a | Contrast panel (Low/High sliders, Auto, Reset) | Phase 2a, 3 | ux-frontend-expert |
| 4b | Histogram panel (mini plot in small uiaxes) | Phase 3 | ux-frontend-expert |
| 4c | Colormap selector (grayscale, hot, parula, etc.) | Phase 3 | ux-frontend-expert |

### Phase 5: Measurement tools

| Step | Description | Dependencies | Agent |
|------|-------------|-------------|-------|
| 5a | Scale bar overlay toggle | Phase 2g, 3 | ux-frontend-expert |
| 5b | Line profile tool (click two points, plot in new figure) | Phase 2e, 3 | ux-frontend-expert |
| 5c | Distance measurement tool | Phase 2f, 3 | ux-frontend-expert |
| 5d | Export line profile as CSV | 5b | code-implementer |

### Phase 6: Image processing

| Step | Description | Dependencies | Agent |
|------|-------------|-------------|-------|
| 6a | Filter panel (Gaussian sigma, Median window) | Phase 2b-c, 3 | ux-frontend-expert |
| 6b | FFT display | Phase 2d, 3 | ux-frontend-expert |
| 6c | Undo/reset to original | Phase 3 | ux-frontend-expert |
| 6d | Save processed image (via `imwrite`) | Phase 3 | code-implementer |

### Phase 7: Polish and integration

| Step | Description | Dependencies | Agent |
|------|-------------|-------------|-------|
| 7a | Batch thumbnail generation | Phase 2h, 1 | code-implementer |
| 7b | GUI tests (`test_em_gui_harness.m`) | Phase 3-6 | bug-hunter |
| 7c | `CLAUDE.md` documentation update | All | code-implementer |
| 7d | "Launch EM Viewer" button in `Boson.m` | Phase 3 | code-implementer |
| 7e | Session save/load | Phase 3-6 | ux-frontend-expert |

---

## Parallelism

```
Phase 1 (Parsers) ──────────┐
                             ├──> Phase 3 (GUI Shell) ──> Phase 4-6 ──> Phase 7
Phase 2 (Imaging Utils) ────┘
```

Phases 1 and 2 have **no dependencies on each other** and can run in parallel.

---

## Agent Assignments

| Agent | Phases | Rationale |
|-------|--------|-----------|
| **code-implementer** | Phase 1, 2, 5d, 6d, 7a, 7c-d | Binary parsing, numerical algorithms, file I/O |
| **ux-frontend-expert** | Phase 3-6, 7e | uifigure layout, callbacks, interaction design |
| **bug-hunter** | Phase 1d, 2i, 7b | Test design, edge cases, validation |

---

## Risks

### HIGH: DM3 parser complexity
Proprietary recursive binary format with no official spec. Community-documented but variable across DM versions. Estimated 400-600 lines of parser code.

**Decision:** Defer to post-launch. Most EM users export TIFF from DigitalMicrograph. The parser can be added later without touching any other component.

### MEDIUM: Median filter performance without Image Processing Toolbox
Naive nested-loop on 4096x4096 with 5x5 window = 16M comparisons × 25. Could take 10+ seconds without MEX.

**Mitigations:**
- Limit window size to 3-7
- Vectorize via column extraction: reshape neighborhoods into columns, `sort`, take middle row
- Progress bar for large images
- Document the limitation

### MEDIUM: `.raw` extension collision with Rigaku/Bruker
`.raw` is already used for XRD files. EM `.raw` files are headerless.

**Resolution:**
- `resolveParser` checks magic bytes: `'RAW'` → Bruker, `'FI'` → Rigaku, otherwise → error with message directing user to `parser.importRawImage(path, Width=W, Height=H, BitDepth=B)`
- Headerless RAW is intentionally not auto-dispatchable (dimensions are unknowable)

### LOW: Large image stacks (memory)
100 frames × 4096² × 16-bit = 3.2 GB.

**Mitigation:** Lazy frame loading — load metadata for all frames but only load pixel data for the displayed frame. Frame slider in GUI.

---

## Future Extensions (post-launch)

- **DM3/DM4 parser** — once real test files are available
- **Multi-channel support** — channel selector, false-color compositing for EDS maps
- **Line profile → Boson** — export profile as standard struct for correction/peak-fitting
- **Annotation tools** — text labels, arrows, region-of-interest
- **Image registration** — align stack frames (drift correction)
- **Session save/load** — persist loaded image list and contrast settings across sessions (Phase 7e, deferred)

---

## Completion Notes (2026-03-15)

### Delivered (Phases 1–7)

| Component | Status |
|-----------|--------|
| `+parser/importTIFF.m` | Complete — 8/16/32-bit TIFF, FEI tag 34682 metadata, multi-page stacks |
| `+parser/importRawImage.m` | Complete — headerless binary, user-specified dimensions |
| `+parser/importDM3.m` | Complete — DM3/DM4 recursive tag tree; two-pass pixel read; calibration + ImageTags metadata |
| `+parser/resolveParser.m` | Updated — `.tif`/`.tiff` dispatch; `.raw` magic-byte disambiguation; `.dm3`/`.dm4` dispatch |
| `+imaging/adjustContrast.m` | Complete |
| `+imaging/applyGaussian.m` | Complete — manual kernel via `conv2` |
| `+imaging/applyMedian.m` | Complete — vectorised sort, window 3-7 |
| `+imaging/computeFFT.m` | Complete — `fft2` + `fftshift` + log scaling |
| `+imaging/lineProfile.m` | Complete — `interp2` with optional pixel calibration |
| `+imaging/measureDistance.m` | Complete |
| `+imaging/addScaleBar.m` | Complete |
| `+imaging/generateThumbnail.m` | Complete |
| `Fermion.m` | Complete — full uifigure GUI with programmatic API |
| `tests/test_em_parsers.m` | Complete — synthetic TIFF + RAW smoke tests |
| `tests/test_imaging_utils.m` | Complete — unit tests for all +imaging functions |
| `tests/test_em_gui_harness.m` | Complete — 12 headless API tests |
| `runAllTests.m` | Updated — `em` and `emgui` groups added |
| `Boson.m` | Updated — "EM Viewer" button in dataset toolbar |
| `CLAUDE.md` | Updated — full documentation for EM Viewer |

### Previously Deferred — Now Complete (2026-03-19)

| Item | Status |
|------|--------|
| Session save/load | Complete — GUI buttons (Save .mat / Load), API methods, Ctrl+Shift+S/L shortcuts |
| Multi-channel EDS support | Complete — EDS composite mode with per-channel color, visibility, intensity; additive blending; export; 10 API tests |
| Image registration (drift correction) | Complete — FFT cross-correlation alignment via `onAlignStack` |
